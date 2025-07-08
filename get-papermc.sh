#! /bin/bash
set -f # Disable globbing

PROJECT="paper"
CACHE_FILE=".download.cache"
USER_AGENT="get-papermc/1.0.0 (https://github.com/scottsideleau/bootstrap-papermc)"
VERBOSE=1
PROJECT_VERSION=""
TRACKED_VERSION="1.21.7"
OUTPUT_FILE=""
LIST_MODE=0
FORCE=0
CLEAN=0

# --- CLI Usage ---
usage()
{
  cat << EOF
Usage: $0 [OPTIONS]

Options:
  -v, --version <version>   Specify Minecraft version 
                            (default: 1.21.7)
  -o, --output <filename>   Set output filename 
                            (default: use PaperMC-provided name)
  -p, --project <name>      Specify other PaperMC project name
                            (default: paper)
  -f, --force               Force download even if URL is cached
  -c, --clean               Remove cache file and exit
  -l, --list                List available builds for specified version
  -h, --help                Show this help message and exit

Examples:
  $0 -v 1.21.7
  $0 -v 1.20.6 -o custom.jar
  $0 -v 1.21.7 --force
  $0 -v 1.21.7 -c
  $0 -v 1.21.7 --list
EOF
}

# --- Parse Arguments ---
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -l | --list)
      LIST_MODE=1
      shift
      ;;
    -v | --version)
      PROJECT_VERSION="$2"
      shift 2
      ;;
    -p | --project)
      PROJECT="$2"
      shift 2
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -f | --force)
      FORCE=1
      shift
      ;;
    -c | --clean)
      CLEAN=1
      shift
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

PROJECT_VERSION="${PROJECT_VERSION:-${TRACKED_VERSION}}"
API_URL="https://fill.papermc.io/v3/projects/${PROJECT}/versions/${PROJECT_VERSION}/builds"

# --- Cleanup Function ---
cleanup()
{
  log "Cleaning up temporary files..."
  [ -f "$CACHE_FILE" ] && rm -f "$CACHE_FILE" && log "  Removed $CACHE_FILE"
}

# --- Utilities ---

log()
{
  [ "$VERBOSE" -eq 1 ] && printf "%s\n" "$*"
}

fail()
{
  printf "Error: %s\n" "$*" >&2
  exit 1
}

fetch_metadata()
{
  log "Fetching build metadata from $API_URL"
  DATA=$(curl -fsSL -H "User-Agent: $USER_AGENT" "$API_URL") || fail "Unable to contact API"
  [ -z "$DATA" ] && fail "Empty response from API"
  echo "$DATA" | grep -q "<html" && fail "Unexpected HTML response from API"
  echo "$DATA"
}

check_api_ok()
{
  echo "$1" | grep -q '"ok":false' && {
    MSG=$(echo "$1" | grep -o '"message":"[^"]*"' | sed 's/.*"message":"\([^"]*\)".*/\1/')
    fail "${MSG:-Unknown error from API}"
  }
}

extract_download_url()
{
  echo "$1" | awk '
    BEGIN { found=0 }
    /"channel":"STABLE"/ { found=1 }
    found && /"url":/ {
      if (match($0, /"url":"([^"]+)"/, arr)) {
        print arr[1]
        exit
      }
    }
  '
}

extract_download_name()
{
  echo "$1" | awk '
    BEGIN { found=0 }
    /"channel":"STABLE"/ { found=1 }
    found && /"name":/ {
      if (match($0, /"name":"([^"]+)"/, arr)) {
        print arr[1]
        exit
      }
    }
  '
}

download_server()
{
  URL="$1"
  OUTPUT="$2"
  [ -z "$URL" ] && fail "No valid download URL found"
  [ -z "$OUTPUT" ] && fail "No output filename provided"
  log "Downloading: $PROJECT"
  curl -fsSL -o "$OUTPUT" "$URL" || fail "Download failed"
  echo "Download completed: $OUTPUT"
}

is_cached()
{
  [ -f "$CACHE_FILE" ] || return 1
  grep -qF "$1" "$CACHE_FILE"
}

cache_url()
{
  printf "%s\n" "$1" > "$CACHE_FILE"
}

list_builds()
{
  log "Available builds for $PROJECT_VERSION:"
  echo "$1" | awk '
    BEGIN {
      RS="\\},\\{"; FS="[:,{}\"]+"; printed = 0
    }
    {
      id = ""; channel = ""
      for (i = 1; i <= NF; ++i) {
        if ($i == "id") id = $(i+1)
        if ($i == "channel") channel = $(i+1)
      }
      if (id != "" && channel != "") {
        printf "  Build: %-5s Channel: %s\n", id, channel
        printed = 1
      }
    }
    END {
      if (printed == 0) print "  (no builds found)"
    }
  '
}

main()
{
  if [ "$CLEAN" -eq 1 ]; then
    cleanup
    exit 0
  fi

  JSON_DATA=$(fetch_metadata)
  check_api_ok "$JSON_DATA"

  if [ "$LIST_MODE" -eq 1 ]; then
    list_builds "$JSON_DATA"
    exit 0
  fi

  URL=$(extract_download_url "$JSON_DATA")
  log "Resolved URL: $URL"

  if is_cached "$URL"; then
    if [ "$FORCE" -eq 1 ]; then
      log "Cached URL found, but --force is enabled. Re-downloading..."
    else
      log "Server already downloaded from $URL — skipping."
      exit 0
    fi
  fi

  if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE=$(extract_download_name "$JSON_DATA")
    [ -z "$OUTPUT_FILE" ] && fail "Could not determine output filename"
  fi

  download_server "$URL" "$OUTPUT_FILE"
  cache_url "$URL"
}

main

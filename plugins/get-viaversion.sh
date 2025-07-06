#! /bin/bash
set -f
IFS='
'

CACHE_FILE=".download.cache"
USER_AGENT="get-viaversion/1.0.0 (https://github.com/scottsideleau/bootstrap-papermc)"
VERBOSE=1
FORCE=0
CLEAN=0
PROJECT="ViaVersion"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p, --project <name>  Plugin project to download
                        (e.g. ViaVersion, ViaBackwards, ViaRewind)
                        (default: ViaVersion)
  -f, --force           Force re-download even if plugin is cached
  -c, --clean           Remove cache file and exit
  -h, --help            Show this help message
  --quiet               Suppress verbose logging

Examples:
  $0                     # Download ViaVersion
  $0 -p ViaBackwards     # Download ViaBackwards
  $0 --project ViaRewind # Download ViaRewind
EOF
}

log() {
  [ "$VERBOSE" -eq 1 ] && printf "%s\n" "$*" >&2
}

fail() {
  printf "Error: %s\n" "$*" >&2
  exit 1
}

cleanup() {
  log "Cleaning up..."
  [ -f "$CACHE_FILE" ] && rm -f "$CACHE_FILE" && log "  Removed $CACHE_FILE"
}

is_cached() {
  [ -f "$CACHE_FILE" ] || return 1
  grep -qF "$1" "$CACHE_FILE"
}

cache_url() {
  grep -qF "$1" "$CACHE_FILE" 2>/dev/null || echo "$1" >> "$CACHE_FILE"
}

extract_jar_url() {
  REPO="$1"
  API="https://api.github.com/repos/$REPO/releases/latest"
  log "Querying GitHub API for $REPO..."

  curl -fsSL -H "User-Agent: $USER_AGENT" "$API" |
    grep '"browser_download_url":' |
    grep -Eo 'https://[^"]+\.jar' |
    head -n1
}

download_plugin() {
  NAME="$1"
  REPO="$2"

  log "Processing $NAME..."
  URL=$(extract_jar_url "$REPO") || {
    log "  [WARN] Failed to get URL for $NAME"
    return 1
  }

  [ -z "$URL" ] && {
    log "  [WARN] No .jar URL found for $NAME"
    return 1
  }

  FILENAME=$(basename "$URL")
  FILE="${NAME}-${FILENAME#${NAME}-}"

  if is_cached "$URL" && [ "$FORCE" -eq 0 ]; then
    log "  Skipping $NAME — already downloaded ($FILE)"
    return 0
  fi

  log "  Downloading $URL..."
  curl -fsSL -o "$FILE" "$URL" || fail "Failed to download $FILE"
  cache_url "$URL"
  log "  Downloaded: $FILE"
}

# Parse CLI arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--project)
      PROJECT="$2"
      shift 2
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    -c|--clean)
      CLEAN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --quiet)
      VERBOSE=0
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

main() {
  if [ "$CLEAN" -eq 1 ]; then
    cleanup
    exit 0
  fi

	touch "$CACHE_FILE" || fail "Unable to create $CACHE_FILE"

  REPO="ViaVersion/${PROJECT}"
  download_plugin "$PROJECT" "$REPO"

  log "Plugin update complete."
}

main


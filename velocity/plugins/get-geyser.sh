#! /bin/bash
set -f  # Disable globbing

PROJECT="geyser"
OUTPUT_FILE=""
CLEAN=0
FORCE=0
CACHE_FILE=".download.cache"
USER_AGENT="get-geyser/1.0.0 (https://github.com/scottsideleau/bootstrap-papermc)"
VERBOSE=1

# --- CLI Usage ---
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Downloads the latest Velocity plugin for a GeyserMC project (default: geyser).

Options:
  -p, --project <name>      Set project name (e.g., geyser, floodgate)
  -o, --output <filename>   Output filename (default: from Jenkins)
  -f, --force               Force re-download even if URL is cached
  -c, --clean               Remove cache file and exit
  -h, --help                Show this help message and exit

Examples:
  $0
  $0 --project floodgate
  $0 -p geyser -o geyser.jar
  $0 --force
  $0 --clean
EOF
}

# --- Logging and Error ---
log() {
  [ "$VERBOSE" -eq 1 ] && printf "%s\n" "$*"
}

fail() {
  printf "Error: %s\n" "$*" >&2
  exit 1
}

# --- Cache Functions ---
is_cached() {
  [ -f "$CACHE_FILE" ] && grep -qF "$1" "$CACHE_FILE"
}

cache_url() {
  printf "%s\n" "$1" >> "$CACHE_FILE"
}

cleanup() {
  log "Cleaning cache..."
  [ -f "$CACHE_FILE" ] && rm -f "$CACHE_FILE" && log "  Removed $CACHE_FILE"
}

# --- Argument Parser ---
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--project)
        shift
        PROJECT="${1:-}"
        ;;
      -o|--output)
        shift
        OUTPUT_FILE="${1:-}"
        ;;
      -f|--force)
        FORCE=1
        ;;
      -c|--clean)
        CLEAN=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
    shift
  done
}

# --- Download Plugin ---
download_plugin() {
  BASE_URL="https://download.geysermc.org/v2/projects/${PROJECT}/versions/latest/builds/latest/downloads/velocity"

  log "Resolved URL: $BASE_URL"

  if is_cached "$BASE_URL"; then
    if [ "$FORCE" -eq 1 ]; then
      log "Cached URL found, but --force is enabled. Re-downloading..."
    else
      log "Plugin already downloaded — skipping."
      return
    fi
  fi

  log "Downloading: $PROJECT"

  if [ -n "$OUTPUT_FILE" ]; then
    curl -fsSL -A "$USER_AGENT" -o "$OUTPUT_FILE" "$BASE_URL" || fail "Download failed"
    log "Download completed: $OUTPUT_FILE"
  else
    TMPDIR=$(mktemp -d)
    (
      cd "$TMPDIR" || fail "Unable to enter temp directory"
      curl -fsSL -A "$USER_AGENT" -OJ "$BASE_URL" || fail "Download failed"
    )
    FILE_DOWNLOADED=$(find "$TMPDIR" -type f | head -n1)
    [ -z "$FILE_DOWNLOADED" ] && fail "Unable to determine downloaded filename."

    ENCODED_NAME=$(basename "$FILE_DOWNLOADED")
    DECODED_NAME=$(echo "$ENCODED_NAME" | sed -E 's/=\?UTF-8\?Q\?//; s/\?=$//')
    mv "$FILE_DOWNLOADED" "./$DECODED_NAME"
    rmdir "$TMPDIR" 2>/dev/null || true
    log "Download completed: $DECODED_NAME"
  fi

  cache_url "$BASE_URL"
}

# --- Main Entry ---
main() {
  parse_args "$@"

  if [ "$CLEAN" -eq 1 ]; then
    cleanup
    exit 0
  fi

  download_plugin
}

main "$@"


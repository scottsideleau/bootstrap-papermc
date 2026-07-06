#! /bin/bash

set -f # Disable globbing

CACHE_FILE=".download.cache"
USER_AGENT="scottsideleau/bootstrap-papermc-get-modrinth/1.0.0 (https://github.com/scottsideleau/bootstrap-papermc)"

VERBOSE=1
FORCE=0
CLEAN=0

PROJECT=""
GAME_VERSION="26.1.2"
LOADER="paper"
VERSION_TYPE="release"
OUTPUT_FILE=""

TMP_DIR=""

usage()
{
 cat << EOF_USAGE
Usage: $0 [OPTIONS]

Downloads the newest matching file for a Modrinth project.

Options:
 -p, --project <id-or-slug>  Modrinth project ID or slug (required)
 -v, --version <version>     Minecraft version (default: 26.1.2)
 -l, --loader <loader>       Loader/platform (default: paper)
 -t, --type <type>           Version type: release, beta, or alpha
                             (default: release)
 -o, --output <filename>     Output filename
                             (default: Modrinth-provided filename)
 -f, --force                 Re-download even if URL is cached
 -c, --clean                 Remove cache file and exit
 -h, --help                  Show this help message and exit
 --quiet                     Suppress verbose logging

Examples:
 $0 -p mobsteer
 $0 -p hikarivehicle -v 26.1.2
 $0 -p buildpaste --loader paper --version 26.1.2
 $0 -p mobsteer --force
EOF_USAGE
}

log()
{
 [ "$VERBOSE" -eq 1 ] && printf "%s\n" "$*" >&2
}

fail()
{
 printf "Error: %s\n" "$*" >&2
 exit 1
}

cleanup_temp()
{
 [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}

cleanup_cache()
{
 log "Cleaning up..."
 [ -f "$CACHE_FILE" ] && rm -f "$CACHE_FILE" && log " Removed $CACHE_FILE"
}

is_cached()
{
 [ -f "$CACHE_FILE" ] || return 1
 grep -qF "$1" "$CACHE_FILE"
}

cache_url()
{
 touch "$CACHE_FILE" || fail "Unable to create $CACHE_FILE"
 grep -qF "$1" "$CACHE_FILE" 2> /dev/null || printf "%s\n" "$1" >> "$CACHE_FILE"
}

validate_token()
{
 VALUE="$1"
 LABEL="$2"

 [ -n "$VALUE" ] || fail "$LABEL cannot be empty"

 case "$VALUE" in
  *[!A-Za-z0-9._+-]*)
   fail "$LABEL contains unsupported characters: $VALUE"
   ;;
 esac
}

# Emit each top-level JSON object from an array on its own line.
# This small scanner avoids a jq dependency while respecting quoted strings,
# escaped characters, and nested objects.
split_top_level_objects()
{
 awk '
 BEGIN {
  depth = 0
  in_string = 0
  escaped = 0
  object = ""
 }
 {
  for (i = 1; i <= length($0); ++i) {
   c = substr($0, i, 1)

   if (in_string) {
    if (depth > 0) object = object c

    if (escaped) {
     escaped = 0
    } else if (c == "\\") {
     escaped = 1
    } else if (c == "\"") {
     in_string = 0
    }

    continue
   }

   if (c == "\"") {
    in_string = 1
    if (depth > 0) object = object c
    continue
   }

   if (c == "{") {
    depth++
    object = object c
    continue
   }

   if (c == "}" && depth > 0) {
    object = object c
    depth--

    if (depth == 0) {
     print object
     object = ""
    }

    continue
   }

   if (depth > 0) object = object c
  }
 }
 '
}

# Emit each object from the named JSON array. The input is one JSON object.
extract_array_objects()
{
 ARRAY_NAME="$1"

 awk -v key="\"${ARRAY_NAME}\"" '
 {
  source = $0
  key_pos = index(source, key)
  if (key_pos == 0) exit

  source = substr(source, key_pos + length(key))
  array_pos = index(source, "[")
  if (array_pos == 0) exit

  source = substr(source, array_pos)

  array_depth = 0
  object_depth = 0
  in_string = 0
  escaped = 0
  object = ""

  for (i = 1; i <= length(source); ++i) {
   c = substr(source, i, 1)

   if (in_string) {
    if (object_depth > 0) object = object c

    if (escaped) {
     escaped = 0
    } else if (c == "\\") {
     escaped = 1
    } else if (c == "\"") {
     in_string = 0
    }

    continue
   }

   if (c == "\"") {
    in_string = 1
    if (object_depth > 0) object = object c
    continue
   }

   if (c == "[") {
    array_depth++
    if (object_depth > 0) object = object c
    continue
   }

   if (c == "]") {
    if (object_depth > 0) object = object c
    array_depth--
    if (array_depth == 0) exit
    continue
   }

   if (c == "{" && array_depth > 0) {
    object_depth++
    object = object c
    continue
   }

   if (c == "}" && object_depth > 0) {
    object = object c
    object_depth--

    if (object_depth == 0) {
     print object
     object = ""
    }

    continue
   }

   if (object_depth > 0) object = object c
  }
 }
 '
}

extract_json_string()
{
 JSON_OBJECT="$1"
 JSON_KEY="$2"

 printf "%s\n" "$JSON_OBJECT" \
  | sed -n 's/.*"'"$JSON_KEY"'":"\([^"]*\)".*/\1/p' \
  | head -n1
}

select_version_object()
{
 printf "%s\n" "$1" \
  | split_top_level_objects \
  | while IFS= read -r OBJECT; do
     printf "%s\n" "$OBJECT" | grep -q '"version_type":"'"$VERSION_TYPE"'"' || continue
     printf "%s\n" "$OBJECT"
     break
    done
}

select_file_object()
{
 FILE_OBJECTS="$1"

 PRIMARY_OBJECT=$(
  printf "%s\n" "$FILE_OBJECTS" \
   | while IFS= read -r OBJECT; do
      printf "%s\n" "$OBJECT" | grep -q '"primary":true' || continue
      FILENAME=$(extract_json_string "$OBJECT" "filename")
      case "$FILENAME" in
       *.jar)
        printf "%s\n" "$OBJECT"
        break
        ;;
      esac
     done
 )

 if [ -n "$PRIMARY_OBJECT" ]; then
  printf "%s\n" "$PRIMARY_OBJECT"
  return 0
 fi

 printf "%s\n" "$FILE_OBJECTS" \
  | while IFS= read -r OBJECT; do
     FILENAME=$(extract_json_string "$OBJECT" "filename")
     case "$FILENAME" in
      *.jar)
       printf "%s\n" "$OBJECT"
       break
       ;;
     esac
    done
}

verify_sha512()
{
 EXPECTED="$1"
 FILE="$2"
 ACTUAL=""

 [ -n "$EXPECTED" ] || {
  log "Warning: Modrinth did not provide a SHA-512 hash; skipping verification."
  return 0
 }

 if command -v sha512sum > /dev/null 2>&1; then
  ACTUAL=$(sha512sum "$FILE" | awk '{ print $1 }')
 elif command -v shasum > /dev/null 2>&1; then
  ACTUAL=$(shasum -a 512 "$FILE" | awk '{ print $1 }')
 else
  log "Warning: neither sha512sum nor shasum is available; skipping verification."
  return 0
 fi

 [ "$ACTUAL" = "$EXPECTED" ] || fail "SHA-512 verification failed for $FILE"
 log "SHA-512 verified."
}

fetch_metadata()
{
 log "Querying Modrinth API for $PROJECT..."

 DATA=$(curl -fsSL \
  -H "User-Agent: $USER_AGENT" \
  -H "Accept: application/json" \
  "$API_URL") || fail "Unable to contact Modrinth API"

 [ -n "$DATA" ] || fail "Empty response from Modrinth API"
 printf "%s\n" "$DATA" | grep -qi '<html' && fail "Unexpected HTML response from Modrinth API"

 printf "%s\n" "$DATA"
}

parse_args()
{
 while [ $# -gt 0 ]; do
  case "$1" in
   -p | --project)
    [ $# -ge 2 ] || fail "$1 requires a value"
    PROJECT="$2"
    shift 2
    ;;
   -v | --version)
    [ $# -ge 2 ] || fail "$1 requires a value"
    GAME_VERSION="$2"
    shift 2
    ;;
   -l | --loader)
    [ $# -ge 2 ] || fail "$1 requires a value"
    LOADER="$2"
    shift 2
    ;;
   -t | --type)
    [ $# -ge 2 ] || fail "$1 requires a value"
    VERSION_TYPE="$2"
    shift 2
    ;;
   -o | --output)
    [ $# -ge 2 ] || fail "$1 requires a value"
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
   --quiet)
    VERBOSE=0
    shift
    ;;
   -h | --help)
    usage
    exit 0
    ;;
   *)
    fail "Unknown option: $1"
    ;;
  esac
 done
}

main()
{
 parse_args "$@"

 if [ "$CLEAN" -eq 1 ]; then
  cleanup_cache
  exit 0
 fi

 [ -n "$PROJECT" ] || {
  usage >&2
  fail "A Modrinth project ID or slug is required"
 }

 validate_token "$PROJECT" "Project"
 validate_token "$GAME_VERSION" "Minecraft version"
 validate_token "$LOADER" "Loader"

 case "$VERSION_TYPE" in
  release | beta | alpha)
   ;;
  *)
   fail "Version type must be release, beta, or alpha"
   ;;
 esac

 API_URL="https://api.modrinth.com/v2/project/${PROJECT}/version?loaders=%5B%22${LOADER}%22%5D&game_versions=%5B%22${GAME_VERSION}%22%5D&include_changelog=false"

 JSON_DATA=$(fetch_metadata)
 VERSION_OBJECT=$(select_version_object "$JSON_DATA")

 [ -n "$VERSION_OBJECT" ] || fail "No $VERSION_TYPE version found for project '$PROJECT' with loader '$LOADER' on Minecraft '$GAME_VERSION'"

 VERSION_NUMBER=$(extract_json_string "$VERSION_OBJECT" "version_number")
 FILE_OBJECTS=$(printf "%s\n" "$VERSION_OBJECT" | extract_array_objects "files")
 FILE_OBJECT=$(select_file_object "$FILE_OBJECTS")

 [ -n "$FILE_OBJECT" ] || fail "No downloadable .jar file found in the selected version"

 URL=$(extract_json_string "$FILE_OBJECT" "url")
 FILENAME=$(extract_json_string "$FILE_OBJECT" "filename")
 SHA512=$(extract_json_string "$FILE_OBJECT" "sha512")

 [ -n "$URL" ] || fail "Could not determine download URL"
 [ -n "$FILENAME" ] || fail "Could not determine downloaded filename"

 if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$FILENAME"
 fi

 log "Resolved version: ${VERSION_NUMBER:-unknown}"
 log "Resolved URL: $URL"

 if is_cached "$URL" && [ -f "$OUTPUT_FILE" ] && [ "$FORCE" -eq 0 ]; then
  log "Plugin already downloaded — skipping ($OUTPUT_FILE)."
  exit 0
 fi

 TMP_DIR=$(mktemp -d) || fail "Unable to create temporary directory"
 trap cleanup_temp 0 HUP INT TERM
 TMP_FILE="$TMP_DIR/$FILENAME"

 log "Downloading: $PROJECT"
 curl -fsSL -A "$USER_AGENT" -o "$TMP_FILE" "$URL" || fail "Download failed"

 verify_sha512 "$SHA512" "$TMP_FILE"
 mv "$TMP_FILE" "$OUTPUT_FILE" || fail "Unable to move download to $OUTPUT_FILE"

 cache_url "$URL"
 log "Download completed: $OUTPUT_FILE"

 cleanup_temp
 TMP_DIR=""
 trap - 0 HUP INT TERM
}

main "$@"

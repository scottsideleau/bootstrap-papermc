#! /bin/bash

TRACKED_VERSION="${TRACKED_VERSION:-26.2}"
MOBILITY_KIT="${MOBILITY_KIT:-0}"

rm -f -- *.jar

./get-viaversion.sh "$@"
./get-viaversion.sh -p ViaBackwards "$@"
./get-viaversion.sh -p ViaRewind "$@"

if [ "${MOBILITY_KIT:-0}" = "1" ]; then
    echo "Mobility Kit enabled."
    ./get-modrinth.sh -p mobsteer -v "$TRACKED_VERSION" "$@"
    ./get-modrinth.sh -p hikarivehicle -v "$TRACKED_VERSION" "$@"
    ./get-modrinth.sh -p aerograpple -v "$TRACKED_VERSION" "$@"
fi

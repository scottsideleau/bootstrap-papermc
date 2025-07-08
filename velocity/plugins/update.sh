#! /bin/bash

rm -f -- *.jar

./get-geyser.sh "$@"
./get-geyser.sh -p floodgate "$@"

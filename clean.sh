#! /bin/bash

./bootstrap.sh -c
find . -maxdepth 1 -name "*.jar" -exec rm {} \+

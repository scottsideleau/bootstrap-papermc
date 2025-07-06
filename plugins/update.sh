#! /bin/bash

rm -f *.jar

./get-viaversion.sh $@
./get-viaversion.sh -p ViaBackwards $@
./get-viaversion.sh -p ViaRewind $@


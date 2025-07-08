#! /bin/bash

QUIET="> /dev/null"

rm -f -- *.jar 

echo -e " --- Update PaperMC ---"
./get-papermc.sh "$@"

for file in paper-*.jar; do
    [ -e "$file" ] || continue
    ln -sf "$file" paper.jar
    echo "Created symlink: paper.jar -> $file"
    break
done

echo -e "--- Update PaperMC's plug-ins ---"
eval "pushd plugins $QUIET"
./update.sh "$@"
eval "popd $QUIET"

echo -e "--- Update Velocity proxy ---"
eval "pushd velocity $QUIET"
./update.sh "$@"
eval "popd $QUIET"

echo -e "--- Update Velocity's plug-ins ---"
eval "pushd velocity/plugins $QUIET"
./update.sh "$@"
eval "popd $QUIET"


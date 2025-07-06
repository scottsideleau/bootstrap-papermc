#! /bin/sh

rm -f *.jar

./get-velocity.sh $@

for file in velocity-*.jar; do
    [ -e "$file" ] || continue
    ln -sf "$file" velocity.jar
    echo "Created symlink: velocity.jar -> $file"
    break
done


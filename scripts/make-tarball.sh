#!/bin/bash
# Assemble <ge-tag>-deadlock.tar.gz: GE's official release with the files this repo's patches
# change swapped for the ones built in <ge-checkout>/build.
#
#   make-tarball.sh <ge-checkout> <ge-tag> <out-dir>
#
# Needs: gh (authenticated for downloads), tar, sha512sum, objcopy, and for the PE files
# x86_64-w64-mingw32-objcopy / i686-w64-mingw32-objcopy.

set -euo pipefail

ge="$(cd "$1" && pwd)"
tag="$2"
out="$(mkdir -p "$3" && cd "$3" && pwd)"
build="$ge/build"
name="$tag-deadlock"
upstream="$tag-x86_64"
work="$out/work"

rm -rf "$work"
mkdir -p "$work"

# GE's release, verified against the checksum it ships
gh release download "$tag" --repo GloriousEggroll/proton-ge-custom \
    --pattern "$upstream.tar.gz" --pattern "$upstream.sha512sum" --dir "$work"
(cd "$work" && sha512sum -c "$upstream.sha512sum")
tar -xzf "$work/$upstream.tar.gz" -C "$work"
dist="$work/$upstream"

# the one build output of $2 matching the find pattern $1; anything but exactly one is an error
built() { # <path-glob> <file name>
    local hits
    mapfile -t hits < <(find "$build" -type f -name "$2" -path "$1")
    [ "${#hits[@]}" = 1 ] || { echo "::error::want 1 $2 matching $1 under build/, got ${#hits[@]}: ${hits[*]:-}" >&2; exit 1; }
    printf '%s\n' "${hits[0]}"
}

# replace <relative path in the tool> <built file> <objcopy to strip debug info with>
replace() {
    local rel="$1" src="$2" objcopy="$3" dest="$dist/files/$1" mode
    [ -f "$dest" ] || { echo "::error::$rel is not in GE's release" >&2; exit 1; }
    mode=$(stat -c %a "$dest")
    chmod u+w "$dest"          # GE ships these read-only
    "$objcopy" --strip-debug "$src" "$dest"
    chmod "$mode" "$dest"
    echo "replaced $rel ($(stat -c %s "$dest") bytes)"
}

replace bin/wineserver                            "$(built '*/dst-wine-x86_64/bin/*' wineserver)"                      objcopy
replace lib/wine/x86_64-unix/ntdll.so             "$(built '*/dst-wine-x86_64/lib/wine/x86_64-unix/*' ntdll.so)"       objcopy
replace lib/wine/i386-unix/ntdll.so               "$(built '*/dst-wine-i386/lib/wine/i386-unix/*' ntdll.so)"           objcopy
replace lib/wine/x86_64-windows/ntdll.dll         "$(built '*/dst-wine-x86_64/lib/wine/x86_64-windows/*' ntdll.dll)"   x86_64-w64-mingw32-objcopy
replace lib/wine/i386-windows/ntdll.dll           "$(built '*/dst-wine-i386/lib/wine/i386-windows/*' ntdll.dll)"       i686-w64-mingw32-objcopy
replace lib/wine/x86_64-windows/lsteamclient.dll  "$(built '*/x86_64-windows/*' lsteamclient.dll)"                    x86_64-w64-mingw32-objcopy
replace lib/wine/i386-windows/lsteamclient.dll    "$(built '*/i386-windows/*' lsteamclient.dll)"                       i686-w64-mingw32-objcopy

# Steam and Proton key the tool and its prefixes by name
for f in compatibilitytool.vdf version; do
    grep -q "$upstream\|$tag" "$dist/$f" || { echo "::error::$f does not mention $tag" >&2; exit 1; }
done
sed -i "s/\"$upstream\"/\"$name\"/g" "$dist/compatibilitytool.vdf"
sed -i "s/ $tag\$/ $name/" "$dist/version"
grep -q "\"$name\" // Internal name" "$dist/compatibilitytool.vdf"
grep -q " $name\$" "$dist/version"

mv "$dist" "$work/$name"
tar --sort=name --owner=0 --group=0 --numeric-owner -C "$work" -czf "$out/$name.tar.gz" "$name"
(cd "$out" && sha512sum "$name.tar.gz" > "$name.sha512sum")
rm -rf "$work"
ls -l "$out"

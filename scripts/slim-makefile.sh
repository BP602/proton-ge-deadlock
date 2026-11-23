#!/bin/bash
# Trim GE's Makefile.in so `make wine lsteamclient` does not build the speech and media libraries
# (ffmpeg, openfst, kaldi, vosk, piper) that only other Wine modules use. This build only
# needs ntdll, wineserver and lsteamclient; everything else comes from GE's own release.
#
#   slim-makefile.sh <ge-checkout>

set -euo pipefail

mk="$(cd "$1" && pwd)/Makefile.in"

replace() { # exact-line old, new ("" deletes the line)
    local old="$1" new="$2" n
    n=$(grep -cxF -- "$old" "$mk" || true)
    [ "$n" = 1 ] || { echo "::error::Makefile.in: line found $n times (want 1): $old" >&2; exit 1; }
    if [ -n "$new" ]; then
        awk -v old="$old" -v new="$new" '$0 == old { print new; next } { print }' "$mk" > "$mk.new"
    else
        awk -v old="$old" '$0 != old { print }' "$mk" > "$mk.new"
    fi
    mv "$mk.new" "$mk"
}

replace 'WINE_DEPENDS = ffmpeg openfst kaldi vosk libxml2 libxkbcommon libpcap' \
        'WINE_DEPENDS = libxml2 libxkbcommon libpcap'
replace 'WINE_x86_64_DEPENDS = piper-phonemize piper vkd3d openxr' \
        'WINE_x86_64_DEPENDS = vkd3d openxr'
replace '  --with-ffmpeg \' ''
echo "slimmed $mk"

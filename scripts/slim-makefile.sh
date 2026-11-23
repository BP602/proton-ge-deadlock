#!/bin/bash
# Trim GE's Makefile.in so `make lsteamclient` does not build the speech libraries (openfst,
# kaldi, vosk, piper) that only other Wine modules use. This build only needs ntdll, wineserver
# and lsteamclient; everything else comes from GE's own release.
#
#   slim-makefile.sh <ge-checkout>

set -euo pipefail

mk="$(cd "$1" && pwd)/Makefile.in"

replace() { # exact-line old, new
    local old="$1" new="$2" n
    n=$(grep -cxF -- "$old" "$mk" || true)
    [ "$n" = 1 ] || { echo "::error::Makefile.in: line found $n times (want 1): $old" >&2; exit 1; }
    awk -v old="$old" -v new="$new" '$0 == old { print new; next } { print }' "$mk" > "$mk.new"
    mv "$mk.new" "$mk"
}

# ffmpeg stays: GE's winedmo links against it and `make wine` builds winedmo
replace 'WINE_DEPENDS = ffmpeg openfst kaldi vosk libxml2 libxkbcommon libpcap' \
        'WINE_DEPENDS = ffmpeg libxml2 libxkbcommon libpcap'
replace 'WINE_x86_64_DEPENDS = piper-phonemize piper vkd3d openxr' \
        'WINE_x86_64_DEPENDS = vkd3d openxr'
echo "slimmed $mk"

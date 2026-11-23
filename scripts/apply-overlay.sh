#!/bin/bash
# Hook this repo's patches into a proton-ge-custom checkout's protonprep-valve-staging.sh.
#
#   apply-overlay.sh <ge-checkout>
#
# - patches/lsteamclient/*.patch run in the Proton source root right after GE's own lsteamclient patches.
# - patches/wine/*.patch run in the wine tree after every GE/staging patch and before
#   `autoreconf -f; ./tools/make_requests`, which regenerates the wineserver protocol files that
#   0003-socket-shm-polling.patch changes (protocol.def).
#
# CI runs protonprep with `|| true`, so a failing hook cannot fail the build by itself. Each hook
# touches "$DEADLOCK_STATE/<name>" on success; `verify` checks for them.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prep_rel="patches/protonprep-valve-staging.sh"

case "${1:-}" in
verify)
    state="${DEADLOCK_STATE:?DEADLOCK_STATE not set}"
    for name in lsteamclient wine; do
        [ -e "$state/$name" ] || { echo "::error::deadlock $name patches were not applied" >&2; exit 1; }
    done
    echo "deadlock patches applied: lsteamclient wine"
    exit 0
    ;;
"")
    echo "usage: $0 <ge-checkout> | verify" >&2
    exit 2
    ;;
esac

ge="$(cd "$1" && pwd)"
prep="$ge/$prep_rel"
: "${DEADLOCK_STATE:?DEADLOCK_STATE not set}"
mkdir -p "$DEADLOCK_STATE"
rm -f "$DEADLOCK_STATE/lsteamclient" "$DEADLOCK_STATE/wine"

# Anchors in GE's script. Each must occur exactly once, or GE changed layout and the hook is unsafe.
lsc_anchor='    apply_all_in_dir "patches/lsteamclient"'
wine_anchor='    echo "WINE: RUN AUTOCONF TOOLS/MAKE_REQUESTS"'
for a in "$lsc_anchor" "$wine_anchor"; do
    n=$(grep -cxF -- "$a" "$prep" || true)
    [ "$n" = 1 ] || { echo "::error::anchor found $n times in $prep_rel (want 1): $a" >&2; exit 1; }
done

mkdir -p "$ge/patches/deadlock"
cp -a "$here/patches/lsteamclient" "$here/patches/wine" "$ge/patches/deadlock/"

lsc_hook='    deadlock_apply "patches/deadlock/lsteamclient" lsteamclient'
wine_hook='    deadlock_apply "../patches/deadlock/wine" wine'

awk -v lsc_anchor="$lsc_anchor" -v lsc_hook="$lsc_hook" \
    -v wine_anchor="$wine_anchor" -v wine_hook="$wine_hook" '
    NR == 1 { print; next }
    # function definition goes right after the shebang
    FNR == 2 && !defined {
        defined = 1
        print "deadlock_apply() {"
        print "    local dir=\"$1\" name=\"$2\" p"
        print "    for p in \"$dir\"/*.patch; do"
        print "        echo \"DEADLOCK: $p\""
        print "        patch -Np1 --fuzz=0 < \"$p\" || { echo \"DEADLOCK: $p failed\" >&2; exit 1; }"
        print "    done"
        print "    touch \"$DEADLOCK_STATE/$name\""
        print "}"
        print ""
    }
    $0 == wine_anchor { print wine_hook }
    { print }
    $0 == lsc_anchor { print lsc_hook }
' "$prep" > "$prep.new"
mv "$prep.new" "$prep"
chmod +x "$prep"
echo "hooked $prep_rel"

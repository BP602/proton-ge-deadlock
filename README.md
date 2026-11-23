# GE-Proton Deadlock build

[GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) with the Wine and lsteamclient patches from [HoppCX/deadlock-linux-optimizations](https://github.com/HoppCX/deadlock-linux-optimizations), published as a complete compatibility tool per GE release (`GE-ProtonX-Y-deadlock`). It is GE's official release with only `wineserver`, `ntdll` and `lsteamclient.dll` replaced by builds of the patched source, so there is no overlay to copy over an existing GE folder.

Measured gain for Deadlock is about 8-9% FPS over unpatched GE-Proton; see the upstream repository for the method and per-patch numbers.

## Patches

Rebased onto GE-Proton11-14 (the upstream repository's patches target 11-11 and no longer apply). Applying cleanly with `--fuzz=0` and a syntax-only `gcc` check of the touched files are the only checks done on the rebase; it has not been run or benchmarked.

| Patch | Applied to | Notes |
|---|---|---|
| `patches/wine/0001-ntdll-qpc-rdtsc.patch` | wine | `rdtsc` instead of `rdtscp` for QueryPerformanceCounter. Opt-in with `WINE_QPC_TSC_UNORDERED=1`. The original's persistent clocksource handle is dropped: GE-Proton 11-12 and later read the clocksource only once at start-up. |
| `patches/wine/0002-ntdll-sync-fast-paths.patch` | wine | Event/semaphore reuse, SRW lock and WaitOnAddress fast paths. |
| `patches/wine/0003-socket-shm-polling.patch` | wine | Socket event state in wineserver shared memory. Changes the wineserver protocol, so `wineserver` and both `ntdll.so` must be replaced together; the release does. |
| `patches/lsteamclient/0001-skip-env-sync-on-callback-polling.patch` | lsteamclient | Skips the per-frame environment scan on callback polling. |

## Install

Download `GE-ProtonX-Y-deadlock.tar.gz` and its `.sha512sum` from [Releases](../../releases), then close Steam and:

```sh
sha512sum -c GE-ProtonX-Y-deadlock.sha512sum
mkdir -p ~/.steam/root/compatibilitytools.d
tar -xf GE-ProtonX-Y-deadlock.tar.gz -C ~/.steam/root/compatibilitytools.d/
```

Flatpak Steam: extract to `~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/` instead.

Restart Steam, select `GE-ProtonX-Y-deadlock` for Deadlock, and set the launch options to:

```
WINE_QPC_TSC_UNORDERED=1 %command% -vulkan
```

## Releases and CI

`.github/workflows/release.yml` runs hourly and on manual dispatch (optional `ge_tag` input). It:

1. Finds the latest GE release (or the requested tag). If `<tag>-deadlock` already exists as a release here, it stops.
2. Checks out that GE tag with all submodules and hooks `patches/` into `protonprep-valve-staging.sh` (`scripts/apply-overlay.sh`):
   - lsteamclient patches right after GE's own lsteamclient patches;
   - wine patches after all GE and staging wine patches, before `autoreconf -f; ./tools/make_requests`, so the protocol changes in `0003` are regenerated.
3. Applies `scripts/slim-makefile.sh`, which drops the speech libraries (openfst, kaldi, vosk, piper) from Wine's build dependencies, and builds only `make wine lsteamclient` with GE's own `configure.sh` in its Docker container.
4. `scripts/make-tarball.sh` downloads GE's official `<tag>-x86_64.tar.gz`, checks it against GE's `.sha512sum`, replaces `bin/wineserver`, the i386 and x86_64 `ntdll` (`.so` and `.dll`) and `lsteamclient.dll`, renames the tool to `<tag>-deadlock` in `compatibilitytool.vdf` and `version`, and repacks it.
5. Publishes `<tag>-deadlock.tar.gz` and `.sha512sum` as a release.

Patches are applied with `--fuzz=0`. If a new GE release no longer applies cleanly, the run fails and no release is published; the patch needs a rebase. To rebuild an existing version, delete its release and dispatch the workflow.

## Building locally

Check out a GE tag with submodules, then follow the workflow's Patch, Configure and Make steps with `scripts/apply-overlay.sh`, `scripts/slim-makefile.sh` and `make wine lsteamclient` (`DEADLOCK_STATE` set to a scratch directory), and finish with `scripts/make-tarball.sh <ge-checkout> <ge-tag> <out-dir>`.

## License

The patches are LGPL-2.1-or-later like Wine; they were written by the authors of the upstream repository linked above.

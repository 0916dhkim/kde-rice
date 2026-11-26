#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="/usr/src/kde-rice-shapecorners"
STATE_DIR="/var/lib/kde-rice"
MANIFEST="$STATE_DIR/shapecorners.manifest"

if [ ! -f "$SRC_DIR/CMakeLists.txt" ]; then
    echo "[kde-rice] Source directory $SRC_DIR not found; skipping shapecorners build." >&2
    exit 0
fi

BUILD_DIR="$(mktemp -d /tmp/kde-rice-shapecorners-build.XXXXXX)"
LOG_FILE="$BUILD_DIR/build.log"
trap 'rm -rf "$BUILD_DIR"' EXIT

kwin_ver="$(pacman -Q kwin 2>/dev/null | awk '{print $2}' || echo 'unknown')"

if ! (
    cmake -S "$SRC_DIR" -B "$BUILD_DIR/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DQT_MAJOR_VERSION=6 \
        -DBUILD_TESTING=OFF
    cmake --build "$BUILD_DIR/build" --parallel
    cmake --install "$BUILD_DIR/build"
) >"$LOG_FILE" 2>&1; then
    echo "" >&2
    echo "========================================================================" >&2
    echo "[kde-rice] ERROR: Failed to compile kwin4_effect_shapecorners for KWin $kwin_ver!" >&2
    echo "[kde-rice] KWin C++ effect API may have changed; update vendored source in kde-rice." >&2
    echo "------------------------------------------------------------------------" >&2
    tail -n 40 "$LOG_FILE" >&2
    echo "========================================================================" >&2
    exit 1
fi

install -d -m 755 "$STATE_DIR"
# Remove any stale files from an older manifest that are no longer installed
if [ -f "$MANIFEST" ]; then
    while IFS= read -r old_file; do
        [ -n "$old_file" ] || continue
        if ! grep -Fxq "$old_file" "$BUILD_DIR/build/install_manifest.txt"; then
            rm -f "$old_file"
        fi
    done < "$MANIFEST"
fi
install -m 644 "$BUILD_DIR/build/install_manifest.txt" "$MANIFEST"

echo "[kde-rice] Built and installed kwin4_effect_shapecorners for KWin $kwin_ver."

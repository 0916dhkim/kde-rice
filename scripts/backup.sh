#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/kde-rice/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/$STAMP"

mkdir -p "$DEST"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
FILES=(
    "plasma-org.kde.plasma.desktop-appletsrc"
    "plasmashellrc"
    "plasmarc"
    "kdeglobals"
    "kwinrc"
)

copied=0
for f in "${FILES[@]}"; do
    if [[ -f "$CONFIG_DIR/$f" ]]; then
        cp -p "$CONFIG_DIR/$f" "$DEST/$f"
        copied=$((copied + 1))
    fi
done

echo "$DEST" > "$BACKUP_ROOT/latest"
echo "Backed up $copied Plasma config file(s) to $DEST"

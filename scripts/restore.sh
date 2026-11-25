#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/kde-rice/backups"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ $# -ge 1 ]]; then
    SRC="$1"
elif [[ -f "$BACKUP_ROOT/latest" ]]; then
    SRC="$(cat "$BACKUP_ROOT/latest")"
else
    echo "Error: no backup found under $BACKUP_ROOT" >&2
    exit 1
fi

if [[ ! -d "$SRC" ]]; then
    echo "Error: backup directory does not exist: $SRC" >&2
    exit 1
fi

mkdir -p "$CONFIG_DIR"

restored=0
for f in "$SRC"/*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    cp -p "$f" "$CONFIG_DIR/$base"
    restored=$((restored + 1))
done

echo "Restored $restored config file(s) from $SRC"

if [[ "${KDE_RICE_NO_RELOAD:-0}" != "1" ]]; then
    if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active plasma-plasmashell.service >/dev/null 2>&1; then
        systemctl --user restart plasma-plasmashell.service
        echo "Restarted plasma-plasmashell.service"
    else
        echo "Note: reload plasmashell manually (e.g. systemctl --user restart plasma-plasmashell.service)"
    fi
fi

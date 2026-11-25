#!/usr/bin/env bash
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

PLASMOIDS=(
    "dev.danny.nordic.workspaces"
    "dev.danny.nordic.windowtitle"
    "dev.danny.nordic.clock"
    "dev.danny.nordic.sysstat"
)

for id in "${PLASMOIDS[@]}"; do
    dst="$DATA_HOME/plasma/plasmoids/$id"
    if [[ -L "$dst" ]]; then
        rm -f "$dst"
        echo "Removed symlinked plasmoid $id"
    elif command -v kpackagetool6 >/dev/null 2>&1 && kpackagetool6 --type Plasma/Applet --show "$id" >/dev/null 2>&1; then
        kpackagetool6 --type Plasma/Applet --remove "$id"
    elif [[ -d "$dst" ]]; then
        rm -rf "$dst"
        echo "Removed plasmoid $id"
    fi
done

rm -rf "$DATA_HOME/plasma/desktoptheme/nordic-glass"
rm -f "$DATA_HOME/color-schemes/NordicMinimal.colors"
rm -f "$DATA_HOME/wallpapers/nordic-mist.png"

echo "Removed kde-rice plasmoids, theme, color scheme, and wallpaper."
echo "Run ./scripts/restore.sh if you also want to restore your previous Plasma panel configs."

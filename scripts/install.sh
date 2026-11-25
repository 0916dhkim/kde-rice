#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
THEME_DST="$DATA_HOME/plasma/desktoptheme/nordic-glass"
COLORS_DST="$DATA_HOME/color-schemes/NordicMinimal.colors"
WALL_DST="$DATA_HOME/wallpapers/nordic-mist.png"

APPLY_COLORS=1
APPLY_WALLPAPER=1
APPLY_LAYOUT=1
DO_BACKUP=1
DEV_SYMLINK=0

usage() {
    cat <<'EOF'
Usage: ./scripts/install.sh [options]

Options:
  --no-colors      Do not apply the NordicMinimal color scheme
  --no-wallpaper   Do not apply the Nordic Mist wallpaper
  --no-layout      Install theme & plasmoids only; do not modify panels
  --no-backup      Skip pre-install config backup
  --dev            Symlink plasmoids & theme for live editing
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-colors) APPLY_COLORS=0 ;;
        --no-wallpaper) APPLY_WALLPAPER=0 ;;
        --no-layout) APPLY_LAYOUT=0 ;;
        --no-backup) DO_BACKUP=0 ;;
        --dev) DEV_SYMLINK=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

if [[ "$DO_BACKUP" -eq 1 ]]; then
    "$SCRIPT_DIR/backup.sh"
fi

# 1. Install custom Plasma 6 plasmoids
PLASMOIDS=(
    "dev.danny.nordic.workspaces"
    "dev.danny.nordic.windowtitle"
    "dev.danny.nordic.clock"
    "dev.danny.nordic.sysstat"
)

mkdir -p "$DATA_HOME/plasma/plasmoids"
for id in "${PLASMOIDS[@]}"; do
    src="$REPO_ROOT/plasmoids/$id"
    dst="$DATA_HOME/plasma/plasmoids/$id"
    if [[ "$DEV_SYMLINK" -eq 1 ]]; then
        rm -rf "$dst"
        ln -s "$src" "$dst"
        echo "Linked plasmoid $id -> $dst"
    elif command -v kpackagetool6 >/dev/null 2>&1; then
        if kpackagetool6 --type Plasma/Applet --show "$id" >/dev/null 2>&1; then
            kpackagetool6 --type Plasma/Applet --upgrade "$src"
        else
            kpackagetool6 --type Plasma/Applet --install "$src"
        fi
    else
        rm -rf "$dst"
        cp -R "$src" "$dst"
        echo "Copied plasmoid $id -> $dst"
    fi
done

# 2. Install Nordic Glass Plasma desktop theme
mkdir -p "$(dirname "$THEME_DST")"
rm -rf "$THEME_DST"
if [[ "$DEV_SYMLINK" -eq 1 ]]; then
    ln -s "$REPO_ROOT/themes/nordic-glass" "$THEME_DST"
    echo "Linked theme nordic-glass -> $THEME_DST"
else
    cp -R "$REPO_ROOT/themes/nordic-glass" "$THEME_DST"
    echo "Installed theme nordic-glass -> $THEME_DST"
fi

# 3. Install Nordic Minimal color scheme & wallpaper
mkdir -p "$(dirname "$COLORS_DST")" "$(dirname "$WALL_DST")"
cp "$REPO_ROOT/colors/NordicMinimal.colors" "$COLORS_DST"
cp "$REPO_ROOT/wallpaper/nordic-mist.png" "$WALL_DST"

# 4. Apply desktop theme, color scheme, wallpaper (when running inside a Plasma session)
if command -v plasma-apply-desktoptheme >/dev/null 2>&1; then
    plasma-apply-desktoptheme nordic-glass
fi

if [[ "$APPLY_COLORS" -eq 1 ]] && command -v plasma-apply-colorscheme >/dev/null 2>&1; then
    plasma-apply-colorscheme NordicMinimal
fi

if [[ "$APPLY_WALLPAPER" -eq 1 ]] && command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALL_DST"
fi

# 5. Apply declarative 2-panel layout (top floating bar + bottom autohide floating dock)
if [[ "$APPLY_LAYOUT" -eq 1 ]]; then
    QDBUS_BIN=""
    if command -v qdbus6 >/dev/null 2>&1; then
        QDBUS_BIN="qdbus6"
    elif command -v qdbus >/dev/null 2>&1; then
        QDBUS_BIN="qdbus"
    fi

    if [[ -n "$QDBUS_BIN" ]]; then
        LAUNCHER_ICON="$THEME_DST/icons/nordic-launcher.svg"
        LAYOUT_JS="$(sed "s|__LAUNCHER_ICON__|$LAUNCHER_ICON|g" "$SCRIPT_DIR/apply-layout.js")"
        "$QDBUS_BIN" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$LAYOUT_JS"
        echo "Applied Nordic top bar + floating autohide bottom dock layout."
    else
        echo "Warning: qdbus6/qdbus not found; skipped live layout script." >&2
    fi
fi

echo "Done. To revert configs, run: ./scripts/restore.sh"

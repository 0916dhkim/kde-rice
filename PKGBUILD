# Maintainer: Danny Kim <0916dhkim@gmail.com>
pkgname=kde-rice-git
pkgver=0.1.0.r1.g0b94525
pkgrel=1
pkgdesc="Nordic Minimal Plasma 6 Global Theme, plasmoids, frosted glass style, and autohide dock layout"
arch=('any')
url="https://github.com/0916dhkim/kde-rice"
license=('MIT' 'OFL-1.1')
depends=(
    'plasma-workspace'
    'plasma-desktop'
    'plasma-pa'
    'libksysguard'
    'kwin-effect-rounded-corners-git'
)
makedepends=('git')
provides=('kde-rice')
conflicts=('kde-rice')
source=("kde-rice::git+https://github.com/0916dhkim/kde-rice.git")
sha256sums=('SKIP')

pkgver() {
    cd "$srcdir/kde-rice"
    printf "0.1.0.r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
}

package() {
    cd "$srcdir/kde-rice"

    # Custom Plasma 6 QML plasmoids
    install -d "$pkgdir/usr/share/plasma/plasmoids"
    cp -r plasmoids/* "$pkgdir/usr/share/plasma/plasmoids/"

    # Nordic Glass Plasma desktop theme
    install -d "$pkgdir/usr/share/plasma/desktoptheme"
    cp -r themes/nordic-glass "$pkgdir/usr/share/plasma/desktoptheme/"

    # Nordic Minimal Global Theme (Look and Feel)
    install -d "$pkgdir/usr/share/plasma/look-and-feel"
    cp -r look-and-feel/dev.danny.nordic "$pkgdir/usr/share/plasma/look-and-feel/"

    # Nordic Minimal color scheme
    install -Dm644 colors/NordicMinimal.colors \
        "$pkgdir/usr/share/color-schemes/NordicMinimal.colors"

    # Nordic Mist wallpaper package
    install -d "$pkgdir/usr/share/wallpapers"
    cp -r wallpapers/NordicMist "$pkgdir/usr/share/wallpapers/"

    # Nordic Icons overlay theme (inherits breeze-dark)
    install -d "$pkgdir/usr/share/icons"
    cp -a icons/nordic-icons "$pkgdir/usr/share/icons/"

    # Bundled Manrope static UI font cuts (SIL OFL 1.1; Regular/Medium/SemiBold/Bold)
    install -Dm644 fonts/manrope/Manrope-*.ttf -t "$pkgdir/usr/share/fonts/nordic-manrope/"
    install -Dm644 fonts/manrope/OFL.txt "$pkgdir/usr/share/licenses/$pkgname/OFL-Manrope.txt"

    # KWin 6 borderless windows script + system-wide XDG kwinrc defaults (rounded corners + outlines + shadows + switcher)
    install -d "$pkgdir/usr/share/kwin/scripts"
    cp -r kwin/scripts/nordic-notitlebar "$pkgdir/usr/share/kwin/scripts/"
    install -Dm644 kwin/kwinrc "$pkgdir/etc/xdg/kwinrc"

    # Plasma 6 Editorial Nordic Minimal lock screen (Plasma/Shell package + KWin-only systemd user drop-in + default wallpaper)
    install -d "$pkgdir/usr/share/plasma/shells"
    cp -r kscreenlocker/shells/dev.danny.nordic.lockscreen "$pkgdir/usr/share/plasma/shells/"
    install -Dm644 kscreenlocker/nordic-lockscreen.conf \
        "$pkgdir/usr/lib/systemd/user/plasma-kwin_wayland.service.d/nordic-lockscreen.conf"
    install -Dm644 kscreenlocker/kscreenlockerrc "$pkgdir/etc/xdg/kscreenlockerrc"

    # Normalize permissions cleanly for system installation (preserve symlinks)
    find "$pkgdir/usr/share" -type d -exec chmod 755 {} +
    find "$pkgdir/usr/share" -type f ! -type l -exec chmod 644 {} +
}

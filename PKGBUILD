# Maintainer: Danny Kim <0916dhkim@gmail.com>
pkgname=kde-rice-git
pkgver=0.1.0.r1.g0b94525
pkgrel=1
pkgdesc="Nordic Minimal Plasma 6 Global Theme, plasmoids, frosted glass style, adaptive switcher, lock screen, SDDM, and titlebar-free KDecoration3 resize borders"
arch=('x86_64')
url="https://github.com/0916dhkim/kde-rice"
license=('MIT' 'OFL-1.1' 'GPL-3.0-or-later')
depends=(
    'plasma-workspace'
    'plasma-desktop'
    'plasma-pa'
    'libksysguard'
    'kwin'
    'kdecoration'
    'cmake'
    'extra-cmake-modules'
    'ninja'
    'gcc'
    'pkgconf'
    'gettext'
    'vulkan-headers'
    'libepoxy'
    'kconfigwidgets'
    'ki18n'
    'kcmutils'
)
makedepends=('git')
provides=('kde-rice' 'kwin-effect-rounded-corners')
conflicts=('kde-rice' 'kwin-effect-rounded-corners' 'kwin-effect-rounded-corners-git')
options=('!debug')
install=kde-rice.install
source=("kde-rice::git+https://github.com/0916dhkim/kde-rice.git")
sha256sums=('SKIP')

pkgver() {
    cd "$srcdir/kde-rice"
    printf "0.1.0.r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
}

build() {
    cmake -S "$srcdir/kde-rice/kwin/decorations/nordic-borderless" \
          -B "$srcdir/build-nordic-borderless" \
          -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build "$srcdir/build-nordic-borderless"
}

package() {
    cd "$srcdir/kde-rice"

    # Custom Plasma 6 QML plasmoids
    install -d "$pkgdir/usr/share/plasma/plasmoids"
    cp -r plasmoids/* "$pkgdir/usr/share/plasma/plasmoids/"

    # Nordic Glass Plasma desktop theme
    install -d "$pkgdir/usr/share/plasma/desktoptheme"
    cp -r themes/nordic-glass "$pkgdir/usr/share/plasma/desktoptheme/"

    # Nordic Minimal Global Theme (Look and Feel + adaptive WindowSwitcher)
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

    # KWin 6 titlebar-free KDecoration3 plugin (0px titlebar + 8px invisible edge resize grips) + system-wide XDG kwinrc/ksplashrc defaults
    DESTDIR="$pkgdir" cmake --install "$srcdir/build-nordic-borderless"
    install -Dm644 kwin/kwinrc "$pkgdir/etc/xdg/kwinrc"
    install -Dm644 kwin/ksplashrc "$pkgdir/etc/xdg/ksplashrc"

    # DKMS-style vendored KDE-Rounded-Corners (shapecorners) source + PostTransaction rebuild hook on kwin updates
    install -d "$pkgdir/usr/src/kde-rice-shapecorners"
    cp -r kwin/effects/shapecorners/. "$pkgdir/usr/src/kde-rice-shapecorners/"
    install -Dm644 kwin/effects/shapecorners/LICENSE \
        "$pkgdir/usr/share/licenses/$pkgname/GPL-3.0-KDE-Rounded-Corners.txt"
    install -Dm755 kwin/kde-rice-shapecorners-build.sh \
        "$pkgdir/usr/lib/kde-rice/rebuild-shapecorners.sh"
    install -Dm644 kwin/hooks/90-kde-rice-shapecorners-rebuild.hook \
        "$pkgdir/usr/share/libalpm/hooks/90-kde-rice-shapecorners-rebuild.hook"

    # Plasma 6 Editorial Nordic Minimal lock screen (Plasma/Shell package + KWin-only systemd user drop-in + default wallpaper)
    install -d "$pkgdir/usr/share/plasma/shells"
    cp -r kscreenlocker/shells/dev.danny.nordic.lockscreen "$pkgdir/usr/share/plasma/shells/"
    install -Dm644 kscreenlocker/nordic-lockscreen.conf \
        "$pkgdir/usr/lib/systemd/user/plasma-kwin_wayland.service.d/nordic-lockscreen.conf"
    install -Dm644 kscreenlocker/kscreenlockerrc "$pkgdir/etc/xdg/kscreenlockerrc"

    # Centered Midnight Horizon SDDM Qt6 theme (#11 Icelandic Volcanic Ring Road + Wayland HiDPI drop-in)
    install -d "$pkgdir/usr/share/sddm/themes"
    cp -r sddm/themes/nordic-minimal "$pkgdir/usr/share/sddm/themes/"
    install -Dm644 sddm/z-nordic-minimal.conf "$pkgdir/etc/sddm.conf.d/z-nordic-minimal.conf"

    # Normalize permissions cleanly for system installation (preserve symlinks)
    find "$pkgdir/usr/share" -type d -exec chmod 755 {} +
    find "$pkgdir/usr/share" -type f ! -type l -exec chmod 644 {} +
    find "$pkgdir/usr/src/kde-rice-shapecorners" -type d -exec chmod 755 {} +
    find "$pkgdir/usr/src/kde-rice-shapecorners" -type f -exec chmod 644 {} +
}

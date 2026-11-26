# kde-rice — Nordic Minimal for KDE Plasma 6

A cohesive dark Nordic desktop setup for KDE Plasma 6, packaged as an Arch Linux `PKGBUILD`.

## System Requirements

- **OS:** Arch Linux (`x86_64`)
- **Desktop:** KDE Plasma 6 (Wayland)
- **Display Manager (optional):** SDDM (for the login theme)
- **Packaging:** `paru` (or `makepkg` + `pacman`)

## Features

- **Nordic Glass Desktop & Color Scheme:** Dark frosted slate panels, popups, dialogs, and system colors with frost-teal and sage accents, paired with bundled **Manrope** UI typography.
- **Floating Top Bar & Autohiding Dock:** Minimal floating top bar (launcher button, workspace indicator, active window title, centered clock, CPU/volume/battery status with charging indicator, system tray) and a centered autohiding squircle app dock.
- **Spotlight-Style App Launcher:** Centered keyboard-driven launcher with fuzzy/acronym/frecency search, existing-window focusing, and Lock Screen quick action.
- **Titlebar-Free Rounded Windows:** Zero-titlebar windows with invisible edge/corner resize handles, 12px squircle corners, sage active / frost-teal inactive outlines, and smooth focus transitions.
- **Adaptive Window Switcher:** Label-free squircle icon strip for `Alt+Tab` (one icon per app) and an icon-free live-thumbnail filmstrip for `Alt+\`` (same-app windows).
- **Nordic Icon Overlay:** Thin-stroke monochrome icons for the top bar, popups, System Settings, and Dolphin sidebar, plus dark frosted 64px folders and 3:4 file icons for Desktop and Dolphin.
- **4K Wallpapers & Liquid-Ripple Splash:** Paired 4K Nordic road wallpapers with an organic liquid-ripple login splash transition.
- **Editorial Lock Screen & SDDM Login Theme:** Left-aligned editorial lock screen with fingerprint/password support, and a matching centered midnight-horizon SDDM login screen with keyboard navigation and user/session switching.

## Install

```bash
paru -S kde-rice-git
plasma-apply-lookandfeel -a dev.danny.nordic --resetLayout
```

To enable the SDDM login screen:

```bash
sudo systemctl enable --force sddm.service
```

## License

MIT (theme & widgets), SIL OFL 1.1 (Manrope fonts), and GPL-3.0-or-later (rounded-corners effect).

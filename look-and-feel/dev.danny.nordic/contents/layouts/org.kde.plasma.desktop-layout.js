// KDE Plasma 6 Global Theme desktop layout — Nordic Minimal + Floating Autohide Dock

(function () {
    const LAUNCHER_ICON = "/usr/share/plasma/desktoptheme/nordic-glass/icons/nordic-launcher.svg";
    const DEFAULT_LAUNCHERS = [
        "applications:com.mitchellh.ghostty.desktop",
        "applications:org.kde.dolphin.desktop",
        "applications:firefox.desktop",
        "applications:systemsettings.desktop"
    ];

    function captureExistingLaunchers() {
        const existingPanels = panels();
        for (let i = 0; i < existingPanels.length; ++i) {
            const widgets = existingPanels[i].widgets();
            for (let j = 0; j < widgets.length; ++j) {
                const w = widgets[j];
                if (w.type === "org.kde.plasma.icontasks" || w.type === "org.kde.plasma.taskmanager") {
                    w.currentConfigGroup = ["General"];
                    const saved = w.readConfig("launchers", "");
                    if (saved && String(saved).trim().length > 0) {
                        return saved;
                    }
                }
            }
        }
        return DEFAULT_LAUNCHERS;
    }

    const preservedLaunchers = captureExistingLaunchers();

    // Remove any remaining panels before creating the Nordic layout.
    const existingPanels = panels();
    for (let i = 0; i < existingPanels.length; ++i) {
        existingPanels[i].remove();
    }

    // 1. Floating Slim Nordic Top Bar (always visible)
    const topBar = new Panel();
    topBar.location = "top";
    topBar.height = 34;
    topBar.floating = true;
    topBar.lengthMode = "fill";
    topBar.hiding = "none";
    if (typeof topBar.opacity !== "undefined") {
        topBar.opacity = "translucent";
    }

    const launcher = topBar.addWidget("org.kde.plasma.kickoff");
    launcher.currentConfigGroup = ["General"];
    launcher.writeConfig("icon", LAUNCHER_ICON);
    launcher.writeConfig("favoritesPortedToKAstats", true);

    topBar.addWidget("dev.danny.nordic.workspaces");
    topBar.addWidget("dev.danny.nordic.windowtitle");

    topBar.addWidget("org.kde.plasma.panelspacer");
    topBar.addWidget("dev.danny.nordic.clock");
    topBar.addWidget("org.kde.plasma.panelspacer");

    topBar.addWidget("dev.danny.nordic.sysstat");

    const systray = topBar.addWidget("org.kde.plasma.systemtray");
    systray.currentConfigGroup = ["General"];
    systray.writeConfig("iconSpacing", 1);

    // 2. Centered Floating Nordic Bottom App Dock (autohide overlay; windows do not avoid it)
    const dock = new Panel();
    dock.location = "bottom";
    dock.height = 54;
    dock.floating = true;
    dock.alignment = "center";
    dock.lengthMode = "fit";
    dock.hiding = "autohide";
    if (typeof dock.opacity !== "undefined") {
        dock.opacity = "translucent";
    }

    const tasks = dock.addWidget("org.kde.plasma.icontasks");
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("fill", false);
    tasks.writeConfig("showOnlyCurrentDesktop", false);
    tasks.writeConfig("showOnlyCurrentScreen", false);
    tasks.writeConfig("groupingStrategy", 1);
    tasks.writeConfig("launchers", preservedLaunchers);

    // Ensure desktops keep the standard image wallpaper plugin (matches Breeze look-and-feel).
    if (typeof desktopsForActivity === "function" && typeof currentActivity === "function") {
        const desktopsArray = desktopsForActivity(currentActivity());
        for (let i = 0; i < desktopsArray.length; ++i) {
            desktopsArray[i].wallpaperPlugin = "org.kde.image";
        }
    }
})();

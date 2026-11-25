// KWin 6 script: hide server-side titlebars and frames on all regular windows and dialogs.

function shouldHideTitlebar(window) {
    if (!window) {
        return false;
    }
    if (window.specialWindow || window.desktopWindow || window.dock || window.popupWindow || window.splash) {
        return false;
    }
    return Boolean(window.normalWindow || window.dialog || window.utility);
}

function applyNoBorder(window) {
    if (!shouldHideTitlebar(window)) {
        return;
    }
    if (!window.noBorder) {
        window.noBorder = true;
    }
}

function trackWindow(window) {
    applyNoBorder(window);
    if (window && window.fullScreenChanged) {
        window.fullScreenChanged.connect(() => {
            if (!window.fullScreen) {
                applyNoBorder(window);
            }
        });
    }
}

workspace.windowAdded.connect(trackWindow);
workspace.windowList().forEach(trackWindow);

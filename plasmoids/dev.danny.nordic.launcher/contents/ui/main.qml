pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml.Models
import org.kde.layershell 1.0 as LayerShell
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import "../code/fuzzy.js" as Fuzzy

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    activationTogglesExpanded: false

    property bool launcherOpen: false
    property double lastClosedMs: 0
    property string query: ""
    property int selectedIndex: 0
    property var allAppsModel: null
    property var appCatalog: []
    property var rankedResults: []
    property var launchCounts: ({})

    readonly property var builtInActions: [
        {
            id: "action:lock",
            name: "Lock Screen",
            icon: "system-lock-screen",
            keywords: "lockscreen",
            kind: "session",
            actionId: "lock",
            defaultRank: 5,
            prefixBoost: 120
        }
    ]

    Connections {
        target: Plasmoid
        function onActivated(): void {
            root.toggleLauncher();
        }
    }

    // RootModel populates KICKER_ALL_MODEL (flat list of all installed .desktop apps)
    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        flat: false
        sorted: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        showSeparators: false
        appletInterface: root

        onRefreshed: root.attachAllAppsModel()
        onCountChanged: root.attachAllAppsModel()
        onModelReset: root.attachAllAppsModel()
    }

    function attachAllAppsModel(): void {
        let found = null;
        for (let i = 0; i < rootModel.count; ++i) {
            const sub = rootModel.modelForRow(i);
            if (sub && sub.description === "KICKER_ALL_MODEL") {
                found = sub;
                break;
            }
        }
        if (found !== root.allAppsModel) {
            root.allAppsModel = found;
        }
        catalogTimer.restart();
    }

    Instantiator {
        id: appCollector
        model: root.allAppsModel
        delegate: QtObject {
            required property int index
            required property var model
            readonly property string appName: String(model.display || "")
            readonly property string appDesc: String(model.description || "")
            readonly property string appFavId: String(model.favoriteId || "")
            readonly property var appIcon: model.decoration
        }
        onObjectAdded: catalogTimer.restart()
        onObjectRemoved: catalogTimer.restart()
    }

    Timer {
        id: catalogTimer
        interval: 60
        repeat: false
        onTriggered: root.rebuildCatalog()
    }

    Sessions.SessionManagement {
        id: sessionMgmt
    }

    // Tracks open windows across all virtual desktops so Enter focuses an existing app instead of spawning duplicates
    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        filterHidden: true
    }

    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
        }
    }

    function loadLaunchCounts(): void {
        try {
            // qmllint disable missing-property
            const raw = String(Plasmoid.configuration.launchCounts || "{}");
            // qmllint enable missing-property
            const parsed = JSON.parse(raw);
            if (parsed && typeof parsed === "object") {
                launchCounts = parsed;
            }
        } catch (e) {
            launchCounts = ({});
        }
    }

    function recordLaunch(id: string): void {
        if (!id) {
            return;
        }
        const next = Object.assign({}, launchCounts);
        next[id] = Number(next[id] || 0) + 1;
        launchCounts = next;
        // qmllint disable missing-property
        Plasmoid.configuration.launchCounts = JSON.stringify(next);
        // qmllint enable missing-property
    }

    function parseCustomActions(): var {
        try {
            // qmllint disable missing-property
            const raw = String(Plasmoid.configuration.customActions || "[]");
            // qmllint enable missing-property
            const parsed = JSON.parse(raw);
            if (!Array.isArray(parsed)) {
                return [];
            }
            const out = [];
            for (let i = 0; i < parsed.length; ++i) {
                const a = parsed[i];
                if (a && a.name && a.command) {
                    out.push({
                        id: "custom:" + String(a.id || a.name),
                        name: String(a.name),
                        icon: String(a.icon || "system-run"),
                        keywords: String(a.keywords || ""),
                        kind: "command",
                        command: String(a.command),
                        defaultRank: Number(a.defaultRank || 0),
                        prefixBoost: Number(a.prefixBoost || 0)
                    });
                }
            }
            return out;
        } catch (e) {
            return [];
        }
    }

    function rebuildCatalog(): void {
        const items = [];
        const seen = {};
        const total = appCollector.count;

        for (let i = 0; i < total; ++i) {
            const obj = appCollector.objectAt(i);
            if (!obj) {
                continue;
            }
            // qmllint disable missing-property
            const name = obj.appName;
            const favId = obj.appFavId;
            const desc = obj.appDesc;
            const icon = obj.appIcon;
            const row = obj.index;
            // qmllint enable missing-property
            if (!name) {
                continue;
            }
            const key = "app:" + (favId || name.toLowerCase());
            if (seen[key]) {
                continue;
            }
            seen[key] = true;

            let defaultRank = 0;
            const lower = name.toLowerCase();
            if (lower === "ghostty") defaultRank = 18;
            else if (lower === "obsidian") defaultRank = 16;
            else if (lower.indexOf("chrome") >= 0) defaultRank = 14;
            else if (lower === "dolphin") defaultRank = 12;
            else if (lower === "system settings") defaultRank = 10;
            else if (lower === "firefox") defaultRank = 8;

            items.push({
                id: key,
                name: name,
                icon: icon,
                favId: favId,
                keywords: desc + " " + favId,
                kind: "app",
                appRow: row,
                defaultRank: defaultRank
            });
        }

        const actions = builtInActions.concat(parseCustomActions());
        for (let j = 0; j < actions.length; ++j) {
            items.push(actions[j]);
        }

        appCatalog = items;
        refreshResults();
    }

    function refreshResults(): void {
        rankedResults = Fuzzy.rankItems(appCatalog, query, launchCounts, 6);
        if (selectedIndex >= rankedResults.length) {
            selectedIndex = Math.max(0, rankedResults.length - 1);
        } else if (selectedIndex < 0 && rankedResults.length > 0) {
            selectedIndex = 0;
        }
    }

    function openLauncher(): void {
        root.query = "";
        root.selectedIndex = 0;
        root.refreshResults();
        root.launcherOpen = true;
        spotlightWindow.width = spotlightWindow.targetWidth;
        spotlightWindow.height = spotlightWindow.targetHeight;
        spotlightWindow.show();
        spotlightWindow.requestActivate();
        focusTimer.restart();
    }

    function closeLauncher(): void {
        if (!root.launcherOpen && !spotlightWindow.visible) {
            return;
        }
        root.launcherOpen = false;
        root.lastClosedMs = Date.now();
        spotlightWindow.hide();
    }

    function toggleLauncher(): void {
        if (root.launcherOpen || spotlightWindow.visible) {
            closeLauncher();
            return;
        }
        // Avoid reopen race when clicking the panel button caused focus-loss dismiss milliseconds earlier
        if (Date.now() - root.lastClosedMs < 180) {
            return;
        }
        openLauncher();
    }

    function runSessionAction(actionId: string): void {
        closeLauncher();
        if (actionId === "lock") {
            sessionMgmt.lock();
        } else if (actionId === "sleep") {
            sessionMgmt.suspend();
        } else if (actionId === "restart") {
            sessionMgmt.requestReboot();
        } else if (actionId === "shutdown") {
            sessionMgmt.requestShutdown();
        } else if (actionId === "logout") {
            sessionMgmt.requestLogout();
        }
    }

    function focusExistingWindow(favId: string, appName: string): bool {
        const targetId = Fuzzy.normalizeDesktopId(favId);
        const targetName = String(appName || "").trim().toLowerCase();
        const total = tasksModel.count;
        let fallbackRow = -1;

        for (let i = 0; i < total; ++i) {
            const idx = tasksModel.makeModelIndex(i);
            if (!tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow)) {
                continue;
            }
            const winLauncher = Fuzzy.normalizeDesktopId(
                tasksModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
            );
            const winAppId = Fuzzy.normalizeDesktopId(
                tasksModel.data(idx, TaskManager.AbstractTasksModel.AppId)
            );
            const winName = String(
                tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName) || ""
            ).trim().toLowerCase();

            const idMatch = targetId.length > 0 && (winLauncher === targetId || winAppId === targetId);
            const nameMatch = targetName.length > 0 && winName === targetName;

            if (idMatch || nameMatch) {
                const isActive = Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive));
                if (!isActive) {
                    tasksModel.requestActivate(idx);
                    return true;
                }
                if (fallbackRow < 0) {
                    fallbackRow = i;
                }
            }
        }

        if (fallbackRow >= 0) {
            tasksModel.requestActivate(tasksModel.makeModelIndex(fallbackRow));
            return true;
        }
        return false;
    }

    function activateResult(index: int, forceNewWindow: bool): void {
        if (index < 0 || index >= rankedResults.length) {
            return;
        }
        const entry = rankedResults[index];
        recordLaunch(entry.id);
        closeLauncher();

        if (entry.kind === "app" && entry.appRow >= 0 && root.allAppsModel) {
            if (!forceNewWindow && focusExistingWindow(entry.favId, entry.name)) {
                return;
            }
            root.allAppsModel.trigger(entry.appRow, "", null);
        } else if (entry.kind === "session") {
            runSessionAction(entry.actionId);
        } else if (entry.kind === "command" && entry.command) {
            execSource.connectSource(entry.command);
        }
    }

    onQueryChanged: {
        selectedIndex = 0;
        refreshResults();
    }

    Component.onCompleted: {
        loadLaunchCounts();
        rootModel.refresh();
        attachAllAppsModel();
    }

    Timer {
        id: focusTimer
        interval: 20
        repeat: false
        onTriggered: {
            searchInput.forceActiveFocus();
            searchInput.selectAll();
        }
    }

    // Centered upper-third Spotlight/Raycast overlay window via Wayland zwlr_layer_shell_v1
    PlasmaCore.Window {
        id: spotlightWindow

        visible: false
        flags: Qt.FramelessWindowHint | Qt.Dialog
        borders: Qt.TopEdge | Qt.BottomEdge | Qt.LeftEdge | Qt.RightEdge

        LayerShell.Window.anchors: LayerShell.Window.AnchorTop
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.activateOnShow: true
        LayerShell.Window.wantsToBeOnActiveScreen: true
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.scope: "nordic-launcher"
        LayerShell.Window.margins.top: Math.max(90, Math.round(Screen.height * 0.20))

        readonly property int targetWidth: popupRoot.implicitWidth + leftPadding + rightPadding
        readonly property int targetHeight: popupRoot.implicitHeight + topPadding + bottomPadding

        width: targetWidth
        height: targetHeight

        onTargetHeightChanged: {
            if (visible) {
                height = targetHeight;
            }
        }

        onActiveChanged: {
            if (!active && visible) {
                root.closeLauncher();
            }
        }

        mainItem: PlasmaExtras.Representation {
            id: popupRoot

            collapseMarginsHint: true
            leftPadding: -9
            rightPadding: -9
            topPadding: -9
            bottomPadding: -9

            readonly property int rowHeight: 38
            readonly property int visibleRows: Math.max(1, Math.min(6, root.rankedResults.length))
            readonly property int listHeight: visibleRows * rowHeight + (visibleRows - 1) * 2 + 16
            readonly property int totalInnerHeight: 48 + listHeight + 34

            implicitWidth: 440 - 18
            implicitHeight: totalInnerHeight - 18

            contentItem: ColumnLayout {
                spacing: 0

                // 1. Mockup 1 Search Bar (48px, edge-to-edge bottom hairline)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 10

                        Kirigami.Icon {
                            source: "preferences-desktop-search"
                            implicitWidth: 17
                            implicitHeight: 17
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                text: "Search apps & actions…"
                                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.42)
                                font.pixelSize: 14
                                visible: searchInput.text.length === 0
                            }

                            TextInput {
                                id: searchInput
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: root.query
                                color: "#eceff4"
                                selectionColor: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.35)
                                selectedTextColor: "#eceff4"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                clip: true
                                focus: true

                                onTextEdited: root.query = text

                                Keys.onDownPressed: function(event) {
                                    if (root.rankedResults.length > 0) {
                                        root.selectedIndex = (root.selectedIndex + 1) % root.rankedResults.length;
                                    }
                                    event.accepted = true;
                                }

                                Keys.onUpPressed: function(event) {
                                    if (root.rankedResults.length > 0) {
                                        root.selectedIndex = (root.selectedIndex - 1 + root.rankedResults.length) % root.rankedResults.length;
                                    }
                                    event.accepted = true;
                                }

                                Keys.onTabPressed: function(event) {
                                    if (root.rankedResults.length > 0) {
                                        root.selectedIndex = (root.selectedIndex + 1) % root.rankedResults.length;
                                    }
                                    event.accepted = true;
                                }

                                Keys.onBacktabPressed: function(event) {
                                    if (root.rankedResults.length > 0) {
                                        root.selectedIndex = (root.selectedIndex - 1 + root.rankedResults.length) % root.rankedResults.length;
                                    }
                                    event.accepted = true;
                                }

                                Keys.onReturnPressed: function(event) {
                                    root.activateResult(root.selectedIndex, Boolean(event.modifiers & Qt.ControlModifier));
                                    event.accepted = true;
                                }

                                Keys.onEnterPressed: function(event) {
                                    root.activateResult(root.selectedIndex, Boolean(event.modifiers & Qt.ControlModifier));
                                    event.accepted = true;
                                }

                                Keys.onEscapePressed: function(event) {
                                    root.closeLauncher();
                                    event.accepted = true;
                                }
                            }
                        }

                        // ESC / match-count pill
                        Rectangle {
                            implicitWidth: Math.max(24, badgeText.implicitWidth + 12)
                            implicitHeight: 20
                            radius: 5
                            color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.07)
                            border.width: 1
                            border.color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.12)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: root.query.length > 0 ? String(root.rankedResults.length) : "ESC"
                                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.56)
                                font.family: "monospace"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // Edge-to-edge hairline divider
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.11)
                    }
                }

                // 2. Minimal List Body (Just Icon + Name, up to 6 rows)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: popupRoot.listHeight
                    Layout.fillHeight: true

                    ListView {
                        id: resultsList
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 2
                        clip: true
                        interactive: contentHeight > height
                        currentIndex: root.selectedIndex
                        model: root.rankedResults

                        delegate: Rectangle {
                            id: rowItem
                            required property int index
                            required property var modelData

                            readonly property bool isSelected: rowItem.index === root.selectedIndex

                            width: resultsList.width
                            height: popupRoot.rowHeight
                            radius: 9
                            color: {
                                if (rowItem.isSelected) {
                                    return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.14);
                                }
                                if (rowMouse.containsMouse) {
                                    return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.06);
                                }
                                return "transparent";
                            }
                            border.width: rowItem.isSelected ? 1 : 0
                            border.color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.34)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: 7
                                    color: rowItem.isSelected
                                        ? Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.72)
                                        : Qt.rgba(38 / 255, 47 / 255, 62 / 255, 0.56)
                                    border.width: 1
                                    border.color: rowItem.isSelected
                                        ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.45)
                                        : Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.11)
                                    Layout.alignment: Qt.AlignVCenter

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        width: 16
                                        height: 16
                                        source: rowItem.modelData.icon
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: rowItem.modelData.displayHtml
                                    textFormat: Text.StyledText
                                    color: "#eceff4"
                                    font.pixelSize: 13
                                    font.weight: rowItem.isSelected ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: rowItem.isSelected
                                    implicitWidth: 20
                                    implicitHeight: 18
                                    radius: 5
                                    color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.14)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "⏎"
                                        color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.65)
                                        font.pixelSize: 10
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = rowItem.index
                                onClicked: function(mouse) {
                                    root.activateResult(rowItem.index, Boolean(mouse.modifiers & Qt.ControlModifier));
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.rankedResults.length === 0
                        text: "No matches"
                        color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.45)
                        font.pixelSize: 12
                    }
                }

                // 3. Full-Bleed Darker Bottom Bar (34px, right-aligned Move + Open hints)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height + 12
                        radius: 10
                        color: Qt.rgba(12 / 255, 16 / 255, 24 / 255, 0.45)
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.10)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 5
                            Rectangle {
                                implicitWidth: 22
                                implicitHeight: 17
                                radius: 4
                                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.07)
                                border.width: 1
                                border.color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.12)
                                Text {
                                    anchors.centerIn: parent
                                    text: "↑↓"
                                    color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.58)
                                    font.pixelSize: 9
                                }
                            }
                            Text {
                                text: "Move"
                                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.48)
                                font.pixelSize: 11
                            }
                        }

                        RowLayout {
                            spacing: 5
                            Rectangle {
                                implicitWidth: 19
                                implicitHeight: 17
                                radius: 4
                                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.07)
                                border.width: 1
                                border.color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.12)
                                Text {
                                    anchors.centerIn: parent
                                    text: "⏎"
                                    color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.58)
                                    font.pixelSize: 9
                                }
                            }
                            Text {
                                text: "Open"
                                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.48)
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }

    // Top-bar Arch Nordic launcher button (rendered inline on the top panel)
    fullRepresentation: PlasmaCore.ToolTipArea {
        id: compactRoot
        location: Plasmoid.location
        mainText: "Nordic Launcher"
        subText: "Press Meta to search apps & actions"

        implicitWidth: 28
        implicitHeight: 26
        Layout.minimumWidth: 28
        Layout.preferredWidth: 28
        Layout.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 26
            height: 24
            radius: 7
            color: {
                if (root.launcherOpen) {
                    return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.20);
                }
                if (compactMouse.containsMouse) {
                    return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.10);
                }
                return "transparent";
            }
            border.width: root.launcherOpen ? 1 : 0
            border.color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.42)

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 18
                height: 18
                // qmllint disable missing-property
                source: Plasmoid.configuration.icon || "start-here-kde-symbolic"
                // qmllint enable missing-property
            }
        }

        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleLauncher()
        }
    }
}

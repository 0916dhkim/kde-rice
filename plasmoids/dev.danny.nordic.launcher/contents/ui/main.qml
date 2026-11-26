pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml.Models
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import org.kde.kirigami as Kirigami
import "../code/fuzzy.js" as Fuzzy

PlasmoidItem {
    id: root

    switchWidth: 0
    switchHeight: 0
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    activationTogglesExpanded: true

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

    // Mirrors KICKER_ALL_MODEL rows via named roles and auto-refreshes when apps are installed/removed
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
                        defaultRank: Number(a.defaultRank || 0)
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

            // Give common daily apps a gentle empty-state default boost before frecency builds up
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
        rankedResults = Fuzzy.rankItems(appCatalog, query, launchCounts, 8);
        if (selectedIndex >= rankedResults.length) {
            selectedIndex = Math.max(0, rankedResults.length - 1);
        } else if (selectedIndex < 0 && rankedResults.length > 0) {
            selectedIndex = 0;
        }
    }

    function runSessionAction(actionId: string): void {
        root.expanded = false;
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

    function activateResult(index: int): void {
        if (index < 0 || index >= rankedResults.length) {
            return;
        }
        const entry = rankedResults[index];
        recordLaunch(entry.id);
        root.expanded = false;

        if (entry.kind === "app" && entry.appRow >= 0 && root.allAppsModel) {
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

    onExpandedChanged: function() {
        if (root.expanded) {
            root.query = "";
            root.selectedIndex = 0;
            root.refreshResults();
        }
    }

    Component.onCompleted: {
        loadLaunchCounts();
        rootModel.refresh();
        attachAllAppsModel();
    }

    // Top-bar Arch Nordic launcher button
    compactRepresentation: PlasmaCore.ToolTipArea {
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
                if (root.expanded) {
                    return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.20);
                }
                if (compactMouse.containsMouse) {
                    return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.10);
                }
                return "transparent";
            }
            border.width: root.expanded ? 1 : 0
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
            onClicked: root.expanded = !root.expanded
        }
    }

    // Spotlight-style minimal popover: Mockup 1 search bar + icon/name list + Mockup 1 bottom bar
    fullRepresentation: Item {
        id: popupRoot

        readonly property int rowHeight: 38
        readonly property int visibleRows: Math.max(1, Math.min(8, root.rankedResults.length))

        implicitWidth: 420
        implicitHeight: 48 + (visibleRows * rowHeight + (visibleRows - 1) * 2 + 16) + 34
        Layout.minimumWidth: 380
        Layout.preferredWidth: 420
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight

        Connections {
            target: root
            function onExpandedChanged(): void {
                if (root.expanded) {
                    focusTimer.restart();
                }
            }
        }

        Timer {
            id: focusTimer
            interval: 15
            repeat: false
            onTriggered: {
                searchInput.forceActiveFocus();
                searchInput.selectAll();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 1. Mockup 1 Search Bar (48px)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
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
                                root.activateResult(root.selectedIndex);
                                event.accepted = true;
                            }

                            Keys.onEnterPressed: function(event) {
                                root.activateResult(root.selectedIndex);
                                event.accepted = true;
                            }

                            Keys.onEscapePressed: function(event) {
                                if (root.query.length > 0) {
                                    root.query = "";
                                } else {
                                    root.expanded = false;
                                }
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

                // Hairline bottom divider
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.10)
                }
            }

            // 2. Minimal List Body (Just Icon + Name)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: resultsList
                    anchors.fill: parent
                    anchors.margins: 8
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

                            // Matching Nordic squircle icon tile
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

                            // Quiet Enter hint on the selected row only
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
                            onClicked: root.activateResult(rowItem.index)
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

            // 3. Mockup 1 Bottom Bar (34px) — Keyboard Hints + Power Actions
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: Qt.rgba(12 / 255, 16 / 255, 24 / 255, 0.45)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.09)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

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

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [
                            { id: "lock", icon: "system-lock-screen", label: "Lock Screen" },
                            { id: "sleep", icon: "system-suspend", label: "Sleep" },
                            { id: "restart", icon: "system-reboot", label: "Restart" },
                            { id: "shutdown", icon: "system-shutdown", label: "Shut Down" }
                        ]

                        delegate: PlasmaCore.ToolTipArea {
                            id: pwrBtn
                            required property var modelData
                            location: PlasmaCore.Types.BottomEdge
                            mainText: pwrBtn.modelData.label

                            implicitWidth: 24
                            implicitHeight: 24
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: pwrMouse.containsMouse
                                    ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.16)
                                    : "transparent"

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    source: pwrBtn.modelData.icon
                                }
                            }

                            MouseArea {
                                id: pwrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runSessionAction(pwrBtn.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}

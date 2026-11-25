pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Option A exact vertical geometry inside a 58px panel (4px panel SVG top/bottom margins -> 50px inner):
    // 5px inner top (+4px panel = 9px) | 36px squircle (y=5..41, center=23) | 4px gap | 3px pill (y=45..48) | 2px inner bottom (+4px panel = 6px)
    readonly property int innerHeight: 50
    readonly property int squircleSize: 36
    readonly property int squircleTopY: 5
    readonly property int indicatorY: 45
    readonly property int dividerHeight: 26

    property int dragFromIndex: -1
    property int pressedIndex: -1
    property bool syncingLaunchers: false
    property int dividerBeforeIndex: -1
    property int menuRow: -1

    TaskManager.TasksModel {
        id: tasksModel
        sortMode: TaskManager.TasksModel.SortManual
        groupMode: TaskManager.TasksModel.GroupApplications
        separateLaunchers: true
        launchInPlace: true
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        filterHidden: true

        onLauncherListChanged: {
            if (!root.syncingLaunchers) {
                root.syncingLaunchers = true;
                // qmllint disable missing-property
                Plasmoid.configuration.launchers = launcherList;
                // qmllint enable missing-property
                root.syncingLaunchers = false;
            }
            root.refreshDivider();
        }

        onCountChanged: root.refreshDivider()
        onDataChanged: root.refreshDivider()
        onRowsInserted: root.refreshDivider()
        onRowsRemoved: root.refreshDivider()
        onRowsMoved: root.refreshDivider()
        onModelReset: root.refreshDivider()
    }

    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key: string, value: var): void {
            if (key === "launchers" && !root.syncingLaunchers) {
                root.syncingLaunchers = true;
                tasksModel.launcherList = value;
                root.syncingLaunchers = false;
                root.refreshDivider();
            }
        }
    }

    function isRowPinned(row: int): bool {
        if (row < 0 || row >= tasksModel.count) {
            return false;
        }
        const idx = tasksModel.makeModelIndex(row);
        return Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.IsLauncher))
            || Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.HasLauncher));
    }

    function refreshDivider(): void {
        const total = tasksModel.count;
        let seenPinned = false;
        for (let i = 0; i < total; ++i) {
            if (isRowPinned(i)) {
                seenPinned = true;
            } else if (seenPinned) {
                dividerBeforeIndex = i;
                return;
            }
        }
        dividerBeforeIndex = -1;
    }

    function activateRow(row: int): void {
        if (row < 0 || row >= tasksModel.count) {
            return;
        }
        const idx = tasksModel.makeModelIndex(row);
        const isLauncher = Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.IsLauncher));
        if (isLauncher) {
            tasksModel.requestActivate(idx);
            return;
        }
        const isGroupParent = Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent));
        const childCount = Number(tasksModel.data(idx, TaskManager.AbstractTasksModel.ChildCount) || 0);
        if (isGroupParent && childCount > 1) {
            let activeChild = -1;
            for (let c = 0; c < childCount; ++c) {
                const cIdx = tasksModel.makeModelIndex(row, c);
                if (tasksModel.data(cIdx, TaskManager.AbstractTasksModel.IsActive)) {
                    activeChild = c;
                    break;
                }
            }
            const nextChild = activeChild >= 0 ? (activeChild + 1) % childCount : 0;
            tasksModel.requestActivate(tasksModel.makeModelIndex(row, nextChild));
            return;
        }
        const isActive = Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive));
        if (isActive) {
            tasksModel.requestToggleMinimized(idx);
        } else {
            tasksModel.requestActivate(idx);
        }
    }

    function moveTaskStep(fromRow: int, toRow: int): void {
        if (fromRow < 0 || toRow < 0 || fromRow === toRow) {
            return;
        }
        if (fromRow >= tasksModel.count || toRow >= tasksModel.count) {
            return;
        }
        if (tasksModel.move(fromRow, toRow)) {
            root.dragFromIndex = toRow;
        }
    }

    function pinUrls(urls: var): void {
        if (!urls || urls.length === 0) {
            return;
        }
        for (let i = 0; i < urls.length; ++i) {
            const u = String(urls[i]);
            if (u.length > 0 && (u.endsWith(".desktop") || u.startsWith("applications:"))) {
                tasksModel.requestAddLauncher(urls[i]);
            }
        }
        tasksModel.syncLaunchers();
    }

    Component.onCompleted: {
        root.syncingLaunchers = true;
        // qmllint disable missing-property
        tasksModel.launcherList = Plasmoid.configuration.launchers;
        // qmllint enable missing-property
        root.syncingLaunchers = false;
        Qt.callLater(root.refreshDivider);
    }

    fullRepresentation: Item {
        id: dockRoot
        implicitWidth: Math.max(root.squircleSize, iconsRow.implicitWidth)
        implicitHeight: root.innerHeight
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        function rowAtX(xPos: real): int {
            const total = taskRepeater.count;
            if (total <= 0) {
                return -1;
            }
            for (let i = 0; i < total; ++i) {
                const item = taskRepeater.itemAt(i);
                if (!item) {
                    continue;
                }
                const left = item.x - 4;
                const right = item.x + item.width + 4;
                if (xPos >= left && xPos <= right) {
                    return i;
                }
            }
            if (xPos < 0) {
                return 0;
            }
            return total - 1;
        }

        DropArea {
            id: externalDrop
            anchors.fill: parent
            onEntered: function(drag) {
                if (root.dragFromIndex >= 0) {
                    drag.accepted = false;
                    return;
                }
                drag.accepted = drag.hasUrls;
            }
            onDropped: function(drop) {
                if (drop.hasUrls) {
                    root.pinUrls(drop.urls);
                    drop.acceptProposedAction();
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.10)
            border.width: 1
            border.color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.45)
            visible: externalDrop.containsDrag
        }

        // Single stable MouseArea outside Repeater so dragging across multiple slots never cancels or shifts coordinates
        MouseArea {
            id: dockMouse
            anchors.fill: iconsRow
            z: -1
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: root.dragFromIndex >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property real pressX: 0
            property bool dragged: false
            property bool movedAny: false

            onPressed: function(mouse) {
                const idx = dockRoot.rowAtX(mouse.x);
                root.pressedIndex = idx;
                pressX = mouse.x;
                dragged = false;
                movedAny = false;
            }

            onPositionChanged: function(mouse) {
                if (!(mouse.buttons & Qt.LeftButton) || root.pressedIndex < 0) {
                    return;
                }
                if (!dragged && Math.abs(mouse.x - pressX) >= 8) {
                    dragged = true;
                    root.dragFromIndex = root.pressedIndex;
                }
                if (dragged && root.dragFromIndex >= 0) {
                    const targetIdx = dockRoot.rowAtX(mouse.x);
                    if (targetIdx >= 0 && targetIdx !== root.dragFromIndex) {
                        // Keep pinned drags inside pinned section and unpinned drags inside unpinned section
                        if (root.isRowPinned(root.dragFromIndex) === root.isRowPinned(targetIdx)) {
                            root.moveTaskStep(root.dragFromIndex, targetIdx);
                            movedAny = true;
                        }
                    }
                }
            }

            onReleased: function(mouse) {
                const wasDragged = dragged;
                const didMove = movedAny;
                const clickedRow = root.pressedIndex;

                dragged = false;
                movedAny = false;
                root.dragFromIndex = -1;
                root.pressedIndex = -1;

                if (wasDragged) {
                    if (didMove) {
                        tasksModel.syncLaunchers();
                        root.refreshDivider();
                    }
                    return;
                }
                if (clickedRow < 0 || clickedRow >= tasksModel.count) {
                    return;
                }
                if (mouse.button === Qt.LeftButton) {
                    root.activateRow(clickedRow);
                } else if (mouse.button === Qt.MiddleButton) {
                    tasksModel.requestNewInstance(tasksModel.makeModelIndex(clickedRow));
                } else if (mouse.button === Qt.RightButton) {
                    root.menuRow = clickedRow;
                    contextMenu.popup();
                }
            }

            onCanceled: {
                if (movedAny) {
                    tasksModel.syncLaunchers();
                    root.refreshDivider();
                }
                dragged = false;
                movedAny = false;
                root.dragFromIndex = -1;
                root.pressedIndex = -1;
            }
        }

        RowLayout {
            id: iconsRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                id: taskRepeater
                model: tasksModel

                delegate: RowLayout {
                    id: slotWrap
                    required property int index
                    required property var model

                    readonly property bool isLauncher: Boolean(slotWrap.model.IsLauncher)
                    readonly property bool isWindow: Boolean(slotWrap.model.IsWindow)
                    readonly property bool isStartup: Boolean(slotWrap.model.IsStartup)
                    readonly property bool isActive: Boolean(slotWrap.model.IsActive)
                    readonly property bool isAttention: Boolean(slotWrap.model.IsDemandingAttention)
                    readonly property bool isGroupParent: Boolean(slotWrap.model.IsGroupParent)
                    readonly property int childCount: Number(slotWrap.model.ChildCount || 0)
                    readonly property bool isRunning: isWindow || isStartup
                    readonly property bool showLeadingDivider: slotWrap.index === root.dividerBeforeIndex
                    readonly property string appName: String(slotWrap.model.AppName || slotWrap.model.display || "")
                    readonly property string winTitle: String(slotWrap.model.display || "")
                    readonly property bool isDraggingThis: root.dragFromIndex === slotWrap.index
                    readonly property bool isPressedThis: root.pressedIndex === slotWrap.index && root.dragFromIndex < 0

                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Vertical divider vertically dead-center aligned with the 36x36 squircle icons
                    Item {
                        visible: slotWrap.showLeadingDivider
                        implicitWidth: 5
                        implicitHeight: root.innerHeight
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.squircleTopY + Math.round((root.squircleSize - root.dividerHeight) / 2)
                            width: 1
                            height: root.dividerHeight
                            color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.24)
                        }
                    }

                    PlasmaCore.ToolTipArea {
                        id: taskTile
                        location: Plasmoid.location
                        mainText: slotWrap.appName
                        subText: {
                            if (slotWrap.isLauncher) {
                                return "Launch " + slotWrap.appName;
                            }
                            if (slotWrap.isGroupParent && slotWrap.childCount > 1) {
                                return slotWrap.childCount + " open windows";
                            }
                            if (slotWrap.winTitle && slotWrap.winTitle !== slotWrap.appName) {
                                return slotWrap.winTitle;
                            }
                            return "";
                        }

                        implicitWidth: root.squircleSize
                        implicitHeight: root.innerHeight
                        Layout.alignment: Qt.AlignVCenter
                        opacity: slotWrap.isDraggingThis ? 0.55 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }

                        Rectangle {
                            id: tileBg
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.squircleTopY
                            width: root.squircleSize
                            height: root.squircleSize
                            radius: 10
                            color: {
                                if (slotWrap.isActive) {
                                    return Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.74);
                                }
                                if (taskTile.containsMouse) {
                                    return Qt.rgba(54 / 255, 66 / 255, 84 / 255, 0.65);
                                }
                                return Qt.rgba(38 / 255, 47 / 255, 62 / 255, 0.54);
                            }
                            border.width: 1
                            border.color: {
                                if (slotWrap.isActive) {
                                    return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.54);
                                }
                                if (taskTile.containsMouse) {
                                    return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.22);
                                }
                                return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.11);
                            }

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: 120 }
                            }

                            Kirigami.Icon {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                source: slotWrap.model.decoration
                                scale: slotWrap.isPressedThis ? 0.92 : (taskTile.containsMouse ? 1.08 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: indicator
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.indicatorY
                            height: 3
                            radius: 1.5
                            visible: slotWrap.isRunning
                            width: {
                                if (slotWrap.isActive) {
                                    return 14;
                                }
                                if (slotWrap.isAttention) {
                                    return 10;
                                }
                                return 4;
                            }
                            color: {
                                if (slotWrap.isAttention) {
                                    return "#ebcb8b";
                                }
                                if (slotWrap.isActive) {
                                    return "#88c0d0";
                                }
                                return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.62);
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }
                    }
                }
            }
        }

        // Single shared context menu for right-click on any dock slot
        PlasmaComponents.Menu {
            id: contextMenu

            readonly property bool validRow: root.menuRow >= 0 && root.menuRow < tasksModel.count
            readonly property var rowIdx: validRow ? tasksModel.makeModelIndex(root.menuRow) : null
            readonly property bool rowPinned: validRow ? root.isRowPinned(root.menuRow) : false
            readonly property bool rowRunning: validRow
                ? (Boolean(tasksModel.data(rowIdx, TaskManager.AbstractTasksModel.IsWindow))
                   || Boolean(tasksModel.data(rowIdx, TaskManager.AbstractTasksModel.IsStartup)))
                : false
            readonly property bool rowGroup: validRow
                ? Boolean(tasksModel.data(rowIdx, TaskManager.AbstractTasksModel.IsGroupParent))
                : false
            readonly property int rowChildren: validRow
                ? Number(tasksModel.data(rowIdx, TaskManager.AbstractTasksModel.ChildCount) || 0)
                : 0
            readonly property var rowLauncherUrl: validRow
                ? tasksModel.data(rowIdx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
                : ""

            PlasmaComponents.MenuItem {
                text: "New Window"
                icon.name: "window-new"
                enabled: contextMenu.validRow
                onClicked: {
                    if (contextMenu.validRow) {
                        tasksModel.requestNewInstance(tasksModel.makeModelIndex(root.menuRow));
                    }
                }
            }

            PlasmaComponents.MenuItem {
                text: contextMenu.rowPinned ? "Unpin from Dock" : "Pin to Dock"
                icon.name: contextMenu.rowPinned ? "window-unpin" : "window-pin"
                enabled: contextMenu.validRow && contextMenu.rowLauncherUrl !== undefined && String(contextMenu.rowLauncherUrl).length > 0
                onClicked: {
                    if (!contextMenu.validRow) {
                        return;
                    }
                    if (contextMenu.rowPinned) {
                        tasksModel.requestRemoveLauncher(contextMenu.rowLauncherUrl);
                    } else {
                        tasksModel.requestAddLauncher(contextMenu.rowLauncherUrl);
                    }
                    tasksModel.syncLaunchers();
                    root.refreshDivider();
                }
            }

            PlasmaComponents.MenuSeparator {
                visible: contextMenu.rowRunning
            }

            PlasmaComponents.MenuItem {
                visible: contextMenu.rowRunning
                text: contextMenu.rowGroup && contextMenu.rowChildren > 1 ? "Close All Windows" : "Close"
                icon.name: "window-close"
                onClicked: {
                    if (!contextMenu.validRow) {
                        return;
                    }
                    if (contextMenu.rowGroup && contextMenu.rowChildren > 1) {
                        for (let c = contextMenu.rowChildren - 1; c >= 0; --c) {
                            tasksModel.requestClose(tasksModel.makeModelIndex(root.menuRow, c));
                        }
                    } else {
                        tasksModel.requestClose(tasksModel.makeModelIndex(root.menuRow));
                    }
                }
            }
        }
    }
}

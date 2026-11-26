pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
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
    readonly property int tileSpacing: 8
    readonly property int tileStep: squircleSize + tileSpacing
    readonly property int dividerExtra: 13

    property int dragFromIndex: -1
    property int pressedIndex: -1
    property bool syncingLaunchers: false
    property bool animatePositions: false
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
        Qt.callLater(function() {
            root.refreshDivider();
            root.animatePositions = true;
        });
    }

    fullRepresentation: Item {
        id: dockRoot

        readonly property int totalCount: tasksModel.count
        readonly property bool hasDivider: root.dividerBeforeIndex > 0 && root.dividerBeforeIndex < totalCount
        readonly property int rowWidth: totalCount > 0
            ? (totalCount * root.squircleSize + Math.max(0, totalCount - 1) * root.tileSpacing + (hasDivider ? root.dividerExtra : 0))
            : root.squircleSize

        implicitWidth: Math.max(root.squircleSize, rowWidth)
        implicitHeight: root.innerHeight
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        function slotX(idx: int): real {
            const extra = (hasDivider && idx >= root.dividerBeforeIndex) ? root.dividerExtra : 0;
            return idx * root.tileStep + extra;
        }

        function clampDragX(rawX: real, idx: int): real {
            const total = totalCount;
            if (total <= 1 || idx < 0) {
                return 0;
            }
            const pinned = root.isRowPinned(idx);
            let minIdx = 0;
            let maxIdx = total - 1;
            if (hasDivider) {
                if (pinned) {
                    maxIdx = root.dividerBeforeIndex - 1;
                } else {
                    minIdx = root.dividerBeforeIndex;
                }
            }
            const minX = slotX(minIdx);
            const maxX = slotX(maxIdx);
            return Math.max(minX, Math.min(maxX, rawX));
        }

        // Deterministic slot lookup using static slot geometry (prevents oscillation while neighbors animate)
        function rowAtX(xPos: real): int {
            const total = totalCount;
            if (total <= 0) {
                return -1;
            }
            let best = 0;
            let bestDist = 1e9;
            for (let i = 0; i < total; ++i) {
                const center = slotX(i) + root.squircleSize * 0.5;
                const d = Math.abs(xPos - center);
                if (d < bestDist) {
                    bestDist = d;
                    best = i;
                }
            }
            return best;
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
            property real pressOffsetX: 0
            property real dragCursorX: 0
            property bool dragged: false
            property bool movedAny: false

            onPressed: function(mouse) {
                const idx = dockRoot.rowAtX(mouse.x);
                root.pressedIndex = idx;
                pressX = mouse.x;
                dragCursorX = mouse.x;
                pressOffsetX = idx >= 0 ? (mouse.x - dockRoot.slotX(idx)) : (root.squircleSize * 0.5);
                dragged = false;
                movedAny = false;
            }

            onPositionChanged: function(mouse) {
                if (!(mouse.buttons & Qt.LeftButton) || root.pressedIndex < 0) {
                    return;
                }
                dragCursorX = mouse.x;
                if (!dragged && Math.abs(mouse.x - pressX) >= 8) {
                    dragged = true;
                    root.dragFromIndex = root.pressedIndex;
                }
                if (dragged && root.dragFromIndex >= 0) {
                    const draggedCenterX = dockRoot.clampDragX(dragCursorX - pressOffsetX, root.dragFromIndex)
                        + root.squircleSize * 0.5;
                    const targetIdx = dockRoot.rowAtX(draggedCenterX);
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
                    const targetItem = taskRepeater.itemAt(clickedRow);
                    contextMenu.visualParent = targetItem ? targetItem : dockRoot;
                    contextMenu.openRelative();
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

        Item {
            id: iconsRow
            anchors.centerIn: parent
            width: dockRoot.rowWidth
            height: root.innerHeight

            // Centered vertical divider between pinned and running-only apps (glides smoothly when section count changes)
            Rectangle {
                visible: dockRoot.hasDivider
                x: dockRoot.hasDivider
                    ? ((root.dividerBeforeIndex - 1) * root.tileStep + root.squircleSize + 10)
                    : 0
                y: root.squircleTopY + Math.round((root.squircleSize - root.dividerHeight) / 2)
                width: 1
                height: root.dividerHeight
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.24)
                z: 1

                Behavior on x {
                    enabled: root.animatePositions
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Repeater {
                id: taskRepeater
                model: tasksModel

                delegate: Item {
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
                    readonly property string appName: String(slotWrap.model.AppName || slotWrap.model.display || "")
                    readonly property string winTitle: String(slotWrap.model.display || "")
                    readonly property bool isDraggingThis: root.dragFromIndex === slotWrap.index
                    readonly property bool isPressedThis: root.pressedIndex === slotWrap.index && root.dragFromIndex < 0

                    width: root.squircleSize
                    height: root.innerHeight
                    y: 0
                    z: isDraggingThis ? 100 : (tileHover.hovered ? 5 : 2)

                    x: isDraggingThis
                        ? dockRoot.clampDragX(dockMouse.dragCursorX - dockMouse.pressOffsetX, slotWrap.index)
                        : dockRoot.slotX(slotWrap.index)

                    Behavior on x {
                        enabled: !slotWrap.isDraggingThis && root.animatePositions
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    HoverHandler {
                        id: tileHover
                    }

                    Rectangle {
                        id: tileBg
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.squircleTopY
                        width: root.squircleSize
                        height: root.squircleSize
                        radius: 10
                        scale: slotWrap.isDraggingThis ? 1.07 : 1.0
                        color: {
                            if (slotWrap.isDraggingThis) {
                                return Qt.rgba(58 / 255, 76 / 255, 98 / 255, 0.88);
                            }
                            if (slotWrap.isActive) {
                                return Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.74);
                            }
                            if (tileHover.hovered) {
                                return Qt.rgba(54 / 255, 66 / 255, 84 / 255, 0.65);
                            }
                            return Qt.rgba(38 / 255, 47 / 255, 62 / 255, 0.54);
                        }
                        border.width: slotWrap.isDraggingThis ? 1.5 : 1
                        border.color: {
                            if (slotWrap.isDraggingThis) {
                                return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.80);
                            }
                            if (slotWrap.isActive) {
                                return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.54);
                            }
                            if (tileHover.hovered) {
                                return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.22);
                            }
                            return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.11);
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
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
                            scale: slotWrap.isPressedThis ? 0.92 : (!slotWrap.isDraggingThis && tileHover.hovered ? 1.08 : 1.0)

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
                        opacity: slotWrap.isDraggingThis ? 0.5 : 1.0
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

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
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

        // Native Wayland xdg_popup QMenu (floats cleanly above the 58px dock with no clipping or scrollbar)
        PlasmaExtras.Menu {
            id: contextMenu
            visualParent: dockRoot
            placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup

            readonly property bool validRow: root.menuRow >= 0 && root.menuRow < tasksModel.count
            readonly property var rowIdx: validRow ? tasksModel.makeModelIndex(root.menuRow) : null
            readonly property string rowAppName: validRow
                ? String(tasksModel.data(rowIdx, TaskManager.AbstractTasksModel.AppName)
                         || tasksModel.data(rowIdx, Qt.DisplayRole) || "")
                : ""
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

            PlasmaExtras.MenuItem {
                section: true
                text: contextMenu.rowAppName
                visible: contextMenu.rowAppName.length > 0
            }

            PlasmaExtras.MenuItem {
                text: "New Window"
                icon: "window-new"
                enabled: contextMenu.validRow
                onClicked: {
                    if (contextMenu.validRow) {
                        tasksModel.requestNewInstance(tasksModel.makeModelIndex(root.menuRow));
                    }
                }
            }

            PlasmaExtras.MenuItem {
                text: contextMenu.rowPinned ? "Unpin from Dock" : "Pin to Dock"
                icon: contextMenu.rowPinned ? "window-unpin" : "window-pin"
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

            PlasmaExtras.MenuItem {
                separator: true
                visible: contextMenu.rowRunning
            }

            PlasmaExtras.MenuItem {
                visible: contextMenu.rowRunning
                text: contextMenu.rowGroup && contextMenu.rowChildren > 1 ? "Close All Windows" : "Close"
                icon: "window-close"
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

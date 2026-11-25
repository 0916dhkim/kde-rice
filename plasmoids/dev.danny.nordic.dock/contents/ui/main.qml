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

    property int dragFromIndex: -1
    property bool syncingLaunchers: false

    TaskManager.TasksModel {
        id: tasksModel
        sortMode: TaskManager.TasksModel.SortManual
        groupMode: TaskManager.TasksModel.GroupApplications
        separateLaunchers: false
        launchInPlace: true
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        filterHidden: true
        // qmllint disable missing-property
        launcherList: Plasmoid.configuration.launchers

        onLauncherListChanged: {
            if (!root.syncingLaunchers) {
                root.syncingLaunchers = true;
                Plasmoid.configuration.launchers = launcherList;
                root.syncingLaunchers = false;
            }
        }
        // qmllint enable missing-property
    }

    function activateItem(row: int, isLauncher: bool, isActive: bool, isGroupParent: bool, childCount: int): void {
        const idx = tasksModel.makeModelIndex(row);
        if (isLauncher) {
            tasksModel.requestActivate(idx);
            return;
        }
        if (isGroupParent && childCount > 1) {
            // Find the currently active child and cycle to the next window in the group
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
        if (isActive) {
            tasksModel.requestToggleMinimized(idx);
        } else {
            tasksModel.requestActivate(idx);
        }
    }

    function moveTask(fromRow: int, toRow: int): void {
        if (fromRow < 0 || toRow < 0 || fromRow === toRow) {
            return;
        }
        if (fromRow >= tasksModel.count || toRow >= tasksModel.count) {
            return;
        }
        if (tasksModel.move(fromRow, toRow)) {
            tasksModel.syncLaunchers();
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

    fullRepresentation: Item {
        id: dockRoot
        implicitWidth: Math.max(48, iconsRow.implicitWidth + 12)
        implicitHeight: 46
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        // External drop target for pinning apps (.desktop / applications: URLs) onto the dock
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

        // Subtle frost-teal highlight when dragging an external app over the dock to pin
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 10
            color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.10)
            border.width: 1
            border.color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.45)
            visible: externalDrop.containsDrag
        }

        RowLayout {
            id: iconsRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                id: taskRepeater
                model: tasksModel

                delegate: PlasmaCore.ToolTipArea {
                    id: taskTile
                    required property int index
                    required property var model

                    readonly property bool isLauncher: Boolean(taskTile.model.IsLauncher)
                    readonly property bool isWindow: Boolean(taskTile.model.IsWindow)
                    readonly property bool isStartup: Boolean(taskTile.model.IsStartup)
                    readonly property bool isActive: Boolean(taskTile.model.IsActive)
                    readonly property bool isAttention: Boolean(taskTile.model.IsDemandingAttention)
                    readonly property bool isGroupParent: Boolean(taskTile.model.IsGroupParent)
                    readonly property int childCount: Number(taskTile.model.ChildCount || 0)
                    readonly property bool isRunning: isWindow || isStartup
                    readonly property bool isPinned: isLauncher || Boolean(taskTile.model.HasLauncher)
                    readonly property var launcherUrl: taskTile.model.LauncherUrlWithoutIcon
                    readonly property string appName: String(taskTile.model.AppName || taskTile.model.display || "")
                    readonly property string winTitle: String(taskTile.model.display || "")
                    readonly property bool isDraggingThis: root.dragFromIndex === taskTile.index

                    location: Plasmoid.location
                    mainText: taskTile.appName
                    subText: {
                        if (taskTile.isLauncher) {
                            return "Launch " + taskTile.appName;
                        }
                        if (taskTile.isGroupParent && taskTile.childCount > 1) {
                            return taskTile.childCount + " open windows";
                        }
                        if (taskTile.winTitle && taskTile.winTitle !== taskTile.appName) {
                            return taskTile.winTitle;
                        }
                        return "";
                    }

                    implicitWidth: 42
                    implicitHeight: 44
                    Layout.alignment: Qt.AlignVCenter
                    opacity: taskTile.isDraggingThis ? 0.55 : 1.0

                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }

                    // Subtle rounded focus/hover tile backdrop
                    Rectangle {
                        id: tileBg
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 1
                        width: 40
                        height: 36
                        radius: 10
                        color: {
                            if (taskTile.isActive) {
                                return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.14);
                            }
                            if (tileMouse.containsMouse) {
                                return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.09);
                            }
                            return "transparent";
                        }
                        border.width: taskTile.isActive ? 1 : 0
                        border.color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.36)

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Kirigami.Icon {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            source: taskTile.model.decoration
                            scale: tileMouse.pressed ? 0.92 : (tileMouse.containsMouse ? 1.06 : 1.0)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    // Compact animated pill indicator lifted cleanly above the dock's bottom border
                    Rectangle {
                        id: indicator
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        height: 3
                        radius: 1.5
                        visible: taskTile.isRunning
                        width: {
                            if (taskTile.isActive) {
                                return 14;
                            }
                            if (taskTile.isAttention) {
                                return 10;
                            }
                            return 4;
                        }
                        color: {
                            if (taskTile.isAttention) {
                                return "#ebcb8b";
                            }
                            if (taskTile.isActive) {
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

                    // Reorder drag + click + middle-click + right-click handler
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: root.dragFromIndex >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                        property real pressX: 0
                        property bool dragged: false

                        onPressed: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                pressX = mouse.x;
                                dragged = false;
                            }
                        }

                        onPositionChanged: function(mouse) {
                            if (!(mouse.buttons & Qt.LeftButton)) {
                                return;
                            }
                            if (!dragged && Math.abs(mouse.x - pressX) >= 8) {
                                dragged = true;
                                root.dragFromIndex = taskTile.index;
                            }
                            if (dragged && root.dragFromIndex >= 0) {
                                const pt = mapToItem(iconsRow, mouse.x, iconsRow.height / 2);
                                const slotWidth = 42 + iconsRow.spacing;
                                const targetIdx = Math.max(
                                    0,
                                    Math.min(tasksModel.count - 1, Math.floor(pt.x / slotWidth))
                                );
                                if (targetIdx !== root.dragFromIndex) {
                                    root.moveTask(root.dragFromIndex, targetIdx);
                                }
                            }
                        }

                        onReleased: function(mouse) {
                            const wasDragged = dragged;
                            dragged = false;
                            root.dragFromIndex = -1;
                            if (wasDragged) {
                                return;
                            }
                            if (mouse.button === Qt.LeftButton) {
                                root.activateItem(
                                    taskTile.index,
                                    taskTile.isLauncher,
                                    taskTile.isActive,
                                    taskTile.isGroupParent,
                                    taskTile.childCount
                                );
                            } else if (mouse.button === Qt.MiddleButton) {
                                tasksModel.requestNewInstance(tasksModel.makeModelIndex(taskTile.index));
                            } else if (mouse.button === Qt.RightButton) {
                                contextMenu.popup();
                            }
                        }

                        onCanceled: {
                            dragged = false;
                            root.dragFromIndex = -1;
                        }
                    }

                    PlasmaComponents.Menu {
                        id: contextMenu

                        PlasmaComponents.MenuItem {
                            text: "New Window"
                            icon.name: "window-new"
                            onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(taskTile.index))
                        }

                        PlasmaComponents.MenuItem {
                            text: taskTile.isPinned ? "Unpin from Dock" : "Pin to Dock"
                            icon.name: taskTile.isPinned ? "window-unpin" : "window-pin"
                            enabled: taskTile.launcherUrl !== undefined && String(taskTile.launcherUrl).length > 0
                            onClicked: {
                                if (taskTile.isPinned) {
                                    tasksModel.requestRemoveLauncher(taskTile.launcherUrl);
                                } else {
                                    tasksModel.requestAddLauncher(taskTile.launcherUrl);
                                }
                                tasksModel.syncLaunchers();
                            }
                        }

                        PlasmaComponents.MenuSeparator {
                            visible: taskTile.isRunning
                        }

                        PlasmaComponents.MenuItem {
                            visible: taskTile.isRunning
                            text: taskTile.isGroupParent && taskTile.childCount > 1 ? "Close All Windows" : "Close"
                            icon.name: "window-close"
                            onClicked: {
                                if (taskTile.isGroupParent && taskTile.childCount > 1) {
                                    for (let c = taskTile.childCount - 1; c >= 0; --c) {
                                        tasksModel.requestClose(tasksModel.makeModelIndex(taskTile.index, c));
                                    }
                                } else {
                                    tasksModel.requestClose(tasksModel.makeModelIndex(taskTile.index));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

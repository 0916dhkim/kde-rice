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

    function isRowPinned(row: int): bool {
        if (row < 0 || row >= tasksModel.count) {
            return false;
        }
        const idx = tasksModel.makeModelIndex(row);
        return Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.IsLauncher))
            || Boolean(tasksModel.data(idx, TaskManager.AbstractTasksModel.HasLauncher));
    }

    function activateItem(row: int, isLauncher: bool, isActive: bool, isGroupParent: bool, childCount: int): void {
        const idx = tasksModel.makeModelIndex(row);
        if (isLauncher) {
            tasksModel.requestActivate(idx);
            return;
        }
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
        implicitWidth: Math.max(44, iconsRow.implicitWidth + 4)
        implicitHeight: 46
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

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
                    readonly property bool isPinned: isLauncher || Boolean(slotWrap.model.HasLauncher)
                    readonly property bool showLeadingDivider: tasksModel.launcherCount > 0
                        && tasksModel.count > 1
                        && slotWrap.index > 0
                        && !slotWrap.isPinned
                        && root.isRowPinned(slotWrap.index - 1)
                    readonly property var launcherUrl: slotWrap.model.LauncherUrlWithoutIcon
                    readonly property string appName: String(slotWrap.model.AppName || slotWrap.model.display || "")
                    readonly property string winTitle: String(slotWrap.model.display || "")
                    readonly property bool isDraggingThis: root.dragFromIndex === slotWrap.index

                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Vertical divider between pinned apps and unpinned running apps
                    Rectangle {
                        visible: slotWrap.showLeadingDivider
                        implicitWidth: 1
                        implicitHeight: 26
                        color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.16)
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        Layout.bottomMargin: 4
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

                        implicitWidth: 38
                        implicitHeight: 45
                        Layout.alignment: Qt.AlignVCenter
                        opacity: slotWrap.isDraggingThis ? 0.55 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }

                        // Uniform dark Nordic squircle background card for every dock icon
                        Rectangle {
                            id: tileBg
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 1
                            width: 36
                            height: 36
                            radius: 10
                            color: {
                                if (slotWrap.isActive) {
                                    return Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.72);
                                }
                                if (tileMouse.containsMouse) {
                                    return Qt.rgba(54 / 255, 66 / 255, 84 / 255, 0.65);
                                }
                                return Qt.rgba(38 / 255, 47 / 255, 62 / 255, 0.52);
                            }
                            border.width: 1
                            border.color: {
                                if (slotWrap.isActive) {
                                    return Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.52);
                                }
                                if (tileMouse.containsMouse) {
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
                                scale: tileMouse.pressed ? 0.92 : (tileMouse.containsMouse ? 1.08 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        // Compact animated pill indicator cleanly below the squircle card
                        Rectangle {
                            id: indicator
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
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
                                    root.dragFromIndex = slotWrap.index;
                                }
                                if (dragged && root.dragFromIndex >= 0) {
                                    const pt = mapToItem(iconsRow, mouse.x, iconsRow.height / 2);
                                    const slotWidth = 38 + iconsRow.spacing;
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
                                        slotWrap.index,
                                        slotWrap.isLauncher,
                                        slotWrap.isActive,
                                        slotWrap.isGroupParent,
                                        slotWrap.childCount
                                    );
                                } else if (mouse.button === Qt.MiddleButton) {
                                    tasksModel.requestNewInstance(tasksModel.makeModelIndex(slotWrap.index));
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
                                onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(slotWrap.index))
                            }

                            PlasmaComponents.MenuItem {
                                text: slotWrap.isPinned ? "Unpin from Dock" : "Pin to Dock"
                                icon.name: slotWrap.isPinned ? "window-unpin" : "window-pin"
                                enabled: slotWrap.launcherUrl !== undefined && String(slotWrap.launcherUrl).length > 0
                                onClicked: {
                                    if (slotWrap.isPinned) {
                                        tasksModel.requestRemoveLauncher(slotWrap.launcherUrl);
                                    } else {
                                        tasksModel.requestAddLauncher(slotWrap.launcherUrl);
                                    }
                                    tasksModel.syncLaunchers();
                                }
                            }

                            PlasmaComponents.MenuSeparator {
                                visible: slotWrap.isRunning
                            }

                            PlasmaComponents.MenuItem {
                                visible: slotWrap.isRunning
                                text: slotWrap.isGroupParent && slotWrap.childCount > 1 ? "Close All Windows" : "Close"
                                icon.name: "window-close"
                                onClicked: {
                                    if (slotWrap.isGroupParent && slotWrap.childCount > 1) {
                                        for (let c = slotWrap.childCount - 1; c >= 0; --c) {
                                            tasksModel.requestClose(tasksModel.makeModelIndex(slotWrap.index, c));
                                        }
                                    } else {
                                        tasksModel.requestClose(tasksModel.makeModelIndex(slotWrap.index));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

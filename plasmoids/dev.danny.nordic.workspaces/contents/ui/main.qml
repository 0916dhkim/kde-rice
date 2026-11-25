pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.VirtualDesktopInfo {
        id: vdInfo
    }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        filterHidden: true

        onCountChanged: root.refreshOccupied()
        onDataChanged: root.refreshOccupied()
        onRowsInserted: root.refreshOccupied()
        onRowsRemoved: root.refreshOccupied()
        onModelReset: root.refreshOccupied()
    }

    property var occupiedMap: ({})

    function refreshOccupied(): void {
        const next = {};
        const total = tasksModel.count;
        for (let i = 0; i < total; ++i) {
            const idx = tasksModel.makeModelIndex(i);
            const isWindow = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow);
            const skipTaskbar = tasksModel.data(idx, TaskManager.AbstractTasksModel.SkipTaskbar);
            if (!isWindow || skipTaskbar) {
                continue;
            }
            const onAll = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops);
            if (onAll) {
                const allIds = vdInfo.desktopIds;
                for (let j = 0; j < allIds.length; ++j) {
                    next[String(allIds[j])] = true;
                }
                continue;
            }
            const desktops = tasksModel.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops);
            if (desktops && desktops.length > 0) {
                for (let j = 0; j < desktops.length; ++j) {
                    next[String(desktops[j])] = true;
                }
            }
        }
        occupiedMap = next;
    }

    function activateDesktop(desktopId: var, index: int): void {
        if (typeof desktopId === "string" && desktopId.length > 0) {
            const msg = ({
                service: "org.kde.KWin",
                path: "/VirtualDesktopManager",
                iface: "org.freedesktop.DBus.Properties",
                member: "Set",
                arguments: [
                    new DBus.string("org.kde.KWin.VirtualDesktopManager"),
                    new DBus.string("current"),
                    new DBus.variant(desktopId)
                ]
            });
            DBus.SessionBus.asyncCall(msg);
        } else {
            const msg = ({
                service: "org.kde.KWin",
                path: "/KWin",
                iface: "org.kde.KWin",
                member: "setCurrentDesktop",
                arguments: [new DBus.int32(index + 1)]
            });
            DBus.SessionBus.asyncCall(msg);
        }
    }

    function stepDesktop(delta: int): void {
        const ids = vdInfo.desktopIds;
        if (!ids || ids.length <= 1) {
            return;
        }
        const curPos = ids.indexOf(vdInfo.currentDesktop);
        if (curPos < 0) {
            return;
        }
        let nextPos = curPos + delta;
        if (vdInfo.navigationWrappingAround) {
            nextPos = (nextPos + ids.length) % ids.length;
        } else {
            nextPos = Math.max(0, Math.min(ids.length - 1, nextPos));
        }
        if (nextPos !== curPos) {
            activateDesktop(ids[nextPos], nextPos);
        }
    }

    Component.onCompleted: refreshOccupied()

    fullRepresentation: Item {
        id: barItem
        implicitWidth: pillFrame.implicitWidth + 4
        implicitHeight: Math.max(24, pillFrame.implicitHeight)
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (event.angleDelta.y > 0) {
                    root.stepDesktop(-1);
                } else if (event.angleDelta.y < 0) {
                    root.stepDesktop(1);
                }
            }
        }

        Rectangle {
            id: pillFrame
            anchors.centerIn: parent
            radius: height / 2
            implicitWidth: dotsRow.implicitWidth + 16
            implicitHeight: 22
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.08)

            RowLayout {
                id: dotsRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: vdInfo.desktopIds

                    delegate: PlasmaCore.ToolTipArea {
                        id: dotWrap
                        required property int index
                        required property var modelData

                        readonly property bool isActive: modelData === vdInfo.currentDesktop
                        readonly property bool isOccupied: root.occupiedMap[String(modelData)] === true
                        readonly property string desktopName: {
                            const names = vdInfo.desktopNames;
                            return (names && index < names.length && names[index])
                                ? names[index]
                                : ("Desktop " + (index + 1));
                        }

                        location: Plasmoid.location
                        mainText: dotWrap.desktopName
                        subText: dotWrap.isActive
                            ? "Active workspace"
                            : (dotWrap.isOccupied ? "Has open windows" : "Empty")

                        implicitWidth: dotRect.implicitWidth
                        implicitHeight: 18
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: dotRect
                            anchors.centerIn: parent
                            implicitWidth: dotWrap.isActive ? 22 : 7
                            implicitHeight: 7
                            radius: 3.5
                            color: {
                                if (dotWrap.isActive) {
                                    return "#88c0d0";
                                }
                                if (dotWrap.containsMouse || dotMouse.containsMouse) {
                                    return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.80);
                                }
                                if (dotWrap.isOccupied) {
                                    return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.56);
                                }
                                return Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.26);
                            }

                            Behavior on implicitWidth {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activateDesktop(dotWrap.modelData, dotWrap.index)
                        }
                    }
                }
            }
        }
    }
}

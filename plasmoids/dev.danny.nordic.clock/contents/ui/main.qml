pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property date now: new Date()
    property int shownYear: now.getFullYear()
    property int shownMonth: now.getMonth()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    onExpandedChanged: {
        if (expanded) {
            shownYear = now.getFullYear();
            shownMonth = now.getMonth();
        }
    }

    function shiftMonth(delta: int): void {
        const d = new Date(shownYear, shownMonth + delta, 1);
        shownYear = d.getFullYear();
        shownMonth = d.getMonth();
    }

    compactRepresentation: Item {
        implicitWidth: clockPill.implicitWidth + 4
        implicitHeight: 24
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        Rectangle {
            id: clockPill
            anchors.centerIn: parent
            implicitWidth: clockText.implicitWidth + 16
            implicitHeight: 24
            radius: 8
            color: clockMouse.containsMouse || root.expanded
                ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.14)
                : "transparent"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Text {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatDate(root.now, "ddd MMM d") + "  " + Qt.formatTime(root.now, "HH:mm")
                color: "#eceff4"
                font.pixelSize: 12.5
                font.weight: Font.DemiBold
                font.letterSpacing: 0.2
            }
        }

        MouseArea {
            id: clockMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        implicitWidth: 284
        implicitHeight: 268
        Layout.minimumWidth: 260
        Layout.minimumHeight: 250

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: Qt.formatDate(new Date(root.shownYear, root.shownMonth, 1), "MMMM yyyy")
                    color: "#eceff4"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                QQC2.ToolButton {
                    text: "‹"
                    onClicked: root.shiftMonth(-1)
                }
                QQC2.ToolButton {
                    text: "Today"
                    font.pixelSize: 11.5
                    onClicked: {
                        root.shownYear = root.now.getFullYear();
                        root.shownMonth = root.now.getMonth();
                    }
                }
                QQC2.ToolButton {
                    text: "›"
                    onClicked: root.shiftMonth(1)
                }
            }

            QQC2.DayOfWeekRow {
                Layout.fillWidth: true
                locale: Qt.locale()
                delegate: Text {
                    required property string shortName
                    text: shortName
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.55)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            QQC2.MonthGrid {
                id: monthGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                month: root.shownMonth
                year: root.shownYear
                locale: Qt.locale()

                delegate: Rectangle {
                    id: dayCell
                    required property var model
                    readonly property bool isToday: Boolean(dayCell.model.today)
                    readonly property bool inMonth: dayCell.model.month === monthGrid.month

                    radius: 7
                    color: dayCell.isToday ? "#88c0d0" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: String(dayCell.model.day)
                        font.pixelSize: 12
                        font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                        color: {
                            if (dayCell.isToday) {
                                return "#141a24";
                            }
                            return dayCell.inMonth
                                ? "#eceff4"
                                : Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.28);
                        }
                    }
                }
            }
        }
    }
}

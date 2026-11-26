pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: osdRoot
    objectName: "onScreenDisplay"

    property int osdMaxValue: 100
    property var osdValue: 0
    property string osdAdditionalText: ""
    property bool showingProgress: false
    property string icon: ""

    visible: opacity > 0
    opacity: 0
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    function show(): void {
        opacity = 1;
        hideTimer.restart();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.InOutQuad
        }
    }

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: osdRoot.opacity = 0
    }

    Rectangle {
        id: pill
        implicitWidth: Math.max(180, row.implicitWidth + 28)
        implicitHeight: 42
        radius: 12
        color: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.86)
        border.width: 1
        border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.18)

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 10

            Kirigami.Icon {
                visible: osdRoot.icon.length > 0
                source: osdRoot.icon
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
            }

            Rectangle {
                visible: osdRoot.showingProgress
                Layout.preferredWidth: 112
                Layout.preferredHeight: 5
                radius: 3
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.16)

                Rectangle {
                    width: osdRoot.osdMaxValue > 0
                        ? Math.max(0, Math.min(parent.width, Math.round(parent.width * (Number(osdRoot.osdValue) / osdRoot.osdMaxValue))))
                        : 0
                    height: parent.height
                    radius: 3
                    color: "#88c0d0"
                }
            }

            Text {
                visible: !osdRoot.showingProgress && String(osdRoot.osdValue).length > 0
                text: String(osdRoot.osdValue)
                color: "#eceff4"
                font.family: "Manrope"
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Text {
                visible: osdRoot.osdAdditionalText.length > 0
                text: osdRoot.osdAdditionalText
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.72)
                font.family: "Manrope"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}

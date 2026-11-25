pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Sensors.Sensor {
        id: cpuSensor
        sensorId: "cpu/all/usage"
        enabled: true
    }

    Sensors.Sensor {
        id: memSensor
        sensorId: "memory/physical/usedPercent"
        enabled: true
    }

    readonly property int cpuPct: isNaN(Number(cpuSensor.value)) ? 0 : Math.round(Number(cpuSensor.value))
    readonly property int memPct: isNaN(Number(memSensor.value)) ? 0 : Math.round(Number(memSensor.value))

    fullRepresentation: Item {
        implicitWidth: statRow.implicitWidth + 8
        implicitHeight: 24
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        RowLayout {
            id: statRow
            anchors.centerIn: parent
            spacing: 5

            Kirigami.Icon {
                source: "cpu-symbolic"
                isMask: true
                implicitWidth: 14
                implicitHeight: 14
                color: root.cpuPct >= 80 ? "#ebcb8b" : Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.78)
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.cpuPct + "%"
                color: root.cpuPct >= 80 ? "#ebcb8b" : Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.84)
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: "monospace"
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                implicitWidth: 1
                implicitHeight: 14
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.16)
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 5
            }
        }

        MouseArea {
            id: statMouse
            anchors.fill: parent
            hoverEnabled: true
        }

        QQC2.ToolTip.visible: statMouse.containsMouse
        QQC2.ToolTip.delay: 300
        QQC2.ToolTip.text: "CPU: " + root.cpuPct + "%  ·  Memory: " + root.memPct + "%"
    }
}

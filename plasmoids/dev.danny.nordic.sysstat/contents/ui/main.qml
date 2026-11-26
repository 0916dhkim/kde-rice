pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.private.battery as BatteryControl
import org.kde.plasma.private.volume as PlasmaPA

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property real paNormalVolume: 65536.0

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

    BatteryControl.BatteryControlModel {
        id: batteryModel
    }

    readonly property int cpuPct: isNaN(Number(cpuSensor.value)) ? 0 : Math.round(Number(cpuSensor.value))
    readonly property int memPct: isNaN(Number(memSensor.value)) ? 0 : Math.round(Number(memSensor.value))

    readonly property var defaultSink: PlasmaPA.PreferredDevice.sink
    readonly property bool hasAudio: defaultSink !== null && defaultSink !== undefined
    readonly property bool isMuted: hasAudio ? Boolean(defaultSink.muted) : false
    readonly property int volPct: hasAudio
        ? Math.max(0, Math.round((Number(defaultSink.volume) / paNormalVolume) * 100))
        : 0

    readonly property bool hasBattery: batteryModel.hasBatteries
    readonly property int batPct: Math.max(0, Math.min(100, batteryModel.percent))
    readonly property bool batPluggedIn: batteryModel.pluggedIn
    readonly property bool batCharging: batteryModel.state === BatteryControl.BatteryControlModel.Charging
    readonly property bool batFull: batteryModel.state === BatteryControl.BatteryControlModel.FullyCharged
    readonly property color batColor: {
        if (batPluggedIn) {
            return "#88c0d0";
        }
        if (batPct <= 12) {
            return "#bf616a";
        }
        if (batPct <= 25) {
            return "#ebcb8b";
        }
        return "#a3be8c";
    }

    function adjustVolume(deltaPct: int): void {
        if (!hasAudio) {
            return;
        }
        const nextPct = Math.max(0, Math.min(100, volPct + deltaPct));
        defaultSink.volume = Math.round((nextPct / 100.0) * paNormalVolume);
        if (nextPct > 0 && defaultSink.muted) {
            defaultSink.muted = false;
        }
    }

    function toggleMute(): void {
        if (!hasAudio) {
            return;
        }
        defaultSink.muted = !defaultSink.muted;
    }

    function formatRemaining(ms: real): string {
        if (!ms || ms <= 0) {
            return "";
        }
        const totalMin = Math.round(ms / 60000);
        const h = Math.floor(totalMin / 60);
        const m = totalMin % 60;
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    fullRepresentation: Item {
        implicitWidth: statusRow.implicitWidth + 8
        implicitHeight: 24
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.fillHeight: true

        RowLayout {
            id: statusRow
            anchors.centerIn: parent
            spacing: 11

            // CPU chip + percentage
            PlasmaCore.ToolTipArea {
                implicitWidth: cpuRow.implicitWidth
                implicitHeight: 22
                Layout.alignment: Qt.AlignVCenter
                location: Plasmoid.location
                mainText: "CPU " + root.cpuPct + "%"
                subText: "Memory: " + root.memPct + "%"

                RowLayout {
                    id: cpuRow
                    anchors.centerIn: parent
                    spacing: 5

                    Image {
                        source: Qt.resolvedUrl("icons/cpu.svg")
                        sourceSize.width: 14
                        sourceSize.height: 14
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        smooth: true
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
                }
            }

            Rectangle {
                implicitWidth: 1
                implicitHeight: 14
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }

            // Inline Volume icon + percentage (scroll to adjust, click to mute)
            PlasmaCore.ToolTipArea {
                visible: root.hasAudio
                implicitWidth: volRow.implicitWidth
                implicitHeight: 22
                Layout.alignment: Qt.AlignVCenter
                location: Plasmoid.location
                mainText: root.isMuted ? "Audio Muted" : ("Volume " + root.volPct + "%")
                subText: "Scroll to adjust · Click to mute"

                RowLayout {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 4

                    Image {
                        source: Qt.resolvedUrl(root.isMuted || root.volPct === 0 ? "icons/volume-muted.svg" : "icons/volume.svg")
                        sourceSize.width: 15
                        sourceSize.height: 15
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        smooth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: root.isMuted ? "mute" : (root.volPct + "%")
                        color: root.isMuted ? "#bf616a" : Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.84)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMute()
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        if (event.angleDelta.y > 0) {
                            root.adjustVolume(5);
                        } else if (event.angleDelta.y < 0) {
                            root.adjustVolume(-5);
                        }
                    }
                }
            }

            // Live-fill Battery + percentage
            PlasmaCore.ToolTipArea {
                visible: root.hasBattery
                implicitWidth: batRow.implicitWidth
                implicitHeight: 22
                Layout.alignment: Qt.AlignVCenter
                location: Plasmoid.location
                mainText: "Battery " + root.batPct + "%"
                subText: {
                    const rem = root.formatRemaining(batteryModel.smoothedRemainingMsec);
                    const state = root.batCharging
                        ? "Charging"
                        : (root.batFull ? "Fully charged" : (root.batPluggedIn ? "Plugged in" : "On battery"));
                    return state + (rem ? (" · " + rem + (root.batCharging ? " until full" : " remaining")) : "");
                }

                RowLayout {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 5

                    Item {
                        implicitWidth: 21
                        implicitHeight: 14
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            x: 0
                            y: 1
                            width: 18
                            height: 12
                            radius: 3
                            color: "transparent"
                            border.width: 1.4
                            border.color: root.batColor

                            Rectangle {
                                x: 2.5
                                y: 2.5
                                width: Math.max(2, Math.round(13 * (root.batPct / 100.0)))
                                height: 7
                                radius: 1.2
                                color: root.batColor
                            }
                        }

                        Rectangle {
                            x: 19.2
                            y: 4.8
                            width: 1.8
                            height: 4.4
                            radius: 0.9
                            color: root.batColor
                        }

                        // Crisp macOS-style charging lightning bolt with dark halo knockout
                        Image {
                            visible: root.batCharging
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: -1.5
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl("icons/bolt.svg")
                            sourceSize.width: 12
                            sourceSize.height: 14
                            width: 11
                            height: 13
                            smooth: true
                        }
                    }

                    Text {
                        text: root.batPct + "%"
                        color: root.batColor
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            Rectangle {
                implicitWidth: 1
                implicitHeight: 14
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.16)
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}

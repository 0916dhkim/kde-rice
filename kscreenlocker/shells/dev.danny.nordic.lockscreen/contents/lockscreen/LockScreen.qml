pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kscreenlocker as ScreenLocker
import org.kde.plasma.private.battery as BatteryControl
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.sessions

Item {
    id: root

    // Required KScreenLocker properties
    property bool viewVisible: false
    property bool locked: true
    property string notification: ""
    property bool isErrorNotification: false
    property string pendingPassword: ""
    property string hoveredPowerLabel: ""
    property date currentTime: new Date()

    readonly property bool hasFingerprint: Boolean(
        authenticator.authenticatorTypes & ScreenLocker.Authenticator.Fingerprint
    )
    readonly property bool hasBattery: batteryModel.hasBatteries
    readonly property int batPct: Math.max(0, Math.min(100, batteryModel.percent))
    readonly property bool batPluggedIn: batteryModel.pluggedIn
    readonly property bool batCharging: batteryModel.state === BatteryControl.BatteryControlModel.Charging
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

    implicitWidth: 1200
    implicitHeight: 740

    function showNotice(msg: string, isError: bool): void {
        if (!msg) {
            return;
        }
        root.notification = msg;
        root.isErrorNotification = isError;
        noticeResetTimer.restart();
    }

    function clearPassword(): void {
        PasswordSync.password = "";
        passwordInput.text = "";
        passwordInput.forceActiveFocus();
    }

    function submitPassword(): void {
        const pw = passwordInput.text;
        if (authenticator.inPasswordDelay) {
            root.pendingPassword = pw;
            return;
        }
        authenticator.respond(pw);
    }

    Component.onCompleted: {
        authenticator.startAuthenticating();
        passwordInput.forceActiveFocus();
        fadeIn.start();
    }

    onViewVisibleChanged: {
        if (root.viewVisible) {
            authenticator.startAuthenticating();
            passwordInput.forceActiveFocus();
        }
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // Keep PAM + non-interactive fingerprint authenticators alive while locked
    Timer {
        interval: 1000
        running: !authenticator.unlocked
        repeat: true
        onTriggered: authenticator.startAuthenticating()
    }

    Timer {
        id: noticeResetTimer
        interval: 4000
        onTriggered: {
            root.notification = "";
            root.isErrorNotification = false;
        }
    }

    SessionManagement {
        id: sessionManagement
    }

    BatteryControl.BatteryControlModel {
        id: batteryModel
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend(): void {
            root.clearPassword();
        }
    }

    Connections {
        target: authenticator

        function onSucceeded(): void {
            authenticator.stopAuthenticating();
            Qt.quit();
        }

        function onFailed(kind: int): void {
            if (kind !== 0) {
                return;
            }
            root.showNotice("Unlocking failed", true);
            root.clearPassword();
            rejectShake.restart();
            authenticator.startAuthenticating();
        }

        function onInPasswordDelayChanged(): void {
            if (!authenticator.inPasswordDelay && root.pendingPassword.length > 0) {
                const pw = root.pendingPassword;
                root.pendingPassword = "";
                authenticator.respond(pw);
            }
        }

        function onErrorMessageChanged(): void {
            if (authenticator.errorMessage) {
                root.showNotice(authenticator.errorMessage, true);
            }
        }

        function onInfoMessageChanged(): void {
            if (authenticator.infoMessage) {
                root.showNotice(authenticator.infoMessage, false);
            }
        }

        function onPromptChanged(): void {
            if (authenticator.prompt) {
                root.showNotice(authenticator.prompt, false);
            }
        }

        function onPromptForSecretChanged(): void {
            passwordInput.forceActiveFocus();
        }

        function onNoninteractiveError(kind: int, auth: var): void {
            if (auth && auth.errorMessage) {
                root.showNotice(auth.errorMessage, true);
            } else if (kind & ScreenLocker.Authenticator.Fingerprint) {
                root.showNotice("Fingerprint not recognized", true);
            }
            rejectShake.restart();
        }

        function onNoninteractiveInfo(kind: int, auth: var): void {
            if (auth && auth.infoMessage) {
                root.showNotice(auth.infoMessage, false);
            }
        }
    }

    // Main interactive surface over KScreenLocker's wallpaperItem (z = -1000)
    MouseArea {
        id: surface
        anchors.fill: parent
        hoverEnabled: true
        opacity: 0
        onPressed: {
            if (Window.window) {
                Window.window.requestActivate();
            }
            passwordInput.forceActiveFocus();
            authenticator.startAuthenticating();
        }

        NumberAnimation {
            id: fadeIn
            target: surface
            property: "opacity"
            from: 0
            to: 1
            duration: 240
            easing.type: Easing.OutCubic
        }

        // Left-side editorial dark gradient scrim: keeps Swiss typography crisp
        // over the dark pines while leaving the right landscape completely open.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(10 / 255, 14 / 255, 21 / 255, 0.66) }
                GradientStop { position: 0.44; color: Qt.rgba(10 / 255, 14 / 255, 21 / 255, 0.22) }
                GradientStop { position: 0.72; color: Qt.rgba(10 / 255, 14 / 255, 21 / 255, 0.02) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Top-right calm battery readout matching dev.danny.nordic.sysstat
        RowLayout {
            visible: root.hasBattery
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 24
            anchors.rightMargin: 28
            spacing: 6

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
                font.family: "Manrope"
                font.pixelSize: 13
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Editorial Left-Aligned Poster Column (Option 2)
        Column {
            id: editorialCol
            x: Math.max(48, Math.round(parent.width * 0.062))
            y: Math.max(72, Math.round(parent.height * 0.21))
            width: 340
            spacing: 0

            Text {
                text: "NORDIC MINIMAL \u00b7 LOCKED"
                color: "#88c0d0"
                font.family: "Manrope"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 2.0
            }

            Item { width: 1; height: 10 }

            Text {
                text: Qt.formatTime(root.currentTime, "HH:mm")
                color: "#eceff4"
                font.family: "Manrope"
                font.pixelSize: 88
                font.weight: Font.DemiBold
                font.letterSpacing: -2.4
                lineHeight: 0.96
            }

            Item { width: 1; height: 10 }

            Text {
                text: Qt.formatDate(root.currentTime, "dddd, MMMM d")
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.78)
                font.family: "Manrope"
                font.pixelSize: 18
                font.weight: Font.Normal
            }

            Item { width: 1; height: 28 }

            // Nordic Sage editorial rule
            Rectangle {
                width: 44
                height: 2
                radius: 1
                color: "#a3be8c"
            }

            Item { width: 1; height: 24 }

            // User + fingerprint prompt row
            RowLayout {
                spacing: 7

                Image {
                    visible: root.hasFingerprint
                    source: Qt.resolvedUrl("icons/fingerprint.svg")
                    sourceSize.width: 15
                    sourceSize.height: 15
                    Layout.preferredWidth: 15
                    Layout.preferredHeight: 15
                    smooth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.hasFingerprint
                        ? (kscreenlocker_userName + " \u00b7 Touch sensor or enter password")
                        : kscreenlocker_userName
                    color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.72)
                    font.family: "Manrope"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Item { width: 1; height: 11 }

            // Frosted Nordic password box with sage focus ring + shake on error
            Item {
                width: 286
                height: 42

                Rectangle {
                    id: passwordBox
                    x: 0
                    y: 0
                    width: 286
                    height: 42
                    radius: 11
                    color: Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.80)
                    border.width: 1.5
                    border.color: root.isErrorNotification
                        ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.85)
                        : Qt.rgba(163 / 255, 190 / 255, 140 / 255, passwordInput.activeFocus ? 0.78 : 0.42)

                    SequentialAnimation {
                        id: rejectShake
                        NumberAnimation { target: passwordBox; property: "x"; to: -8; duration: 45 }
                        NumberAnimation { target: passwordBox; property: "x"; to: 8; duration: 55 }
                        NumberAnimation { target: passwordBox; property: "x"; to: -5; duration: 45 }
                        NumberAnimation { target: passwordBox; property: "x"; to: 4; duration: 45 }
                        NumberAnimation { target: passwordBox; property: "x"; to: 0; duration: 40 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 6
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordInput.text.length === 0
                                text: "Password"
                                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.46)
                                font.family: "Manrope"
                                font.pixelSize: 13
                                font.weight: Font.Normal
                            }

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "\u2022"
                                color: "#eceff4"
                                selectionColor: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.35)
                                selectedTextColor: "#eceff4"
                                font.family: "Manrope"
                                font.pixelSize: 14
                                focus: true
                                text: PasswordSync.password
                                onTextEdited: {
                                    PasswordSync.password = text;
                                    if (root.isErrorNotification) {
                                        root.notification = "";
                                        root.isErrorNotification = false;
                                    }
                                }
                                onAccepted: root.submitPassword()
                                Keys.onEscapePressed: {
                                    root.clearPassword();
                                    // Let kscreenlocker_greet handle DPMS off on Esc
                                    event.accepted = false;
                                }
                            }
                        }

                        // Rounded-square sage submit button
                        Rectangle {
                            id: submitBtn
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: submitMouse.containsMouse
                                ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.34)
                                : Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.22)
                            border.width: 1
                            border.color: Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.55)
                            opacity: authenticator.busy ? 0.5 : 1.0

                            Image {
                                anchors.centerIn: parent
                                source: Qt.resolvedUrl("icons/arrow.svg")
                                sourceSize.width: 15
                                sourceSize.height: 15
                                width: 15
                                height: 15
                                smooth: true
                            }

                            MouseArea {
                                id: submitMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitPassword()
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 10 }

            // Caps Lock + PAM error/status feedback
            Text {
                width: 286
                wrapMode: Text.WordWrap
                visible: text.length > 0
                text: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push("Caps Lock is on");
                    }
                    if (root.notification) {
                        parts.push(root.notification);
                    }
                    return parts.join(" \u00b7 ");
                }
                color: root.isErrorNotification
                    ? "#bf616a"
                    : (capsLockState.locked ? "#ebcb8b" : "#88c0d0")
                font.family: "Manrope"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        // Bottom-left quiet power controls (Sleep / Restart / Shut Down)
        RowLayout {
            anchors.left: editorialCol.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 42
            spacing: 10

            component PowerBtn: Rectangle {
                id: pbtn
                required property string iconFile
                required property string labelText
                property bool destructive: false
                signal triggered()

                width: 36
                height: 36
                radius: 10
                color: pMouse.containsMouse
                    ? (pbtn.destructive
                        ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.26)
                        : Qt.rgba(40 / 255, 52 / 255, 68 / 255, 0.82))
                    : Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.72)
                border.width: 1
                border.color: pMouse.containsMouse
                    ? (pbtn.destructive
                        ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.65)
                        : Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.50))
                    : Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.14)

                Image {
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl(pbtn.iconFile)
                    sourceSize.width: 17
                    sourceSize.height: 17
                    width: 17
                    height: 17
                    smooth: true
                    opacity: pMouse.containsMouse ? 1.0 : 0.80
                }

                MouseArea {
                    id: pMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredPowerLabel = pbtn.labelText
                    onExited: {
                        if (root.hoveredPowerLabel === pbtn.labelText) {
                            root.hoveredPowerLabel = "";
                        }
                    }
                    onClicked: pbtn.triggered()
                }
            }

            PowerBtn {
                visible: sessionManagement.canSuspend
                iconFile: "icons/sleep.svg"
                labelText: "Sleep"
                onTriggered: sessionManagement.suspend()
            }

            PowerBtn {
                visible: sessionManagement.canReboot
                iconFile: "icons/restart.svg"
                labelText: "Restart"
                onTriggered: sessionManagement.reboot()
            }

            PowerBtn {
                visible: sessionManagement.canShutdown
                iconFile: "icons/power.svg"
                labelText: "Shut Down"
                destructive: true
                onTriggered: sessionManagement.shutdown()
            }

            Text {
                visible: root.hoveredPowerLabel.length > 0
                text: root.hoveredPowerLabel
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.72)
                font.family: "Manrope"
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.leftMargin: 4
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // OSD support (volume / brightness keys on lock screen)
        Loader {
            z: 4
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
        }
    }
}

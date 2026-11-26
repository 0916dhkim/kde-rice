pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root
    width: 1200
    height: 740

    property date currentTime: new Date()
    property int userIndex: userModel && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool userMenuOpen: false
    property bool sessionMenuOpen: false
    property bool loggingIn: false
    property string statusMessage: ""
    property bool isErrorMessage: false
    property string hoveredPowerLabel: ""

    readonly property int userCount: userModel ? userModel.count : 0
    readonly property int sessionCount: sessionModel ? sessionModel.count : 0
    readonly property bool multiUser: userCount > 1

    // SDDM UserModel roles: NameRole = Qt.UserRole + 1 (257), RealNameRole = Qt.UserRole + 2 (258)
    // SDDM SessionModel roles: NameRole = Qt.UserRole + 4 (260) or DisplayRole (0)
    readonly property string currentUserName: {
        if (!userModel || userCount <= 0) {
            return userModel ? (userModel.lastUser || "") : "";
        }
        const idx = userModel.index(Math.max(0, Math.min(userIndex, userCount - 1)), 0);
        return String(userModel.data(idx, 257) || userModel.lastUser || "");
    }

    readonly property string currentUserLabel: {
        if (!userModel || userCount <= 0) {
            return currentUserName;
        }
        const idx = userModel.index(Math.max(0, Math.min(userIndex, userCount - 1)), 0);
        const real = String(userModel.data(idx, 258) || "");
        return real.length > 0 ? real : currentUserName;
    }

    readonly property string currentSessionName: {
        if (!sessionModel || sessionCount <= 0) {
            return "Plasma (Wayland)";
        }
        const idx = sessionModel.index(Math.max(0, Math.min(sessionIndex, sessionCount - 1)), 0);
        const name = String(sessionModel.data(idx, 0) || sessionModel.data(idx, 260) || "Plasma");
        return name;
    }

    readonly property string backgroundUrl: {
        if (typeof config !== "undefined" && config && config.background) {
            const bg = String(config.background);
            return bg.indexOf("://") >= 0 ? bg : ("file://" + bg);
        }
        return "file:///usr/share/plasma/look-and-feel/dev.danny.nordic/contents/splash/splash-start.jpg";
    }

    function submitLogin(): void {
        if (root.loggingIn || root.currentUserName.length === 0) {
            return;
        }
        root.userMenuOpen = false;
        root.sessionMenuOpen = false;
        root.loggingIn = true;
        root.statusMessage = "";
        root.isErrorMessage = false;
        sddm.login(root.currentUserName, passwordInput.text, root.sessionIndex);
    }

    function selectUser(idx: int): void {
        root.userIndex = idx;
        root.userMenuOpen = false;
        passwordInput.text = "";
        root.statusMessage = "";
        root.isErrorMessage = false;
        passwordInput.forceActiveFocus();
    }

    function selectSession(idx: int): void {
        root.sessionIndex = idx;
        root.sessionMenuOpen = false;
        passwordInput.forceActiveFocus();
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    Timer {
        id: statusClearTimer
        interval: 4000
        onTriggered: {
            root.statusMessage = "";
            root.isErrorMessage = false;
        }
    }

    Connections {
        target: sddm

        function onLoginSucceeded(): void {
            root.loggingIn = false;
        }

        function onLoginFailed(): void {
            root.loggingIn = false;
            root.statusMessage = "Login failed";
            root.isErrorMessage = true;
            passwordInput.text = "";
            rejectShake.restart();
            statusClearTimer.restart();
            passwordInput.forceActiveFocus();
        }

        function onInformationMessage(message: string): void {
            if (message && message.length > 0) {
                root.statusMessage = message;
                root.isErrorMessage = false;
                statusClearTimer.restart();
            }
        }
    }

    // Background: #11 Icelandic Volcanic Ring Road (exact PreserveAspectCrop matching Splash.qml)
    Rectangle {
        anchors.fill: parent
        color: "#080c12"
    }

    Image {
        anchors.fill: parent
        source: root.backgroundUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        smooth: true
    }

    // Click outside menus to close popups and refocus password input
    MouseArea {
        anchors.fill: parent
        onPressed: {
            root.userMenuOpen = false;
            root.sessionMenuOpen = false;
            passwordInput.forceActiveFocus();
        }
    }

    // ================================================================
    // OPTION 1 — CENTERED MIDNIGHT HORIZON (SYMMETRIC UPPER-SKY STACK)
    // ================================================================
    Column {
        id: centerCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(64, Math.round(parent.height * 0.145))
        width: 340
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.currentTime, "dddd, MMMM d")
            color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.76)
            font.family: "Manrope"
            font.pixelSize: 15
            font.weight: Font.Medium
            font.letterSpacing: 0.5
        }

        Item { width: 1; height: 4 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.currentTime, "HH:mm")
            color: "#eceff4"
            font.family: "Manrope"
            font.pixelSize: 92
            font.weight: Font.DemiBold
            font.letterSpacing: -2.4
            lineHeight: 0.98
        }

        Item { width: 1; height: 30 }

        // Username (plain clean text for 1 user; clickable switcher pill when 2+ users exist)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: userTrigger.implicitWidth
            height: userTrigger.implicitHeight
            z: 20

            Rectangle {
                id: userTrigger
                implicitWidth: userRow.implicitWidth + (root.multiUser ? 20 : 0)
                implicitHeight: root.multiUser ? 28 : 20
                radius: 8
                color: root.multiUser && (userMouse.containsMouse || root.userMenuOpen)
                    ? Qt.rgba(24 / 255, 32 / 255, 44 / 255, 0.78)
                    : "transparent"
                border.width: root.multiUser && (userMouse.containsMouse || root.userMenuOpen) ? 1 : 0
                border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.18)

                RowLayout {
                    id: userRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: root.currentUserLabel
                        color: Qt.rgba(236 / 255, 239 / 255, 244 / 255, 0.90)
                        font.family: "Manrope"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Image {
                        visible: root.multiUser
                        source: Qt.resolvedUrl("icons/chevron.svg")
                        sourceSize.width: 13
                        sourceSize.height: 13
                        Layout.preferredWidth: 13
                        Layout.preferredHeight: 13
                        smooth: true
                    }
                }

                MouseArea {
                    id: userMouse
                    anchors.fill: parent
                    enabled: root.multiUser
                    hoverEnabled: root.multiUser
                    cursorShape: root.multiUser ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.sessionMenuOpen = false;
                        root.userMenuOpen = !root.userMenuOpen;
                    }
                }
            }

            // Frosted dropdown for switching users (only shown when 2+ accounts exist)
            Rectangle {
                visible: root.userMenuOpen && root.multiUser
                anchors.top: userTrigger.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: 210
                height: Math.min(220, userListCol.implicitHeight + 12)
                radius: 12
                color: Qt.rgba(16 / 255, 22 / 255, 32 / 255, 0.94)
                border.width: 1
                border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.18)
                z: 40

                Column {
                    id: userListCol
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Repeater {
                        model: userModel

                        delegate: Rectangle {
                            id: userItem
                            required property int index
                            required property string name
                            required property string realName

                            readonly property bool isSelected: index === root.userIndex

                            width: userListCol.width
                            height: 32
                            radius: 8
                            color: uItemMouse.containsMouse
                                ? Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.72)
                                : (isSelected ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.14) : "transparent")

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: userItem.realName.length > 0 ? userItem.realName : userItem.name
                                elide: Text.ElideRight
                                color: userItem.isSelected ? "#a3be8c" : "#eceff4"
                                font.family: "Manrope"
                                font.pixelSize: 12
                                font.weight: userItem.isSelected ? Font.DemiBold : Font.Medium
                            }

                            MouseArea {
                                id: uItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectUser(userItem.index)
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 10 }

        // Frosted pill password input with sage focus ring + shake on error
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 268
            height: 42

            Rectangle {
                id: pwPill
                x: 0
                y: 0
                width: 268
                height: 42
                radius: 21
                color: Qt.rgba(16 / 255, 22 / 255, 32 / 255, 0.82)
                border.width: 1.5
                border.color: root.isErrorMessage
                    ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.86)
                    : Qt.rgba(163 / 255, 190 / 255, 140 / 255, passwordInput.activeFocus ? 0.78 : 0.44)

                SequentialAnimation {
                    id: rejectShake
                    NumberAnimation { target: pwPill; property: "x"; to: -8; duration: 45 }
                    NumberAnimation { target: pwPill; property: "x"; to: 8; duration: 55 }
                    NumberAnimation { target: pwPill; property: "x"; to: -5; duration: 45 }
                    NumberAnimation { target: pwPill; property: "x"; to: 4; duration: 45 }
                    NumberAnimation { target: pwPill; property: "x"; to: 0; duration: 40 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
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
                            enabled: !root.loggingIn
                            onTextEdited: {
                                if (root.isErrorMessage) {
                                    root.statusMessage = "";
                                    root.isErrorMessage = false;
                                }
                            }
                            onAccepted: root.submitLogin()
                            Keys.onEscapePressed: {
                                root.userMenuOpen = false;
                                root.sessionMenuOpen = false;
                                passwordInput.text = "";
                            }
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_F1 && root.sessionCount > 1) {
                                    root.sessionIndex = (root.sessionIndex + 1) % root.sessionCount;
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Circular sage submit button
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        radius: 14
                        color: submitMouse.containsMouse
                            ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.34)
                            : Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.22)
                        border.width: 1
                        border.color: Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.55)
                        opacity: root.loggingIn ? 0.45 : 1.0

                        Image {
                            anchors.centerIn: parent
                            source: Qt.resolvedUrl("icons/arrow.svg")
                            sourceSize.width: 14
                            sourceSize.height: 14
                            width: 14
                            height: 14
                            smooth: true
                        }

                        MouseArea {
                            id: submitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submitLogin()
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 10 }

        // Caps Lock + PAM error/info feedback
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text.length > 0
            text: {
                const parts = [];
                if (typeof keyboard !== "undefined" && keyboard && keyboard.capsLock) {
                    parts.push("Caps Lock is on");
                }
                if (root.statusMessage.length > 0) {
                    parts.push(root.statusMessage);
                }
                return parts.join(" \u00b7 ");
            }
            color: root.isErrorMessage
                ? "#bf616a"
                : ((typeof keyboard !== "undefined" && keyboard && keyboard.capsLock) ? "#ebcb8b" : "#88c0d0")
            font.family: "Manrope"
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    // ================================================================
    // BOTTOM-LEFT SESSION PICKER PILL + POPUP MENU
    // ================================================================
    Item {
        id: sessionAnchor
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.bottomMargin: 28
        width: sessionPill.implicitWidth
        height: sessionPill.implicitHeight
        z: 20

        Rectangle {
            id: sessionPill
            implicitWidth: sessRow.implicitWidth + 24
            implicitHeight: 36
            radius: 10
            color: (sessMouse.containsMouse || root.sessionMenuOpen)
                ? Qt.rgba(34 / 255, 44 / 255, 60 / 255, 0.84)
                : Qt.rgba(18 / 255, 24 / 255, 34 / 255, 0.74)
            border.width: 1
            border.color: (sessMouse.containsMouse || root.sessionMenuOpen)
                ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.45)
                : Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.14)

            RowLayout {
                id: sessRow
                anchors.centerIn: parent
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    Layout.alignment: Qt.AlignVCenter
                    radius: 3
                    color: "#88c0d0"
                }

                Text {
                    text: root.currentSessionName
                    color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.82)
                    font.family: "Manrope"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }

                Image {
                    visible: root.sessionCount > 1
                    source: Qt.resolvedUrl("icons/chevron.svg")
                    sourceSize.width: 13
                    sourceSize.height: 13
                    Layout.preferredWidth: 13
                    Layout.preferredHeight: 13
                    Layout.alignment: Qt.AlignVCenter
                    smooth: true
                }
            }

            MouseArea {
                id: sessMouse
                anchors.fill: parent
                enabled: root.sessionCount > 1
                hoverEnabled: true
                cursorShape: root.sessionCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.userMenuOpen = false;
                    root.sessionMenuOpen = !root.sessionMenuOpen;
                }
            }
        }

        // Frosted session list opening above the pill
        Rectangle {
            visible: root.sessionMenuOpen && root.sessionCount > 1
            anchors.bottom: sessionPill.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            width: Math.max(220, sessionPill.width)
            height: Math.min(260, sessListCol.implicitHeight + 12)
            radius: 12
            color: Qt.rgba(16 / 255, 22 / 255, 32 / 255, 0.94)
            border.width: 1
            border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.18)
            z: 40

            Column {
                id: sessListCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: sessionModel

                    delegate: Rectangle {
                        id: sItem
                        required property int index
                        required property string name

                        readonly property bool isSelected: index === root.sessionIndex

                        width: sessListCol.width
                        height: 32
                        radius: 8
                        color: sItemMouse.containsMouse
                            ? Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.72)
                            : (isSelected ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.14) : "transparent")

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            text: sItem.name
                            elide: Text.ElideRight
                            color: sItem.isSelected ? "#88c0d0" : "#eceff4"
                            font.family: "Manrope"
                            font.pixelSize: 12
                            font.weight: sItem.isSelected ? Font.DemiBold : Font.Medium
                        }

                        MouseArea {
                            id: sItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectSession(sItem.index)
                        }
                    }
                }
            }
        }
    }

    // ================================================================
    // BOTTOM-RIGHT QUIET POWER CONTROLS (SLEEP / RESTART / SHUT DOWN)
    // ================================================================
    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 28
        spacing: 9

        Text {
            visible: root.hoveredPowerLabel.length > 0
            text: root.hoveredPowerLabel
            color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.72)
            font.family: "Manrope"
            font.pixelSize: 12
            font.weight: Font.Medium
            Layout.rightMargin: 4
            Layout.alignment: Qt.AlignVCenter
        }

        component SddmPowerBtn: Rectangle {
            id: pbtn
            required property string iconFile
            required property string labelText
            property bool destructive: false
            signal triggered()

            implicitWidth: 36
            implicitHeight: 36
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 10
            color: pMouse.containsMouse
                ? (pbtn.destructive
                    ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.28)
                    : Qt.rgba(34 / 255, 44 / 255, 60 / 255, 0.84))
                : Qt.rgba(18 / 255, 24 / 255, 34 / 255, 0.74)
            border.width: 1
            border.color: pMouse.containsMouse
                ? (pbtn.destructive
                    ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.65)
                    : Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.48))
                : Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.14)

            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl(pbtn.iconFile)
                sourceSize.width: 17
                sourceSize.height: 17
                width: 17
                height: 17
                smooth: true
                opacity: pMouse.containsMouse ? 1.0 : 0.82
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

        SddmPowerBtn {
            visible: sddm.canSuspend
            iconFile: "icons/sleep.svg"
            labelText: "Sleep"
            onTriggered: sddm.suspend()
        }

        SddmPowerBtn {
            visible: sddm.canReboot
            iconFile: "icons/restart.svg"
            labelText: "Restart"
            onTriggered: sddm.reboot()
        }

        SddmPowerBtn {
            visible: sddm.canPowerOff
            iconFile: "icons/power.svg"
            labelText: "Shut Down"
            destructive: true
            onTriggered: sddm.powerOff()
        }
    }
}

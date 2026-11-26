pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

FocusScope {
    id: root
    width: 1200
    height: 740
    focus: true

    property date currentTime: new Date()
    property int userIndex: userModel && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: 0
    property bool userMenuOpen: false
    property bool sessionMenuOpen: false
    property int userMenuHighlight: 0
    property int sessionMenuHighlight: 0
    property bool loggingIn: false
    property string statusMessage: ""
    property bool isErrorMessage: false
    property string activePowerLabel: ""

    readonly property int userCount: userModel ? userModel.count : 0
    readonly property int sessionCount: sessionModel ? sessionModel.count : 0
    readonly property bool multiUser: userCount > 1

    // SDDM UserModel roles: NameRole = 257, RealNameRole = 258
    // SDDM SessionModel roles: NameRole = 260
    readonly property string currentUserName: {
        if (!userModel || userCount <= 0) {
            return userModel ? String(userModel.lastUser || "") : "";
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
        return String(sessionModel.data(idx, 260) || sessionModel.data(idx, 0) || "Plasma");
    }

    readonly property string backgroundUrl: {
        if (typeof config !== "undefined" && config && config.background) {
            const bg = String(config.background);
            return bg.indexOf("://") >= 0 ? bg : ("file://" + bg);
        }
        return "file:///usr/share/plasma/look-and-feel/dev.danny.nordic/contents/splash/splash-start.jpg";
    }

    readonly property bool capsLockOn: typeof keyboard !== "undefined" && keyboard ? Boolean(keyboard.capsLock) : false

    function pickInitialSession(): int {
        if (!sessionModel || sessionCount <= 0) {
            return 0;
        }
        // Respect SDDM's remembered last session when a prior login exists
        const hasLastUser = userModel && String(userModel.lastUser || "").length > 0;
        if (hasLastUser && sessionModel.lastIndex >= 0 && sessionModel.lastIndex < sessionCount) {
            return sessionModel.lastIndex;
        }
        // First-time SDDM boot: prefer Plasma over alphabetical fallback (e.g. GNOME Classic)
        for (let i = 0; i < sessionCount; i++) {
            const name = String(sessionModel.data(sessionModel.index(i, 0), 260) || "").toLowerCase();
            if (name.indexOf("plasma") >= 0) {
                return i;
            }
        }
        return Math.max(0, Math.min(sessionModel.lastIndex, sessionCount - 1));
    }

    function focusPassword(): void {
        passwordInput.forceActiveFocus();
    }

    function showError(msg: string): void {
        root.statusMessage = msg;
        root.isErrorMessage = true;
        rejectShake.restart();
    }

    function showInfo(msg: string): void {
        root.statusMessage = msg;
        root.isErrorMessage = false;
    }

    function submitLogin(): void {
        if (root.loggingIn) {
            return;
        }
        if (root.currentUserName.length === 0) {
            root.showError("No user selected");
            return;
        }
        if (passwordInput.text.length === 0) {
            root.showError("Enter your password");
            root.focusPassword();
            return;
        }
        root.userMenuOpen = false;
        root.sessionMenuOpen = false;
        root.loggingIn = true;
        root.statusMessage = "";
        root.isErrorMessage = false;
        loginTimeoutTimer.restart();
        sddm.login(root.currentUserName, passwordInput.text, root.sessionIndex);
    }

    function selectUser(idx: int): void {
        root.userIndex = Math.max(0, Math.min(idx, root.userCount - 1));
        root.userMenuOpen = false;
        passwordInput.text = "";
        root.statusMessage = "";
        root.isErrorMessage = false;
        root.focusPassword();
    }

    function selectSession(idx: int): void {
        root.sessionIndex = Math.max(0, Math.min(idx, root.sessionCount - 1));
        root.sessionMenuOpen = false;
        root.focusPassword();
    }

    Component.onCompleted: {
        root.sessionIndex = root.pickInitialSession();
        focusInitTimer.start();
    }

    // Ensure password field receives focus after Wayland/X11 greeter window activates
    Timer {
        id: focusInitTimer
        interval: 60
        repeat: false
        onTriggered: root.focusPassword()
    }

    Connections {
        target: root.Window.window
        ignoreUnknownSignals: true
        function onActiveChanged(): void {
            if (root.Window.window && root.Window.window.active) {
                root.focusPassword();
            }
        }
    }

    // Safety timeout so preview mode (no SDDM daemon socket) or stalled PAM never locks input
    Timer {
        id: loginTimeoutTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (root.loggingIn) {
                root.loggingIn = false;
                root.showError("Authentication did not respond (preview mode or daemon unavailable)");
                root.focusPassword();
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    Connections {
        target: sddm
        ignoreUnknownSignals: true

        function onLoginSucceeded(): void {
            loginTimeoutTimer.stop();
            root.loggingIn = false;
        }

        function onLoginFailed(): void {
            loginTimeoutTimer.stop();
            root.loggingIn = false;
            passwordInput.text = "";
            root.showError("Incorrect password — please try again");
            root.focusPassword();
        }

        function onInformationMessage(message: string): void {
            if (message && message.length > 0) {
                root.showInfo(message);
            }
        }

        function onErrorMessage(message: string): void {
            loginTimeoutTimer.stop();
            root.loggingIn = false;
            if (message && message.length > 0) {
                root.showError(message);
            }
            root.focusPassword();
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

    // Click empty background to close open popups and return focus to password field
    MouseArea {
        anchors.fill: parent
        onPressed: {
            root.userMenuOpen = false;
            root.sessionMenuOpen = false;
            root.focusPassword();
        }
    }

    // ================================================================
    // OPTION 1 — CENTERED MIDNIGHT HORIZON (SYMMETRIC UPPER-SKY STACK)
    // ================================================================
    Column {
        id: centerCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(60, Math.round(parent.height * 0.145))
        width: 360
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

        Item { width: 1; height: 28 }

        // Username (plain text for 1 user; Tab-focusable switcher pill when 2+ accounts exist)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: userTrigger.implicitWidth
            height: userTrigger.implicitHeight
            z: 20

            Rectangle {
                id: userTrigger
                activeFocusOnTab: root.multiUser
                implicitWidth: userRow.implicitWidth + (root.multiUser ? 22 : 0)
                implicitHeight: root.multiUser ? 30 : 20
                radius: 9
                color: root.multiUser && (userMouse.containsMouse || userTrigger.activeFocus || root.userMenuOpen)
                    ? Qt.rgba(28 / 255, 38 / 255, 52 / 255, 0.86)
                    : "transparent"
                border.width: root.multiUser
                    ? (userTrigger.activeFocus || root.userMenuOpen ? 2 : (userMouse.containsMouse ? 1 : 0))
                    : 0
                border.color: userTrigger.activeFocus || root.userMenuOpen
                    ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.90)
                    : Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.22)

                Keys.onPressed: function(event) {
                    if (!root.multiUser) {
                        return;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (root.userMenuOpen) {
                            root.selectUser(root.userMenuHighlight);
                        } else {
                            root.sessionMenuOpen = false;
                            root.userMenuHighlight = root.userIndex;
                            root.userMenuOpen = true;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        if (!root.userMenuOpen) {
                            root.userMenuOpen = true;
                            root.userMenuHighlight = root.userIndex;
                        } else {
                            root.userMenuHighlight = (root.userMenuHighlight + 1) % root.userCount;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up && root.userMenuOpen) {
                        root.userMenuHighlight = (root.userMenuHighlight - 1 + root.userCount) % root.userCount;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape && root.userMenuOpen) {
                        root.userMenuOpen = false;
                        event.accepted = true;
                    }
                }

                RowLayout {
                    id: userRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: root.currentUserLabel
                        color: Qt.rgba(236 / 255, 239 / 255, 244 / 255, 0.92)
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
                        userTrigger.forceActiveFocus();
                        root.sessionMenuOpen = false;
                        root.userMenuHighlight = root.userIndex;
                        root.userMenuOpen = !root.userMenuOpen;
                    }
                }
            }

            // Frosted user dropdown
            Rectangle {
                visible: root.userMenuOpen && root.multiUser
                anchors.top: userTrigger.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: 220
                height: Math.min(220, userListCol.implicitHeight + 12)
                radius: 12
                color: Qt.rgba(16 / 255, 22 / 255, 32 / 255, 0.95)
                border.width: 1
                border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.20)
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
                            readonly property bool isHighlighted: index === root.userMenuHighlight

                            width: userListCol.width
                            height: 32
                            radius: 8
                            color: (uItemMouse.containsMouse || isHighlighted)
                                ? Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.78)
                                : (isSelected ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.14) : "transparent")
                            border.width: isHighlighted ? 1 : 0
                            border.color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.55)

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
                                onEntered: root.userMenuHighlight = userItem.index
                                onClicked: root.selectUser(userItem.index)
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 10 }

        // Frosted pill password input — unmistakably distinct focus ring + blinking cursor
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 44

            // Subtle outer focus glow halo when password input is focused
            Rectangle {
                visible: passwordInput.activeFocus || root.isErrorMessage
                x: pwPill.x - 3
                y: pwPill.y - 3
                width: pwPill.width + 6
                height: pwPill.height + 6
                radius: 25
                color: "transparent"
                border.width: 2
                border.color: root.isErrorMessage
                    ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.34)
                    : Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.28)
            }

            Rectangle {
                id: pwPill
                x: 0
                y: 0
                width: 280
                height: 44
                radius: 22
                color: passwordInput.activeFocus
                    ? Qt.rgba(22 / 255, 30 / 255, 42 / 255, 0.90)
                    : Qt.rgba(16 / 255, 22 / 255, 32 / 255, 0.76)
                border.width: (passwordInput.activeFocus || root.isErrorMessage) ? 2 : 1
                border.color: root.isErrorMessage
                    ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.95)
                    : (passwordInput.activeFocus
                        ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.95)
                        : Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.20))

                SequentialAnimation {
                    id: rejectShake
                    NumberAnimation { target: pwPill; property: "x"; to: -8; duration: 45 }
                    NumberAnimation { target: pwPill; property: "x"; to: 8; duration: 55 }
                    NumberAnimation { target: pwPill; property: "x"; to: -5; duration: 45 }
                    NumberAnimation { target: pwPill; property: "x"; to: 4; duration: 45 }
                    NumberAnimation { target: pwPill; property: "x"; to: 0; duration: 40 }
                }

                // Clicking anywhere on the pill focuses the password field
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onPressed: function(mouse) {
                        root.focusPassword();
                        mouse.accepted = false;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 7
                    spacing: 8

                    QQC2.TextField {
                        id: passwordInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 160
                        focus: true
                        activeFocusOnTab: true
                        echoMode: TextInput.Password
                        passwordCharacter: "\u2022"
                        placeholderText: "Password"
                        placeholderTextColor: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.46)
                        color: "#eceff4"
                        selectionColor: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.38)
                        selectedTextColor: "#eceff4"
                        font.family: "Manrope"
                        font.pixelSize: 14
                        verticalAlignment: TextInput.AlignVCenter
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        background: Item {}
                        readOnly: root.loggingIn

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
                            root.statusMessage = "";
                            root.isErrorMessage = false;
                        }
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_F1 && root.sessionCount > 1) {
                                root.sessionIndex = (root.sessionIndex + 1) % root.sessionCount;
                                event.accepted = true;
                            }
                        }
                    }

                    // Circular sage submit button (Tab-focusable with clear focus ring)
                    Rectangle {
                        id: submitBtn
                        activeFocusOnTab: true
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: 15
                        color: (submitMouse.containsMouse || submitBtn.activeFocus)
                            ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.36)
                            : Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.20)
                        border.width: submitBtn.activeFocus ? 2 : 1
                        border.color: submitBtn.activeFocus
                            ? "#a3be8c"
                            : Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.55)
                        opacity: root.loggingIn ? 0.45 : 1.0

                        Keys.onReturnPressed: root.submitLogin()
                        Keys.onEnterPressed: root.submitLogin()
                        Keys.onSpacePressed: root.submitLogin()

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
                            onClicked: root.submitLogin()
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 12 }

        // High-visibility frosted error / Caps Lock / status banner
        Rectangle {
            id: noticeBanner
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property string fullNotice: {
                const parts = [];
                if (root.capsLockOn) {
                    parts.push("Caps Lock is on");
                }
                if (root.statusMessage.length > 0) {
                    parts.push(root.statusMessage);
                }
                return parts.join(" \u00b7 ");
            }
            visible: fullNotice.length > 0
            width: Math.min(350, Math.max(180, noticeText.implicitWidth + 28))
            height: noticeText.implicitHeight + 14
            radius: 10
            color: root.isErrorMessage
                ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.24)
                : (root.capsLockOn
                    ? Qt.rgba(235 / 255, 203 / 255, 139 / 255, 0.20)
                    : Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.18))
            border.width: 1.4
            border.color: root.isErrorMessage
                ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.85)
                : (root.capsLockOn
                    ? Qt.rgba(235 / 255, 203 / 255, 139 / 255, 0.72)
                    : Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.65))

            Text {
                id: noticeText
                anchors.centerIn: parent
                width: Math.min(322, implicitWidth)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: noticeBanner.fullNotice
                color: root.isErrorMessage
                    ? "#ffd6da"
                    : (root.capsLockOn ? "#f7e2b4" : "#d8eef5")
                font.family: "Manrope"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    // ================================================================
    // BOTTOM-LEFT SESSION PICKER PILL (KEYBOARD & MOUSE ACCESSIBLE)
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
            activeFocusOnTab: root.sessionCount > 1
            implicitWidth: sessRow.implicitWidth + 24
            implicitHeight: 36
            radius: 10
            color: (sessMouse.containsMouse || sessionPill.activeFocus || root.sessionMenuOpen)
                ? Qt.rgba(34 / 255, 44 / 255, 60 / 255, 0.88)
                : Qt.rgba(18 / 255, 24 / 255, 34 / 255, 0.74)
            border.width: (sessionPill.activeFocus || root.sessionMenuOpen) ? 2 : 1
            border.color: (sessionPill.activeFocus || root.sessionMenuOpen)
                ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.92)
                : (sessMouse.containsMouse
                    ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.48)
                    : Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.14))

            Keys.onPressed: function(event) {
                if (root.sessionCount <= 1) {
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (root.sessionMenuOpen) {
                        root.selectSession(root.sessionMenuHighlight);
                    } else {
                        root.userMenuOpen = false;
                        root.sessionMenuHighlight = root.sessionIndex;
                        root.sessionMenuOpen = true;
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    if (!root.sessionMenuOpen) {
                        root.sessionMenuOpen = true;
                        root.sessionMenuHighlight = root.sessionIndex;
                    } else {
                        root.sessionMenuHighlight = (root.sessionMenuHighlight - 1 + root.sessionCount) % root.sessionCount;
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down && root.sessionMenuOpen) {
                    root.sessionMenuHighlight = (root.sessionMenuHighlight + 1) % root.sessionCount;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape && root.sessionMenuOpen) {
                    root.sessionMenuOpen = false;
                    event.accepted = true;
                }
            }

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
                    color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.86)
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
                    sessionPill.forceActiveFocus();
                    root.userMenuOpen = false;
                    root.sessionMenuHighlight = root.sessionIndex;
                    root.sessionMenuOpen = !root.sessionMenuOpen;
                }
            }
        }

        // Frosted session dropdown above the pill
        Rectangle {
            visible: root.sessionMenuOpen && root.sessionCount > 1
            anchors.bottom: sessionPill.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            width: Math.max(220, sessionPill.width)
            height: Math.min(260, sessListCol.implicitHeight + 12)
            radius: 12
            color: Qt.rgba(16 / 255, 22 / 255, 32 / 255, 0.95)
            border.width: 1
            border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.20)
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
                        readonly property bool isHighlighted: index === root.sessionMenuHighlight

                        width: sessListCol.width
                        height: 32
                        radius: 8
                        color: (sItemMouse.containsMouse || isHighlighted)
                            ? Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.78)
                            : (isSelected ? Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.14) : "transparent")
                        border.width: isHighlighted ? 1 : 0
                        border.color: Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.55)

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
                            onEntered: root.sessionMenuHighlight = sItem.index
                            onClicked: root.selectSession(sItem.index)
                        }
                    }
                }
            }
        }
    }

    // ================================================================
    // BOTTOM-RIGHT POWER CONTROLS (TAB-FOCUSABLE WITH CLEAR FOCUS RING)
    // ================================================================
    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 28
        spacing: 9

        Text {
            visible: root.activePowerLabel.length > 0
            text: root.activePowerLabel
            color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.82)
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

            activeFocusOnTab: true
            implicitWidth: 36
            implicitHeight: 36
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 10
            color: (pMouse.containsMouse || pbtn.activeFocus)
                ? (pbtn.destructive
                    ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.30)
                    : Qt.rgba(34 / 255, 44 / 255, 60 / 255, 0.88))
                : Qt.rgba(18 / 255, 24 / 255, 34 / 255, 0.74)
            border.width: pbtn.activeFocus ? 2 : 1
            border.color: (pMouse.containsMouse || pbtn.activeFocus)
                ? (pbtn.destructive
                    ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.92)
                    : Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.92))
                : Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.14)

            onActiveFocusChanged: {
                if (activeFocus) {
                    root.activePowerLabel = pbtn.labelText;
                } else if (root.activePowerLabel === pbtn.labelText && !pMouse.containsMouse) {
                    root.activePowerLabel = "";
                }
            }

            Keys.onReturnPressed: pbtn.triggered()
            Keys.onEnterPressed: pbtn.triggered()
            Keys.onSpacePressed: pbtn.triggered()

            Image {
                anchors.centerIn: parent
                source: Qt.resolvedUrl(pbtn.iconFile)
                sourceSize.width: 17
                sourceSize.height: 17
                width: 17
                height: 17
                smooth: true
                opacity: (pMouse.containsMouse || pbtn.activeFocus) ? 1.0 : 0.82
            }

            MouseArea {
                id: pMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.activePowerLabel = pbtn.labelText
                onExited: {
                    if (root.activePowerLabel === pbtn.labelText && !pbtn.activeFocus) {
                        root.activePowerLabel = "";
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

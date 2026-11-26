pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin as KWin
import org.kde.kirigami as Kirigami

KWin.TabBoxSwitcher {
    id: tabBox

    // ClientModel::WIdRole = Qt::UserRole (256) + 5 = 261
    readonly property int widRole: 261

    // True when >=2 windows in the switcher belong to the exact same app (e.g. Alt+`),
    // automatically switching from the label-free Nordic squircle strip to the
    // icon-free live-thumbnail filmstrip with zero shortcut rebinding.
    property bool sameAppMode: false

    function recomputeMode(): void {
        const m = tabBox.model;
        if (!m || typeof m.rowCount !== "function") {
            tabBox.sameAppMode = false;
            return;
        }
        const count = m.rowCount();
        if (count < 2) {
            tabBox.sameAppMode = false;
            return;
        }

        const classById = {};
        const wins = KWin.Workspace.windows;
        if (wins) {
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i];
                if (!w) {
                    continue;
                }
                const cls = String(w.resourceClass || w.desktopFileName || "").toLowerCase();
                if (cls) {
                    classById[String(w.internalId)] = cls;
                }
            }
        }

        let firstCls = "";
        for (let r = 0; r < count; r++) {
            const idx = m.index(r, 0);
            const wid = m.data(idx, tabBox.widRole);
            const cls = classById[String(wid)] || "";
            if (!cls) {
                tabBox.sameAppMode = false;
                return;
            }
            if (r === 0) {
                firstCls = cls;
            } else if (cls !== firstCls) {
                tabBox.sameAppMode = false;
                return;
            }
        }
        tabBox.sameAppMode = true;
    }

    onAboutToShow: recomputeMode()
    onModelChanged: recomputeMode()
    onVisibleChanged: {
        if (visible) {
            recomputeMode();
        }
    }

    Connections {
        target: tabBox.model
        ignoreUnknownSignals: true
        function onModelReset(): void {
            tabBox.recomputeMode();
        }
        function onRowsInserted(): void {
            tabBox.recomputeMode();
        }
        function onRowsRemoved(): void {
            tabBox.recomputeMode();
        }
    }

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            id: dialog
            location: PlasmaCore.Types.Floating
            visible: true
            flags: Qt.ToolTip | Qt.X11BypassWindowManagerHint
            x: Math.round(tabBox.screenGeometry.x + (tabBox.screenGeometry.width - dialog.width) * 0.5)
            y: Math.round(tabBox.screenGeometry.y + (tabBox.screenGeometry.height - dialog.height) * 0.5)

            mainItem: FocusScope {
                id: dialogMainItem
                focus: true

                readonly property int itemCount: switcherList.count
                readonly property int pad: 4

                // Mode A (Alt+Tab): Label-free Nordic squircle strip
                readonly property int sqSize: 60
                readonly property int sqSpacing: 12

                // Mode B (Alt+`): Icon-free live-thumbnail filmstrip
                readonly property int cardWidth: 268
                readonly property int cardHeight: 198
                readonly property int cardSpacing: 14

                readonly property int itemWidth: tabBox.sameAppMode ? cardWidth : sqSize
                readonly property int itemHeight: tabBox.sameAppMode ? cardHeight : sqSize
                readonly property int itemSpacing: tabBox.sameAppMode ? cardSpacing : sqSpacing

                readonly property int maxWidth: Math.round(tabBox.screenGeometry.width * (tabBox.sameAppMode ? 0.90 : 0.85))
                readonly property int naturalWidth: itemCount > 0
                    ? (itemCount * itemWidth + Math.max(0, itemCount - 1) * itemSpacing + pad * 2)
                    : (sqSize + pad * 2)

                width: Math.min(naturalWidth, maxWidth)
                height: itemHeight + pad * 2

                ListView {
                    id: switcherList
                    anchors.fill: parent
                    anchors.margins: dialogMainItem.pad
                    orientation: ListView.Horizontal
                    spacing: dialogMainItem.itemSpacing
                    clip: true
                    focus: true
                    keyNavigationWraps: true
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds

                    model: tabBox.model
                    currentIndex: tabBox.currentIndex

                    onCurrentIndexChanged: {
                        if (tabBox.currentIndex !== currentIndex) {
                            tabBox.currentIndex = currentIndex;
                        }
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    Connections {
                        target: tabBox
                        function onCurrentIndexChanged(): void {
                            if (switcherList.currentIndex !== tabBox.currentIndex) {
                                switcherList.currentIndex = tabBox.currentIndex;
                            }
                            switcherList.positionViewAtIndex(switcherList.currentIndex, ListView.Contain);
                        }
                    }

                    delegate: Item {
                        id: entryRoot
                        required property int index
                        required property string caption
                        required property var icon
                        required property var windowId
                        required property bool closeable
                        required property bool minimized

                        readonly property bool isCurrent: ListView.isCurrentItem

                        width: dialogMainItem.itemWidth
                        height: dialogMainItem.itemHeight

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    if (entryRoot.closeable) {
                                        tabBox.model.close(entryRoot.index);
                                    }
                                    return;
                                }
                                tabBox.model.activate(entryRoot.index);
                            }
                        }

                        // ====================================================
                        // MODE A: Label-free 60x60 Nordic squircle icon tile
                        // ====================================================
                        Rectangle {
                            id: squircleCard
                            visible: !tabBox.sameAppMode
                            anchors.fill: parent
                            radius: 15
                            color: entryRoot.isCurrent
                                ? Qt.rgba(52 / 255, 68 / 255, 88 / 255, 0.78)
                                : (tileMouse.containsMouse
                                    ? Qt.rgba(46 / 255, 58 / 255, 76 / 255, 0.68)
                                    : Qt.rgba(38 / 255, 47 / 255, 62 / 255, 0.56))
                            border.width: entryRoot.isCurrent ? 1.8 : 1
                            border.color: entryRoot.isCurrent
                                ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.92)
                                : Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.12)

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                source: entryRoot.icon
                                active: entryRoot.isCurrent
                                opacity: entryRoot.minimized && !entryRoot.isCurrent ? 0.58 : 1.0
                            }
                        }

                        // ====================================================
                        // MODE B: Icon-free live-thumbnail preview card (Alt+`)
                        // ====================================================
                        Rectangle {
                            id: previewCard
                            visible: tabBox.sameAppMode
                            anchors.fill: parent
                            radius: 13
                            color: entryRoot.isCurrent
                                ? Qt.rgba(42 / 255, 56 / 255, 72 / 255, 0.78)
                                : (tileMouse.containsMouse
                                    ? Qt.rgba(36 / 255, 47 / 255, 62 / 255, 0.66)
                                    : Qt.rgba(30 / 255, 39 / 255, 52 / 255, 0.50))
                            border.width: entryRoot.isCurrent ? 2 : 1
                            border.color: entryRoot.isCurrent
                                ? Qt.rgba(163 / 255, 190 / 255, 140 / 255, 0.92)
                                : Qt.rgba(136 / 255, 192 / 255, 208 / 255, 0.22)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 9
                                    color: "#111722"
                                    border.width: 1
                                    border.color: Qt.rgba(186 / 255, 210 / 255, 238 / 255, 0.10)
                                    clip: true

                                    KWin.WindowThumbnail {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        wId: tabBox.sameAppMode ? entryRoot.windowId : ""
                                    }

                                    // Unobtrusive hover-only close button
                                    Rectangle {
                                        visible: entryRoot.closeable
                                            && (tileMouse.containsMouse || closeMouse.containsMouse)
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        width: 20
                                        height: 20
                                        radius: 6
                                        color: closeMouse.containsMouse
                                            ? Qt.rgba(191 / 255, 97 / 255, 106 / 255, 0.88)
                                            : Qt.rgba(20 / 255, 26 / 255, 36 / 255, 0.78)
                                        border.width: 1
                                        border.color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.20)
                                        z: 2

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u00d7"
                                            color: "#eceff4"
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                        }

                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                mouse.accepted = true;
                                                tabBox.model.close(entryRoot.index);
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 4
                                    Layout.rightMargin: 4
                                    text: entryRoot.caption
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    color: entryRoot.isCurrent
                                        ? "#eceff4"
                                        : Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.72)
                                    font.pixelSize: 12
                                    font.weight: entryRoot.isCurrent ? Font.DemiBold : Font.Medium
                                }
                            }
                        }
                    }
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        switcherList.decrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                        switcherList.incrementCurrentIndex();
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_W || event.key === Qt.Key_Delete) && switcherList.count > 0) {
                        tabBox.model.close(switcherList.currentIndex);
                        event.accepted = true;
                    }
                }
            }

            onSceneGraphError: () => {}
        }
    }
}

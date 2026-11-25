pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: true
        filterByScreen: true
        filterByActivity: true
        filterHidden: true

        onCountChanged: root.updateActiveWindow()
        onDataChanged: root.updateActiveWindow()
        onRowsInserted: root.updateActiveWindow()
        onRowsRemoved: root.updateActiveWindow()
        onModelReset: root.updateActiveWindow()
        onActiveTaskChanged: root.updateActiveWindow()
    }

    property string activeAppName: ""
    property string activeSubtitle: ""

    function cleanSubtitle(appName: string, rawTitle: string): string {
        if (!rawTitle) {
            return "";
        }
        let cleaned = rawTitle.trim();
        if (!appName) {
            return cleaned;
        }
        const lowerApp = appName.toLowerCase();
        if (cleaned.toLowerCase() === lowerApp) {
            return "";
        }
        const separators = [" — ", " – ", " - ", " · "];
        for (let i = 0; i < separators.length; ++i) {
            const sep = separators[i];
            const suffix = String(sep + appName);
            if (cleaned.toLowerCase().endsWith(suffix.toLowerCase())) {
                cleaned = cleaned.slice(0, cleaned.length - suffix.length).trim();
                break;
            }
            const prefix = String(appName + sep);
            if (cleaned.toLowerCase().startsWith(prefix.toLowerCase())) {
                cleaned = cleaned.slice(prefix.length).trim();
                break;
            }
        }
        return cleaned;
    }

    function updateActiveWindow(): void {
        const total = tasksModel.count;
        for (let i = 0; i < total; ++i) {
            const idx = tasksModel.makeModelIndex(i);
            const isActive = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive);
            const isMinimized = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized);
            if (isActive && !isMinimized) {
                const app = String(tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName) || "").trim();
                const title = String(tasksModel.data(idx, Qt.DisplayRole) || "").trim();
                activeAppName = app || title;
                activeSubtitle = app ? cleanSubtitle(app, title) : "";
                return;
            }
        }
        activeAppName = "";
        activeSubtitle = "";
    }

    Component.onCompleted: updateActiveWindow()

    fullRepresentation: Item {
        id: titleBarItem
        readonly property bool hasWindow: root.activeAppName.length > 0

        implicitWidth: hasWindow ? Math.min(420, contentRow.implicitWidth + 8) : 0
        implicitHeight: 24
        Layout.minimumWidth: 0
        Layout.preferredWidth: implicitWidth
        Layout.maximumWidth: 420
        Layout.fillHeight: true
        visible: hasWindow

        RowLayout {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            Rectangle {
                implicitWidth: 1
                implicitHeight: 14
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.16)
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
            }

            Text {
                id: appLabel
                text: root.activeAppName
                color: "#eceff4"
                font.pixelSize: 12.5
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 160
            }

            Text {
                id: subLabel
                text: root.activeSubtitle
                visible: text.length > 0
                color: Qt.rgba(216 / 255, 222 / 255, 233 / 255, 0.56)
                font.pixelSize: 12
                font.weight: Font.Normal
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}

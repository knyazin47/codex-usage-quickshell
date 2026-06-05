import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    implicitWidth: contentRow.implicitWidth + 12
    implicitHeight: Appearance.sizes.barHeight

    onClicked: usagePopup.toggle()

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: contentRow.left
        anchors.leftMargin: -6
        width: contentRow.width + 12
        height: Math.min(parent.height - 4, 26)
        radius: height / 2
        color: root.containsPress
            ? Appearance.colors.colLayer1Active
            : root.containsMouse
                ? Appearance.colors.colLayer1Hover
                : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        CustomIcon {
            Layout.alignment: Qt.AlignVCenter
            width: 22
            height: 22
            source: SystemColorScheme.dark ? "codex-cloud.svg" : "codex-color.svg"
            colorize: false

            Rectangle {
                z: -1
                visible: !SystemColorScheme.dark
                anchors.centerIn: parent
                width: 22
                height: 22
                radius: 999
                color: "white"

                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "Codex"
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer1
        }
    }

    CodexUsagePopup {
        id: usagePopup
        hoverTarget: root
    }
}

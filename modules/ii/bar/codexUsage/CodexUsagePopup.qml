import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root

    required property Item hoverTarget
    property bool popupOpen: false

    function toggle(): void {
        popupOpen = !popupOpen;
    }

    function close(): void {
        popupOpen = false;
    }

    function mappedX(item, x) {
        const mapped = root.QsWindow?.mapFromItem(item, x, 0);
        return Number.isFinite(mapped?.x) ? mapped.x : 0;
    }

    function mappedY(item, y) {
        const mapped = root.QsWindow?.mapFromItem(item, 0, y);
        return Number.isFinite(mapped?.y) ? mapped.y : 0;
    }

    LazyLoader {
        id: popupLoader
        active: root.popupOpen

        component: PanelWindow {
            id: popupWindow
            visible: true
            color: "transparent"

            anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
            anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
            anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
            anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

            implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

            mask: Region {
                item: popupBackground
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:codexUsagePopup"
            WlrLayershell.layer: WlrLayer.Overlay

            margins {
                left: {
                    if (!Config.options.bar.vertical)
                        return root.mappedX(root.hoverTarget, (root.hoverTarget.width - 612) / 2);
                    return Appearance.sizes.verticalBarWidth;
                }
                top: {
                    if (!Config.options.bar.vertical)
                        return Appearance.sizes.barHeight;
                    return root.mappedY(root.hoverTarget, (root.hoverTarget.height - popupBackground.implicitHeight) / 2);
                }
                right: Appearance.sizes.verticalBarWidth
                bottom: Appearance.sizes.barHeight
            }

            Rectangle {
                id: popupBackground
                anchors {
                    fill: parent
                    margins: Appearance.sizes.elevationMargin
                }
                implicitWidth: card.implicitWidth
                implicitHeight: card.implicitHeight
                color: "transparent"

                CodexUsageCard {
                    id: card
                    anchors.centerIn: parent
                }
            }
        }
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool ready: false
    property string scheme: ""
    readonly property bool dark: ready ? scheme.indexOf("dark") !== -1 : Appearance.m3colors.darkmode

    function parse(value) {
        const match = String(value).match(/'([^']+)'/);
        const nextScheme = (match ? match[1] : String(value).trim().replace(/'/g, ""));
        if (nextScheme.length === 0)
            return;

        scheme = nextScheme;
        ready = true;
    }

    function refresh() {
        if (readProc.running)
            readProc.running = false;
        readProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: readProc

        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: monitorProc

        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        stdout: SplitParser {
            onRead: data => root.parse(data)
        }
        onExited: (exitCode, exitStatus) => {
            if (root.ready || exitCode === 0)
                restartMonitor.restart();
        }
    }

    Timer {
        id: restartMonitor

        interval: 1000
        repeat: false
        onTriggered: {
            if (!monitorProc.running)
                monitorProc.running = true;
        }
    }
}

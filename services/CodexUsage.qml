pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool ok: false
    property string error: ""
    property string updatedAt: ""
    property string status: "Safe"
    property real primaryUsed: 0
    property real secondaryUsed: 0
    property int primaryPercent: 0
    property int secondaryPercent: 0
    property real primaryRemaining: 1
    property real secondaryRemaining: 1
    property int primaryRemainingPercent: 100
    property int secondaryRemainingPercent: 100
    property string reset: "--"
    property int todayTokens: 0
    property string todayTokensText: "0"
    property int weekTokens: 0
    property string weekTokensText: "0"
    property int lastTurnTokens: 0
    property string lastTurnTokensText: "0"
    property string inputTokensText: "0"
    property string cachedInputTokensText: "0"
    property string outputTokensText: "0"
    property string reasoningOutputTokensText: "0"
    property string modelContextWindowText: "0"
    property string topWorkspace: "none"
    property int eventCount: 0
    property list<real> activity: [0.08, 0.16, 0.24, 0.18, 0.32, 0.22, 0.12, 0.2]
    property var activityDetails: []
    property var limits: []
    property string limitsSource: "local"
    property string limitsSyncedAt: ""
    property string limitsError: ""
    property bool hasData: false
    property bool forceLiveRefresh: false
    property bool pendingForceRefresh: false
    readonly property bool enabled: Config.options.bar.codexUsage.enable
    readonly property bool refreshing: collector.running

    readonly property string scriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/codex-usage/codex_usage.py`
    readonly property color statusColor: primaryRemainingPercent <= 10 || secondaryRemainingPercent <= 10
        ? Appearance.colors.colError
        : primaryRemainingPercent <= 35 || secondaryRemainingPercent <= 35
            ? "#f0c36a"
            : "#8f8cff"
    readonly property color coolAccentColor: "#7aa2ff"
    readonly property color warmAccentColor: "#aa83ff"

    function needsLiveProbe() {
        return root.limitsSource !== "live" && root.limitsSource !== "cache";
    }

    function refresh(forceLive): void {
        if (!root.enabled)
            return;
        if (collector.running) {
            if (forceLive)
                root.pendingForceRefresh = true;
            return;
        }
        root.forceLiveRefresh = Boolean(forceLive);
        collector.running = true;
    }

    function applyData(data: var): void {
        root.ok = data.ok ?? false;
        root.error = data.error ?? "";
        if (!root.ok)
            return;

        root.hasData = true;
        root.updatedAt = data.updatedAt ?? "";
        root.status = data.status ?? "Safe";
        root.primaryUsed = data.primaryUsed ?? 0;
        root.secondaryUsed = data.secondaryUsed ?? 0;
        root.primaryPercent = data.primaryPercent ?? 0;
        root.secondaryPercent = data.secondaryPercent ?? 0;
        root.primaryRemaining = data.primaryRemaining ?? 1;
        root.secondaryRemaining = data.secondaryRemaining ?? 1;
        root.primaryRemainingPercent = data.primaryRemainingPercent ?? 100;
        root.secondaryRemainingPercent = data.secondaryRemainingPercent ?? 100;
        root.reset = data.reset ?? "--";
        root.todayTokens = data.todayTokens ?? 0;
        root.todayTokensText = data.todayTokensText ?? "0";
        root.weekTokens = data.weekTokens ?? 0;
        root.weekTokensText = data.weekTokensText ?? "0";
        root.lastTurnTokens = data.lastTurnTokens ?? 0;
        root.lastTurnTokensText = data.lastTurnTokensText ?? "0";
        root.inputTokensText = data.inputTokensText ?? "0";
        root.cachedInputTokensText = data.cachedInputTokensText ?? "0";
        root.outputTokensText = data.outputTokensText ?? "0";
        root.reasoningOutputTokensText = data.reasoningOutputTokensText ?? "0";
        root.modelContextWindowText = data.modelContextWindowText ?? "0";
        root.topWorkspace = data.topWorkspace ?? "none";
        root.eventCount = data.eventCount ?? 0;
        root.activity = data.activity ?? root.activity;
        root.activityDetails = data.activityDetails ?? [];
        root.limits = data.limits ?? [];
        root.limitsSource = data.limitsSource ?? "local";
        root.limitsSyncedAt = data.limitsSyncedAt ?? "";
        root.limitsError = data.limitsError ?? "";
    }

    onEnabledChanged: {
        if (root.enabled)
            root.refresh();
        else if (collector.running)
            collector.running = false;
    }

    Component.onCompleted: {
        if (root.enabled)
            root.refresh();
    }

    Timer {
        interval: Math.max(5, Config.options.bar.codexUsage.refreshInterval) * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh(root.needsLiveProbe())
    }

    Process {
        id: collector
        command: root.forceLiveRefresh ? ["python3", root.scriptPath, "--force-live"] : ["python3", root.scriptPath]

        onExited: (exitCode, exitStatus) => {
            const shouldForce = root.pendingForceRefresh;
            root.forceLiveRefresh = false;
            root.pendingForceRefresh = false;
            if (shouldForce)
                root.refresh(true);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.length)
                    return;
                try {
                    root.applyData(JSON.parse(text));
                } catch (error) {
                    root.ok = false;
                    root.error = String(error);
                    console.error(`[CodexUsage] Failed to parse collector output: ${error}`);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    root.ok = false;
                    root.error = text.trim();
                    console.error(`[CodexUsage] Collector error: ${root.error}`);
                }
            }
        }
    }
}

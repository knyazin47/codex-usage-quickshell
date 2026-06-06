import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: root

    readonly property bool russian: Config.options.bar.codexUsage.language === "ru"
        || (Config.options.bar.codexUsage.language === "auto"
            && (String(Config.options.language.ui).startsWith("ru") || Qt.locale().name.startsWith("ru")))
    readonly property bool compact: false
    readonly property bool balanced: false
    readonly property bool errorState: !CodexUsage.ok && CodexUsage.error.length > 0
    readonly property bool emptyError: errorState && !CodexUsage.hasData
    readonly property bool loading: !CodexUsage.hasData && !errorState
    property bool showSettings: false
    property string pendingLanguage: "auto"
    property string pendingAccentStyle: "codex"
    property string pendingCustomAccentBase: "#86a8ff"
    property int pendingCustomAccentHue: 220
    property int pendingCustomAccentTemperature: 0
    property bool pendingShowDetailedLimits: true
    property bool pendingShowActivity: true
    property bool pendingShowTokenBreakdown: true
    property int pendingRefreshInterval: 15

    readonly property bool darkTheme: SystemColorScheme.dark
    readonly property int mainWidth: 612
    readonly property int mainHeight: 464
    readonly property int drawerWidth: 218
    readonly property int drawerGap: 10
    readonly property int drawerOuterWidth: drawerWidth + drawerGap
    readonly property color accentA: accentColorA(Config.options.bar.codexUsage.accentStyle)
    readonly property color accentB: accentColorB(Config.options.bar.codexUsage.accentStyle)
    readonly property color accentC: accentColorC(Config.options.bar.codexUsage.accentStyle)
    readonly property color panelColor: darkTheme ? "#121114" : "#fbfbff"
    readonly property color subPanelColor: darkTheme ? "#46444d" : "#f1f0fa"
    readonly property color tileColor: darkTheme ? "#3f3d46" : "#ffffff"
    readonly property color railColor: darkTheme ? "#4a4853" : "#f2f1fb"
    readonly property color chipColor: darkTheme ? "#3a3840" : "#e7e5f0"
    readonly property color textPrimary: darkTheme ? "#f4f1f8" : "#1e1b23"
    readonly property color textSecondary: darkTheme ? "#bfb9c8" : "#6f6877"
    readonly property color outlineColor: darkTheme ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0.12, 0.10, 0.18, 0.12)

    readonly property bool settingsDirty: pendingLanguage !== Config.options.bar.codexUsage.language
        || pendingRefreshInterval !== Config.options.bar.codexUsage.refreshInterval

    implicitWidth: mainWidth + drawerOuterWidth
    implicitHeight: mainHeight

    function t(en, ru) {
        return russian ? ru : en;
    }

    function shortTime(value) {
        return value && value.length >= 16 ? value.slice(11, 16) : "--:--";
    }

    function normalizedHex(value, fallback) {
        const text = String(value || "").trim();
        const candidate = text.startsWith("#") ? text : `#${text}`;
        return /^#[0-9a-fA-F]{6}$/.test(candidate) ? candidate : fallback;
    }

    function clampNumber(value, min, max, fallback) {
        const number = Number(value);
        if (isNaN(number))
            return fallback;
        return Math.max(min, Math.min(max, number));
    }

    function customAccentBase() {
        return hslToHex({
            "h": customAccentHue(),
            "s": 0.78,
            "l": 0.70
        });
    }

    function customAccentHue() {
        const fallbackHue = rgbToHsl(hexToRgb(normalizedHex(Config.options.bar.codexUsage.customAccentBase, "#86a8ff"))).h;
        return Math.round(clampNumber(Config.options.bar.codexUsage.customAccentHue, 0, 360, fallbackHue));
    }

    function customAccentTemperature() {
        return Math.round(clampNumber(Config.options.bar.codexUsage.customAccentTemperature, -100, 100, 0));
    }

    function hexToRgb(hex) {
        const value = normalizedHex(hex, "#86a8ff").slice(1);
        return {
            "r": parseInt(value.slice(0, 2), 16) / 255,
            "g": parseInt(value.slice(2, 4), 16) / 255,
            "b": parseInt(value.slice(4, 6), 16) / 255
        };
    }

    function componentToHex(value) {
        const text = Math.round(clampNumber(value, 0, 1, 0) * 255).toString(16);
        return text.length === 1 ? `0${text}` : text;
    }

    function rgbToHex(rgb) {
        return `#${componentToHex(rgb.r)}${componentToHex(rgb.g)}${componentToHex(rgb.b)}`;
    }

    function hslToHex(hsl) {
        return rgbToHex(hslToRgb(hsl));
    }

    function rgbToHsl(rgb) {
        const r = rgb.r;
        const g = rgb.g;
        const b = rgb.b;
        const max = Math.max(r, g, b);
        const min = Math.min(r, g, b);
        const lightness = (max + min) / 2;
        let hue = 0;
        let saturation = 0;

        if (max !== min) {
            const delta = max - min;
            saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min);
            if (max === r)
                hue = (g - b) / delta + (g < b ? 6 : 0);
            else if (max === g)
                hue = (b - r) / delta + 2;
            else
                hue = (r - g) / delta + 4;
            hue /= 6;
        }

        return { "h": hue * 360, "s": saturation, "l": lightness };
    }

    function hueToRgb(p, q, t) {
        let value = t;
        if (value < 0)
            value += 1;
        if (value > 1)
            value -= 1;
        if (value < 1 / 6)
            return p + (q - p) * 6 * value;
        if (value < 1 / 2)
            return q;
        if (value < 2 / 3)
            return p + (q - p) * (2 / 3 - value) * 6;
        return p;
    }

    function hslToRgb(hsl) {
        const h = ((hsl.h % 360) + 360) % 360 / 360;
        const s = clampNumber(hsl.s, 0, 1, 0.7);
        const l = clampNumber(hsl.l, 0, 1, 0.65);
        if (s === 0)
            return { "r": l, "g": l, "b": l };

        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        return {
            "r": hueToRgb(p, q, h + 1 / 3),
            "g": hueToRgb(p, q, h),
            "b": hueToRgb(p, q, h - 1 / 3)
        };
    }

    function generatedAccent(baseHex, temperature, index) {
        const hsl = rgbToHsl(hexToRgb(baseHex));
        const temp = clampNumber(temperature, -100, 100, 0) / 100;
        // Custom mode is intentionally constrained: one base color fans out
        // into a small analogous palette so user edits stay polished.
        if (index === 1) {
            return rgbToHex(hslToRgb({
                "h": hsl.h + 22 + temp * 22,
                "s": clampNumber(hsl.s + 0.06, 0.42, 0.95, hsl.s),
                "l": clampNumber(hsl.l - 0.02, 0.48, 0.72, hsl.l)
            }));
        }
        if (index === 2) {
            return rgbToHex(hslToRgb({
                "h": hsl.h - 28 + temp * 12,
                "s": clampNumber(hsl.s + 0.10, 0.45, 1, hsl.s),
                "l": clampNumber(hsl.l + 0.02, 0.52, 0.76, hsl.l)
            }));
        }
        return normalizedHex(baseHex, "#86a8ff");
    }

    function customAccentA() {
        return generatedAccent(customAccentBase(), customAccentTemperature(), 0);
    }

    function customAccentB() {
        return generatedAccent(customAccentBase(), customAccentTemperature(), 1);
    }

    function customAccentC() {
        return generatedAccent(customAccentBase(), customAccentTemperature(), 2);
    }

    function accentColorA(style) {
        if (style === "custom")
            return customAccentA();
        if (style === "clean")
            return "#dfe5ff";
        if (style === "violet")
            return "#9f91ff";
        if (style === "mint")
            return "#62dcb4";
        if (style === "rose")
            return "#ff8fb3";
        return "#86a8ff";
    }

    function accentColorB(style) {
        if (style === "custom")
            return customAccentB();
        if (style === "clean")
            return "#aebaff";
        if (style === "violet")
            return "#bd8cff";
        if (style === "mint")
            return "#7aa2ff";
        if (style === "rose")
            return "#9c8cff";
        return "#948cff";
    }

    function accentColorC(style) {
        if (style === "custom")
            return customAccentC();
        if (style === "clean")
            return "#7aa2ff";
        if (style === "violet")
            return "#ff9ee8";
        if (style === "mint")
            return "#8cf4de";
        if (style === "rose")
            return "#66d9ff";
        return "#65d7ff";
    }

    function previewAccentColorA(style) {
        return style === "custom" ? generatedAccent(pendingCustomAccentBase, pendingCustomAccentTemperature, 0) : accentColorA(style);
    }

    function previewAccentColorB(style) {
        return style === "custom" ? generatedAccent(pendingCustomAccentBase, pendingCustomAccentTemperature, 1) : accentColorB(style);
    }

    function previewAccentColorC(style) {
        return style === "custom" ? generatedAccent(pendingCustomAccentBase, pendingCustomAccentTemperature, 2) : accentColorC(style);
    }

    function sourceLabel(source) {
        if (source === "live")
            return "live";
        if (source === "cache")
            return "cache";
        if (source === "stale")
            return "stale";
        return "local";
    }

    function sourceColor(source) {
        if (source === "live")
            return "#62dcb4";
        if (source === "cache")
            return root.accentC;
        if (source === "stale")
            return "#f0c36a";
        return root.textSecondary;
    }

    function sourceTooltip() {
        if (CodexUsage.limitsSource === "live")
            return root.t("Live account limits", "Живые лимиты аккаунта");
        if (CodexUsage.limitsSource === "cache")
            return `${root.t("Cached live limits", "Кэш живых лимитов")} · ${root.shortTime(CodexUsage.limitsSyncedAt)}`;
        if (CodexUsage.limitsSource === "stale")
            return `${root.t("Stale live cache", "Устаревший live-кэш")} · ${root.shortTime(CodexUsage.limitsSyncedAt)}`;
        return root.t("Local session metadata", "Локальные данные сессий");
    }

    function limitLabel(label) {
        if (label === "weekly")
            return t("week", "неделя");
        if (label === "limit")
            return t("limit", "лимит");
        return label;
    }

    function limitTitle(label) {
        if (label === "weekly")
            return t("Weekly limit", "Недельный лимит");
        if (label === "5h" || label === "limit")
            return t("5-hour window", "Окно 5 часов");
        return limitLabel(label);
    }

    function remainingText(percent) {
        return `${percent}% ${t("left", "осталось")}`;
    }

    function limitValueText(rowData) {
        if (loading)
            return "--";
        return `${rowData.remainingPercent}% ${t("left", "ост.")} · ${rowData.reset}`;
    }

    function limitAccentColor() {
        if (CodexUsage.primaryRemainingPercent <= 10 || CodexUsage.secondaryRemainingPercent <= 10)
            return Appearance.colors.colError;
        if (CodexUsage.primaryRemainingPercent <= 35 || CodexUsage.secondaryRemainingPercent <= 35)
            return "#f0c36a";
        return root.accentB;
    }

    function updatedText() {
        if (errorState && CodexUsage.hasData)
            return t("collector error · showing last data", "ошибка чтения · показаны прошлые данные");
        if (emptyError)
            return t("collector could not read Codex sessions", "не удалось прочитать сессии Codex");
        if (loading)
            return t("reading local Codex sessions", "читаю локальные сессии Codex");
        return `${t("updated", "обновлено")} ${shortTime(CodexUsage.updatedAt)} · ${t("auto", "авто")} ${Config.options.bar.codexUsage.refreshInterval}s`;
    }

    function weeklyReset() {
        if (CodexUsage.limits.length <= 0 || !CodexUsage.limits[0].rows || CodexUsage.limits[0].rows.length < 2)
            return "--";
        return CodexUsage.limits[0].rows[1].reset;
    }

    function fiveHourReset() {
        if (CodexUsage.limits.length <= 0 || !CodexUsage.limits[0].rows || CodexUsage.limits[0].rows.length < 1)
            return CodexUsage.reset;
        return CodexUsage.limits[0].rows[0].reset;
    }

    function limitAt(index) {
        if (!loading && CodexUsage.limits.length > index)
            return CodexUsage.limits[index];
        return { "title": "", "planType": "", "rows": [] };
    }

    function limitRowAt(limitData, index) {
        if (limitData && limitData.rows && limitData.rows.length > index)
            return limitData.rows[index];
        return {
            "label": index === 0 ? "5h" : "weekly",
            "remaining": 0,
            "remainingPercent": 0,
            "reset": ""
        };
    }

    function activityAt(index) {
        const fallback = [0.18, 0.28, 0.22, 0.38, 0.26, 0.44, 0.34, 0.22, 0.28, 0.2, 0.32, 0.24, 0.2, 0.3, 0.24, 0.36, 0.28, 0.22];
        if (!loading && CodexUsage.activityDetails.length > index)
            return CodexUsage.activityDetails[index];
        return { "hour": "--", "tokensText": "--", "intensity": fallback[index] ?? 0.2 };
    }

    function syncPendingSettings() {
        pendingLanguage = Config.options.bar.codexUsage.language;
        pendingAccentStyle = Config.options.bar.codexUsage.accentStyle;
        pendingCustomAccentBase = customAccentBase();
        pendingCustomAccentHue = customAccentHue();
        pendingCustomAccentTemperature = customAccentTemperature();
        pendingShowDetailedLimits = Config.options.bar.codexUsage.showDetailedLimits;
        pendingShowActivity = Config.options.bar.codexUsage.showActivity;
        pendingShowTokenBreakdown = Config.options.bar.codexUsage.showTokenBreakdown;
        pendingRefreshInterval = Config.options.bar.codexUsage.refreshInterval;
    }

    function applyPendingSettings() {
        Config.options.bar.codexUsage.language = pendingLanguage;
        Config.options.bar.codexUsage.refreshInterval = pendingRefreshInterval;
    }

    function applyAccentStyle(style) {
        pendingAccentStyle = style;
        Config.options.bar.codexUsage.accentStyle = style;
    }

    function applyCustomAccentBase(value) {
        const accent = normalizedHex(value, "#86a8ff");
        pendingCustomAccentBase = accent;
        pendingCustomAccentHue = Math.round(rgbToHsl(hexToRgb(accent)).h);
        Config.options.bar.codexUsage.customAccentHue = pendingCustomAccentHue;
        Config.options.bar.codexUsage.customAccentBase = accent;
    }

    function applyCustomAccentHue(value) {
        const hue = Math.round(clampNumber(value, 0, 360, 220));
        const accent = hslToHex({ "h": hue, "s": 0.78, "l": 0.70 });
        pendingCustomAccentHue = hue;
        pendingCustomAccentBase = accent;
        Config.options.bar.codexUsage.customAccentHue = hue;
        Config.options.bar.codexUsage.customAccentBase = accent;
    }

    function applyCustomAccentTemperature(value) {
        const temperature = Math.round(clampNumber(value, -100, 100, 0));
        pendingCustomAccentTemperature = temperature;
        Config.options.bar.codexUsage.customAccentTemperature = temperature;
    }

    function setDetailedLimitsShown(value) {
        pendingShowDetailedLimits = value;
        Config.options.bar.codexUsage.showDetailedLimits = value;
    }

    function setActivityShown(value) {
        pendingShowActivity = value;
        Config.options.bar.codexUsage.showActivity = value;
    }

    function setTokenBreakdownShown(value) {
        pendingShowTokenBreakdown = value;
        Config.options.bar.codexUsage.showTokenBreakdown = value;
    }

    Component.onCompleted: {
        syncPendingSettings();
    }

    onShowSettingsChanged: {
        if (showSettings)
            syncPendingSettings();
    }

    StyledRectangularShadow {
        target: mainSurface
    }

    StyledRectangularShadow {
        target: settingsDrawer
        visible: root.showSettings
    }

    Rectangle {
        id: mainSurface
        z: 2
        x: 0
        width: root.mainWidth
        height: root.mainHeight
        implicitHeight: root.mainHeight
        radius: Appearance.rounding.large
        color: root.panelColor
        border.width: 1
        border.color: root.outlineColor
        clip: true

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Rectangle {
            visible: false
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 2
            opacity: 0.88
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.accentA }
                GradientStop { position: 0.5; color: root.accentB }
                GradientStop { position: 1.0; color: root.accentC }
            }
        }

        RowLayout {
            id: mainContent
            width: parent.width - 28
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 14
                leftMargin: 14
            }
            spacing: 14

            Rectangle {
                id: statusRail
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 154
                Layout.preferredHeight: root.mainHeight - 28
                radius: Appearance.rounding.normal
                color: root.subPanelColor
                border.width: 1
                border.color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.24)
                clip: true

                Behavior on color {
                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    id: railColumn
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26

                        StyledText {
                            anchors.centerIn: parent
                            text: "Codex"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: root.textPrimary
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 112

                        LimitGauge {
                            id: primaryGauge
                            anchors.centerIn: parent
                            gaugeSize: 96
                            lineWidth: 7
                            value: root.loading ? 0.66 : CodexUsage.primaryRemaining
                            accent: root.loading ? root.accentB : root.limitAccentColor()
                            indeterminate: root.loading
                        }

                        Column {
                            anchors.centerIn: primaryGauge
                            spacing: 4

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loading ? "" : `${CodexUsage.primaryRemainingPercent}%`
                                font.pixelSize: 25
                                font.weight: Font.Bold
                                color: root.textPrimary
                            }

                            SkeletonBlock {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.loading
                                implicitWidth: 50
                                implicitHeight: 20
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.loading ? root.t("loading", "загрузка") : root.t("left", "осталось")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.textSecondary
                            }
                        }
                    }

                    ResetTimer {
                        Layout.alignment: Qt.AlignHCenter
                        value: root.loading ? "--" : root.fiveHourReset()
                        label: root.t("until reset", "до сброса")
                        placeholder: root.loading
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: Appearance.rounding.small
                        color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.11)
                        border.width: 1
                        border.color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.22)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 9

                            Item {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42

                                LimitGauge {
                                    id: weeklyGauge
                                    anchors.centerIn: parent
                                    gaugeSize: 42
                                    lineWidth: 5
                                    value: root.loading ? 0.62 : CodexUsage.secondaryRemaining
                                    accent: root.accentC
                                    indeterminate: root.loading
                                }

                            StyledText {
                                anchors.centerIn: weeklyGauge
                                visible: !root.loading
                                text: root.loading ? "--" : `${CodexUsage.secondaryRemainingPercent}`
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.textPrimary
                            }

                            SkeletonBlock {
                                anchors.centerIn: weeklyGauge
                                visible: root.loading
                                implicitWidth: 16
                                implicitHeight: 9
                            }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.limitLabel("weekly")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: root.textPrimary
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: !root.loading
                                    text: `${CodexUsage.secondaryRemainingPercent}% · ${root.weeklyReset()}`
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: root.textSecondary
                                    elide: Text.ElideRight
                                }

                                SkeletonBlock {
                                    Layout.preferredWidth: 54
                                    Layout.preferredHeight: 9
                                    visible: root.loading
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RailStatLine {
                            label: root.t("today", "сегодня")
                            value: root.loading ? "--" : CodexUsage.todayTokensText
                            placeholder: root.loading
                        }

                        RailStatLine {
                            label: root.t("turns", "ходы")
                            value: root.loading ? "--" : String(CodexUsage.eventCount)
                            placeholder: root.loading
                        }
                    }
                }
            }

            ColumnLayout {
                id: mainColumn
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            StyledText {
                                text: "Codex Usage"
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.Bold
                                color: root.textPrimary
                                elide: Text.ElideRight
                            }

                            DataSourceDot {
                                visible: !root.loading && !root.emptyError
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                Layout.fillWidth: true
                                text: root.updatedText()
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.textSecondary
                                elide: Text.ElideRight
                            }

                        }
                    }

                    RoundIconButton {
                        symbol: "refresh"
                        active: CodexUsage.refreshing
                        onTriggered: CodexUsage.refresh()
                    }

                    RoundIconButton {
                        symbol: root.showSettings ? "close" : "tune"
                        active: root.showSettings
                        onTriggered: root.showSettings = !root.showSettings
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MetricTile {
                        title: root.t("today", "сегодня")
                        value: CodexUsage.todayTokensText
                    }
                    MetricTile {
                        title: root.t("last turn", "последний ход")
                        value: CodexUsage.lastTurnTokensText
                    }
                    MetricTile {
                        title: root.t("context", "контекст")
                        value: CodexUsage.modelContextWindowText
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    visible: root.emptyError
                    radius: Appearance.rounding.normal
                    color: root.tileColor
                    border.width: 1
                    border.color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.24)

                    Behavior on color {
                        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        MaterialSymbol {
                            text: "error"
                            iconSize: 24
                            color: root.accentB
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: root.t("No Codex usage data yet", "Данных Codex пока нет")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: root.textPrimary
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: CodexUsage.error || root.t("Run Codex once, then refresh.", "Запусти Codex хотя бы один раз и обнови.")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.textSecondary
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                ColumnLayout {
                    property bool expanded: Config.options.bar.codexUsage.showDetailedLimits && !root.compact && !root.emptyError
                    property real animatedHeight: expanded ? implicitHeight : 0

                    Layout.fillWidth: true
                    Layout.preferredHeight: animatedHeight
                    visible: expanded || animatedHeight > 1
                    opacity: expanded ? 1 : 0
                    spacing: 7
                    clip: true

                    Behavior on animatedHeight {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    LimitModelCard {
                        Layout.fillWidth: true
                        limitData: root.limitAt(0)
                        placeholder: root.loading
                    }

                    LimitModelCard {
                        Layout.fillWidth: true
                        visible: root.loading || CodexUsage.limits.length > 1
                        limitData: root.limitAt(1)
                        placeholder: root.loading
                    }
                }

                ColumnLayout {
                    property bool expanded: Config.options.bar.codexUsage.showActivity && !root.compact && !root.emptyError
                    property real animatedHeight: expanded ? implicitHeight : 0

                    Layout.fillWidth: true
                    Layout.preferredHeight: animatedHeight
                    visible: expanded || animatedHeight > 1
                    opacity: expanded ? 1 : 0
                    spacing: 6
                    clip: true

                    Behavior on animatedHeight {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: root.t("activity", "активность")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: root.textSecondary
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            visible: !root.loading
                            text: root.t("last 18 hours", "последние 18 часов")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.textSecondary
                        }
                    }

                    Row {
                        id: activityBars
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        spacing: 4

                        Repeater {
                            model: 18

                            Item {
                                required property int index
                                readonly property var activityData: root.activityAt(index)
                                width: Math.max(6, (activityBars.width - activityBars.spacing * 17) / 18)
                                height: activityBars.height

                                MouseArea {
                                    id: activityMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: activityMouse.containsMouse ? parent.width + 2 : parent.width
                                    height: Math.max(4, parent.height * activityData.intensity)
                                    radius: Math.min(width, height) / 2
                                    color: root.accentA
                                    opacity: activityMouse.containsMouse ? 1 : 0.24 + activityData.intensity * 0.62
                                    transformOrigin: Item.Bottom

                                    Behavior on width {
                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on height {
                                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                    }
                                }

                                StyledToolTip {
                                    extraVisibleCondition: activityMouse.containsMouse
                                    text: root.loading ? root.t("Loading activity", "Загружаю активность") : `${activityData.hour} · ${activityData.tokensText} ${root.t("tokens", "токенов")}`
                                }
                            }
                        }
                    }
                }

                Flow {
                    property bool expanded: Config.options.bar.codexUsage.showTokenBreakdown && !root.balanced && !root.compact && !root.loading
                    property real animatedHeight: expanded ? implicitHeight : 0

                    Layout.fillWidth: true
                    Layout.preferredHeight: animatedHeight
                    visible: expanded || animatedHeight > 1
                    opacity: expanded ? 1 : 0
                    spacing: 7
                    clip: true

                    Behavior on animatedHeight {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    StatPill { label: root.t("week", "неделя"); value: CodexUsage.weekTokensText }
                    StatPill { label: root.t("input", "вход"); value: CodexUsage.inputTokensText }
                    StatPill { label: root.t("cached", "кэш"); value: CodexUsage.cachedInputTokensText }
                    StatPill { label: root.t("output", "выход"); value: CodexUsage.outputTokensText }
                    StatPill { label: root.t("reasoning", "reasoning"); value: CodexUsage.reasoningOutputTokensText }
                }
            }
        }
    }

    Rectangle {
        id: settingsDrawer
        z: 1
        width: root.drawerWidth
        height: mainSurface.height
        x: root.showSettings ? root.mainWidth + root.drawerGap : root.mainWidth - root.drawerWidth + 18
        y: 0
        visible: root.showSettings || opacity > 0.01
        opacity: root.showSettings ? 1 : 0
        radius: Appearance.rounding.large
        color: root.subPanelColor
        border.width: 1
        border.color: root.outlineColor
        clip: true

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on x {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "tune"
                    iconSize: 18
                    color: root.textPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.t("Settings", "Настройки")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Bold
                    color: root.textPrimary
                    elide: Text.ElideRight
                }
            }

            Flickable {
                id: settingsScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: settingsContent.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: settingsContent

                    width: settingsScroll.width
                    spacing: 9

                    SettingsSection {
                        title: root.t("language", "язык")
                        Flow {
                            Layout.fillWidth: true
                            spacing: 7
                            OptionChip { label: "auto"; active: root.pendingLanguage === "auto"; onClicked: root.pendingLanguage = "auto" }
                            OptionChip { label: "ru"; active: root.pendingLanguage === "ru"; onClicked: root.pendingLanguage = "ru" }
                            OptionChip { label: "en"; active: root.pendingLanguage === "en"; onClicked: root.pendingLanguage = "en" }
                        }
                    }

                    SettingsSection {
                        title: root.t("palette", "палитра")
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            PaletteChip { label: "codex"; styleName: "codex"; active: root.pendingAccentStyle === "codex"; onClicked: root.applyAccentStyle("codex") }
                            PaletteChip { label: "violet"; styleName: "violet"; active: root.pendingAccentStyle === "violet"; onClicked: root.applyAccentStyle("violet") }
                            PaletteChip { label: "mint"; styleName: "mint"; active: root.pendingAccentStyle === "mint"; onClicked: root.applyAccentStyle("mint") }
                            PaletteChip { label: "rose"; styleName: "rose"; active: root.pendingAccentStyle === "rose"; onClicked: root.applyAccentStyle("rose") }
                            PaletteChip { label: "clean"; styleName: "clean"; active: root.pendingAccentStyle === "clean"; onClicked: root.applyAccentStyle("clean") }
                            PaletteChip { label: "custom"; styleName: "custom"; active: root.pendingAccentStyle === "custom"; onClicked: root.applyAccentStyle("custom") }
                        }
                    }

                    SettingsSection {
                        visible: root.pendingAccentStyle === "custom"
                        title: root.t("custom", "свой цвет")

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 9

                            HueSlider {
                                Layout.fillWidth: true
                                value: root.pendingCustomAccentHue
                                onMoved: newValue => root.applyCustomAccentHue(newValue)
                            }

                            TemperatureSlider {
                                Layout.fillWidth: true
                                value: root.pendingCustomAccentTemperature
                                onMoved: newValue => root.applyCustomAccentTemperature(newValue)
                            }
                        }
                    }

                    SettingsSection {
                        title: root.t("show", "показывать")
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            ToggleRow {
                                label: root.t("limits", "лимиты")
                                checked: Config.options.bar.codexUsage.showDetailedLimits
                                onClicked: root.setDetailedLimitsShown(!Config.options.bar.codexUsage.showDetailedLimits)
                            }
                            ToggleRow {
                                label: root.t("activity", "активность")
                                checked: Config.options.bar.codexUsage.showActivity
                                onClicked: root.setActivityShown(!Config.options.bar.codexUsage.showActivity)
                            }
                            ToggleRow {
                                label: root.t("tokens", "токены")
                                checked: Config.options.bar.codexUsage.showTokenBreakdown
                                onClicked: root.setTokenBreakdownShown(!Config.options.bar.codexUsage.showTokenBreakdown)
                            }
                        }
                    }

                    SettingsSection {
                        title: root.t("refresh", "обновление")
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            OptionChip { label: "5s"; active: root.pendingRefreshInterval === 5; onClicked: root.pendingRefreshInterval = 5 }
                            OptionChip { label: "15s"; active: root.pendingRefreshInterval === 15; onClicked: root.pendingRefreshInterval = 15 }
                            OptionChip { label: "30s"; active: root.pendingRefreshInterval === 30; onClicked: root.pendingRefreshInterval = 30 }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    id: cancelButton

                    Layout.fillWidth: true
                    implicitHeight: 32
                    enabled: root.settingsDirty
                    opacity: enabled ? 1 : 0.42
                    radius: 999
                    color: cancelMouse.containsMouse
                        ? root.chipColor
                        : root.chipColor
                    border.width: 1
                    border.color: root.outlineColor

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        enabled: cancelButton.enabled
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.syncPendingSettings()
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.t("Cancel", "Отмена")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                    }
                }

                Rectangle {
                    id: applyButton

                    Layout.fillWidth: true
                    implicitHeight: 32
                    enabled: root.settingsDirty
                    opacity: enabled ? 1 : 0.42
                    radius: 999
                    color: applyMouse.containsMouse
                        ? Qt.rgba(root.accentC.r, root.accentC.g, root.accentC.b, 0.34)
                        : Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.26)
                    border.width: 1
                    border.color: Qt.rgba(root.accentC.r, root.accentC.g, root.accentC.b, 0.52)

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        enabled: applyButton.enabled
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.applyPendingSettings()
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.t("Apply", "Применить")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: root.textPrimary
                    }
                }
            }
        }
    }

    component LimitGauge: Item {
        id: gauge

        property int gaugeSize: 92
        property int lineWidth: 6
        property real value: 1
        property real animatedValue: value
        property color accent: root.accentB
        property bool indeterminate: false

        implicitWidth: gaugeSize
        implicitHeight: gaugeSize
        rotation: indeterminate ? 360 : 0

        Behavior on animatedValue {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
            }
        }

        RotationAnimation on rotation {
            running: gauge.indeterminate
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1200
            easing.type: Easing.Linear
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.rgba(gauge.accent.r, gauge.accent.g, gauge.accent.b, 0.18)
                strokeWidth: gauge.lineWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"

                PathAngleArc {
                    centerX: gauge.width / 2
                    centerY: gauge.height / 2
                    radiusX: gauge.width / 2 - gauge.lineWidth
                    radiusY: gauge.height / 2 - gauge.lineWidth
                    startAngle: -135
                    sweepAngle: -270
                }
            }

            ShapePath {
                strokeColor: gauge.accent
                strokeWidth: gauge.lineWidth
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"

                PathAngleArc {
                    centerX: gauge.width / 2
                    centerY: gauge.height / 2
                    radiusX: gauge.width / 2 - gauge.lineWidth
                    radiusY: gauge.height / 2 - gauge.lineWidth
                    startAngle: -135
                    sweepAngle: -Math.max(2, Math.min(1, gauge.animatedValue) * 270)
                }
            }
        }
    }

    component MetricTile: Rectangle {
        required property string title
        required property string value

        Layout.fillWidth: true
        implicitHeight: 50
        radius: Appearance.rounding.small
        color: root.tileColor
        border.width: 1
        border.color: root.outlineColor

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.loading ? "" : value
                visible: !root.loading
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                color: root.textPrimary
                elide: Text.ElideRight
            }

            SkeletonBlock {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 16
                visible: root.loading
            }

            StyledText {
                Layout.fillWidth: true
                text: title
                visible: !root.loading
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.textSecondary
                elide: Text.ElideRight
            }

            SkeletonBlock {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 10
                visible: root.loading
            }
        }
    }

    component LimitModelCard: Rectangle {
        id: limitModelCard

        required property var limitData
        property bool placeholder: false

        implicitHeight: limitColumn.implicitHeight + 14
        radius: Appearance.rounding.small
        color: root.subPanelColor
        border.width: 1
        border.color: root.outlineColor

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: limitColumn
            width: parent.width - 16
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 7
                leftMargin: 8
            }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    visible: !limitModelCard.placeholder
                    text: limitModelCard.placeholder ? "" : (limitData.title || "Codex")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: root.textPrimary
                    elide: Text.ElideRight
                }

                SkeletonBlock {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 12
                    visible: limitModelCard.placeholder
                }

                StyledText {
                    visible: Boolean(limitData.planType) && !limitModelCard.placeholder
                    text: String(limitData.planType)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.textSecondary
                }
            }

            LimitProgressRow {
                Layout.fillWidth: true
                rowData: root.limitRowAt(limitModelCard.limitData, 0)
                placeholder: limitModelCard.placeholder
            }

            LimitProgressRow {
                Layout.fillWidth: true
                rowData: root.limitRowAt(limitModelCard.limitData, 1)
                placeholder: limitModelCard.placeholder
            }
        }
    }

    component LimitProgressRow: ColumnLayout {
        id: limitProgressRow

        required property var rowData
        property bool placeholder: false
        property color fillA: rowData.remainingPercent <= 10
            ? "#ff8f86"
            : rowData.remainingPercent <= 35
                ? "#f0c36a"
                : root.accentA
        property color fillB: rowData.remainingPercent <= 10
            ? "#ff9a8a"
            : rowData.remainingPercent <= 35
                ? "#ffe08a"
                : root.accentB
        property color fillC: rowData.remainingPercent <= 10
            ? "#ffcfbc"
            : rowData.remainingPercent <= 35
                ? "#fff0b8"
                : root.accentC

        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                visible: !limitProgressRow.placeholder
                text: limitProgressRow.placeholder ? "" : root.limitTitle(rowData.label)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.textSecondary
                elide: Text.ElideRight
            }

            SkeletonBlock {
                Layout.fillWidth: true
                Layout.preferredWidth: 78
                Layout.preferredHeight: 10
                visible: limitProgressRow.placeholder
            }

            StyledText {
                visible: !limitProgressRow.placeholder
                text: root.limitValueText(rowData)
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: root.textPrimary
                elide: Text.ElideRight
            }
        }

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            value: rowData.remaining ?? 0
            fillA: limitProgressRow.fillA
            fillB: limitProgressRow.fillB
            fillC: limitProgressRow.fillC
            animated: !limitProgressRow.placeholder
        }
    }

    component ProgressBar: Rectangle {
        id: bar

        property real value: 0
        property color fillA: root.accentA
        property color fillB: root.accentB
        property color fillC: root.accentC
        property bool animated: true

        radius: height / 2
        color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.14)
        clip: true

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: fillBar
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, bar.value)))
            radius: height / 2
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: bar.fillB }
                GradientStop { position: 0.50; color: bar.fillA }
                GradientStop { position: 1.00; color: bar.fillC }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                opacity: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: bar.fillC }
                    GradientStop { position: 0.50; color: bar.fillB }
                    GradientStop { position: 1.00; color: bar.fillA }
                }

                SequentialAnimation on opacity {
                    running: bar.animated && fillBar.width > 12
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.04; to: 0.48; duration: 820; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.48; to: 0.04; duration: 820; easing.type: Easing.InOutSine }
                }
            }

            Behavior on width {
                NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
            }
        }
    }

    component StatPill: Rectangle {
        required property string label
        required property string value

        implicitWidth: statRow.implicitWidth + 16
        implicitHeight: 26
        radius: 999
        color: root.chipColor
        border.width: 1
        border.color: root.outlineColor

        Behavior on color {
            ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Row {
            id: statRow
            anchors.centerIn: parent
            spacing: 5

            StyledText {
                text: label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.textSecondary
            }

            StyledText {
                text: value
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: root.textPrimary
            }
        }
    }

    component RailStatLine: RowLayout {
        required property string label
        required property string value
        property bool placeholder: false

        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.textSecondary
            elide: Text.ElideRight
        }

        StyledText {
            visible: !parent.placeholder
            text: value
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.textPrimary
            elide: Text.ElideRight
        }

        SkeletonBlock {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 9
            visible: parent.placeholder
        }
    }

    component ResetTimer: Rectangle {
        required property string value
        required property string label
        property bool placeholder: false

        implicitWidth: 98
        implicitHeight: 46
        radius: 999
        color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.13)
        border.width: 1
        border.color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.24)

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !parent.parent.placeholder
                text: value
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                color: root.textPrimary
            }

            SkeletonBlock {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: parent.parent.placeholder
                implicitWidth: 30
                implicitHeight: 14
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !parent.parent.placeholder
                text: label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.textSecondary
            }

            SkeletonBlock {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: parent.parent.placeholder
                implicitWidth: 46
                implicitHeight: 8
            }
        }
    }

    component RoundIconButton: MouseArea {
        id: button

        required property string symbol
        property bool active: false
        readonly property bool pulsing: button.symbol === "refresh" && button.active

        signal triggered()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.triggered()

        Rectangle {
            anchors.fill: parent
            radius: 999
            color: button.containsPress
                ? Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.30)
                : button.active
                    ? Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.2)
                    : button.containsMouse
                        ? root.chipColor
                        : Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.11)
            border.width: 1
            border.color: button.active
                ? Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.42)
                : Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.22)

            Behavior on color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 4
            height: parent.height - 4
            radius: 999
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.55)
            opacity: button.pulsing ? 0.75 : 0
            scale: button.pulsing ? 1 : 0.86

            SequentialAnimation on opacity {
                running: button.pulsing
                loops: Animation.Infinite
                NumberAnimation { from: 0.35; to: 0.85; duration: 520; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.85; to: 0.35; duration: 520; easing.type: Easing.InOutSine }
            }

            SequentialAnimation on scale {
                running: button.pulsing
                loops: Animation.Infinite
                NumberAnimation { from: 0.84; to: 1; duration: 520; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.84; duration: 520; easing.type: Easing.InOutSine }
            }

            Behavior on opacity {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.symbol
            iconSize: 18
            color: root.textPrimary
        }
    }

    component SettingsSection: ColumnLayout {
        required property string title

        Layout.fillWidth: true
        spacing: 5

        StyledText {
            Layout.fillWidth: true
            text: parent.title
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.textSecondary
            elide: Text.ElideRight
        }
    }

    component DataSourceDot: MouseArea {
        id: dot

        readonly property color dotColor: root.sourceColor(CodexUsage.limitsSource)

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 14
        Layout.preferredHeight: 14
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 999
            color: dot.dotColor
            border.width: 1
            border.color: Qt.rgba(dot.dotColor.r, dot.dotColor.g, dot.dotColor.b, 0.58)
            opacity: dot.containsMouse ? 1 : 0.84

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        StyledToolTip {
            extraVisibleCondition: dot.containsMouse
            text: CodexUsage.limitsError.length > 0
                ? `${root.sourceLabel(CodexUsage.limitsSource)} · ${root.sourceTooltip()} · ${CodexUsage.limitsError}`
                : `${root.sourceLabel(CodexUsage.limitsSource)} · ${root.sourceTooltip()}`
        }
    }

    component PaletteChip: MouseArea {
        id: palette

        required property string label
        required property string styleName
        property bool active: false
        readonly property color swatchA: root.previewAccentColorA(styleName)
        readonly property color swatchB: root.previewAccentColorB(styleName)
        readonly property color swatchC: root.previewAccentColorC(styleName)

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        implicitWidth: 92
        implicitHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: 999
            color: palette.active
                ? Qt.rgba(palette.swatchB.r, palette.swatchB.g, palette.swatchB.b, 0.22)
                : palette.containsMouse
                    ? root.chipColor
                    : root.chipColor
            border.width: 1
            border.color: palette.active
                ? Qt.rgba(palette.swatchC.r, palette.swatchC.g, palette.swatchC.b, 0.58)
                : root.outlineColor

            Behavior on color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 7

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: -2

                Repeater {
                    model: [palette.swatchA, palette.swatchB, palette.swatchC]

                    Rectangle {
                        required property color modelData

                        width: 10
                        height: 10
                        radius: 999
                        color: modelData
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, root.darkTheme ? 0.18 : 0.72)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: palette.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: palette.active ? Font.DemiBold : Font.Normal
                color: palette.active ? root.textPrimary : root.textSecondary
                elide: Text.ElideRight
            }
        }
    }

    component HueSlider: MouseArea {
        id: slider

        property int value: 220

        signal moved(int newValue)

        implicitHeight: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updateFromX(xValue) {
            const ratio = Math.max(0, Math.min(1, xValue / Math.max(1, width)));
            slider.moved(Math.round(ratio * 360));
        }

        onPressed: event => slider.updateFromX(event.x)
        onPositionChanged: event => {
            if (pressed)
                slider.updateFromX(event.x);
        }

        Rectangle {
            id: hueTrack
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: 12
            radius: 999
            border.width: 1
            border.color: root.outlineColor
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ff5f7a" }
                GradientStop { position: 0.16; color: "#f0c36a" }
                GradientStop { position: 0.33; color: "#62dcb4" }
                GradientStop { position: 0.50; color: "#65d7ff" }
                GradientStop { position: 0.66; color: "#7aa2ff" }
                GradientStop { position: 0.83; color: "#bd8cff" }
                GradientStop { position: 1.0; color: "#ff5f7a" }
            }
        }

        Rectangle {
            width: 20
            height: 20
            radius: 999
            x: Math.max(0, Math.min(parent.width - width, (slider.value / 360) * parent.width - width / 2))
            y: hueTrack.y + hueTrack.height / 2 - height / 2
            color: root.hslToHex({ "h": slider.value, "s": 0.78, "l": 0.70 })
            border.width: 2
            border.color: root.textPrimary

            Behavior on x {
                NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
            }
        }
    }

    component TemperatureSlider: MouseArea {
        id: slider

        property int value: 0

        signal moved(int newValue)

        implicitHeight: 38
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updateFromX(xValue) {
            const ratio = Math.max(0, Math.min(1, xValue / Math.max(1, width)));
            slider.moved(Math.round((ratio * 200 - 100) / 5) * 5);
        }

        onPressed: event => slider.updateFromX(event.x)
        onPositionChanged: event => {
            if (pressed)
                slider.updateFromX(event.x);
        }

        RowLayout {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 14

            StyledText {
                text: root.t("cool", "холоднее")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.textSecondary
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: root.t("warm", "теплее")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.textSecondary
            }
        }

        Rectangle {
            id: tempTrack
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 7
            }
            height: 8
            radius: 999
            border.width: 1
            border.color: root.outlineColor
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.previewAccentColorC("custom") }
                GradientStop { position: 0.5; color: root.previewAccentColorA("custom") }
                GradientStop { position: 1.0; color: root.previewAccentColorB("custom") }
            }
        }

        Rectangle {
            width: 18
            height: 18
            radius: 999
            x: Math.max(0, Math.min(parent.width - width, ((slider.value + 100) / 200) * parent.width - width / 2))
            y: tempTrack.y + tempTrack.height / 2 - height / 2
            color: root.tileColor
            border.width: 2
            border.color: root.previewAccentColorB("custom")

            Behavior on x {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }
    }

    component OptionChip: MouseArea {
        id: chip

        required property string label
        property bool active: false

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        implicitWidth: chipText.implicitWidth + 28
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: 999
            color: chip.active
                ? Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.24)
                : chip.containsMouse
                    ? root.chipColor
                    : root.chipColor
            border.width: 1
            border.color: chip.active
                ? Qt.rgba(root.accentC.r, root.accentC.g, root.accentC.b, 0.52)
                : root.outlineColor

            Behavior on color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            visible: chip.active
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 9
            }
            width: 6
            height: 6
            radius: 999
            color: root.accentC
        }

        StyledText {
            id: chipText
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: chip.active ? 5 : 0
            text: chip.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: chip.active ? Font.DemiBold : Font.Normal
            color: chip.active ? root.textPrimary : root.textSecondary
        }
    }

    component ToggleRow: MouseArea {
        id: toggle

        required property string label
        property bool checked: false

        Layout.fillWidth: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        implicitHeight: 28

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: toggle.containsMouse
                ? Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.16)
                : root.chipColor
            border.width: 1
            border.color: root.outlineColor

            Behavior on color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors {
                leftMargin: 12
                rightMargin: 7
                topMargin: 6
                bottomMargin: 6
            }
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: toggle.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.textPrimary
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 16
                radius: 999
                color: toggle.checked
                    ? Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.44)
                    : Qt.rgba(root.textSecondary.r, root.textSecondary.g, root.textSecondary.b, 0.18)

                Rectangle {
                    width: 12
                    height: 12
                    radius: 999
                    y: 2
                    x: toggle.checked ? 14 : 2
                    color: toggle.checked ? root.accentC : root.textSecondary

                    Behavior on x {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    component SkeletonBlock: Rectangle {
        id: skeleton

        radius: Math.min(width, height) / 2
        color: Qt.rgba(root.accentB.r, root.accentB.g, root.accentB.b, 0.16)
        opacity: 0.52

        SequentialAnimation on opacity {
            running: skeleton.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.32; to: 0.72; duration: 760; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.72; to: 0.32; duration: 760; easing.type: Easing.InOutSine }
        }
    }
}

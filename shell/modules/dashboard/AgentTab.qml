// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Taris.Config
import Taris.I18n
import qs.components
import qs.components.controls
import qs.services

// Agent tab, ported from the Witcher's Tweaks agent panel: a compact usage header (the agent, its
// plan, and the session/weekly limits side by side) over a real terminal running the default
// agent (Settings > Apps > Agent), so it's the agent's own interface with every command. The
// terminal is AgentTerminal's, which outlives the dashboard; the tab borrows it while shown.
// Restart starts a fresh session (Start, once the agent has exited).
Item {
    id: root

    required property ScreenState screenState

    readonly property bool shown: screenState.dashboard && screenState.agentTabActive

    readonly property bool running: AgentTerminal.running
    // The header follows the agent the running session started with until a restart
    readonly property string agent: running && AgentTerminal.sessionAgent ? AgentTerminal.sessionAgent : Agents.defaultAgent
    readonly property Item terminal: AgentTerminal.terminal
    readonly property var usage: Agents.records[agent] ?? null
    readonly property var limits: limitWindows(usage)

    property double nowMs: Date.now()

    // ---------------------------------------------------------------- limits
    // Claude spells its windows out, Codex abbreviates them; both land on { title, percent, resetAt }

    function windowIsLong(text: string): bool {
        return ["week", "7-day", "seven", "month", "30-day"].some(w => text.includes(w));
    }

    function windowTitle(label: string): string {
        const text = (label ?? "").toLowerCase();
        if (text.includes("month"))
            return Tr.tr("Monthly");
        if (windowIsLong(text))
            return Tr.tr("Weekly");
        if (text.includes("session") || /(\d+)\s*-?\s*(h(our)?|m(in(ute)?s?)?)\b/.test(text))
            return Tr.tr("Session");
        const plain = (label ?? "").replace(/\s*\(.*\)\s*/, "").trim();
        return plain || Tr.tr("Limit");
    }

    function limitWindows(u: var): var {
        return (u?.limits ?? []).filter(l => Number(l?.percent) >= 0).map(l => ({
                    title: l.title || windowTitle(l.label),
                    percent: Number(l.percent),
                    resetAt: l.resetsAt ?? ""
                }));
    }

    function formatDuration(ms: real): string {
        if (!(ms > 0))
            return Tr.tr("now");
        const minutes = Math.floor(ms / 60000);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        if (days > 0)
            return `${days}d ${hours % 24}h`;
        if (hours > 0)
            return `${hours}h ${minutes % 60}m`;
        return `${Math.max(1, minutes)}m`;
    }

    function resetText(w: var): string {
        const at = new Date(w?.resetAt ?? "").getTime();
        return isFinite(at) && at > nowMs ? Tr.tr("Resets in %1").arg(formatDuration(at - nowMs)) : "";
    }

    function planText(u: var): string {
        if (u?.usageStatusText)
            return u.usageStatusText;
        const tier = u?.tierLabel ?? "";
        return tier ? tier.charAt(0).toUpperCase() + tier.slice(1) : "";
    }

    // Take the terminal into this tab's frame
    function adopt(): void {
        if (!shown || !terminal || terminal.parent === terminalFrame)
            return;
        terminal.parent = terminalFrame;
        terminal.anchors.fill = terminalFrame;
        terminal.forceActiveFocus();
        Qt.callLater(root.repaint);
    }

    // Its picture is only brought up to date when the agent prints: bring it up to date now, so
    // an idle agent's screen shows straight away (qmltermwidget-taris repaints all of it in
    // the new window, rather than only what changed)
    function repaint(): void {
        if (!terminal || terminal.parent !== terminalFrame)
            return;
        if (typeof terminal.updateImage === "function")
            terminal.updateImage();
        terminal.update();
    }

    // Hand it back before this tab goes, at the size it had, so the agent's screen doesn't reflow
    function release(): void {
        if (!terminal || terminal.parent !== terminalFrame)
            return;
        const w = terminal.width;
        const h = terminal.height;
        terminal.anchors.fill = undefined;
        terminal.parent = null;
        terminal.width = w;
        terminal.height = h;
    }

    implicitWidth: 760
    implicitHeight: 460

    onShownChanged: {
        if (shown) {
            nowMs = Date.now();
            Agents.refreshLimits();
            AgentTerminal.start();
            adopt();
        }
    }
    onTerminalChanged: adopt()
    Component.onDestruction: release()

    Timer {
        interval: 30000
        running: root.shown
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // ---------- Header: mark · agent · plan ············ restart ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Image {
                id: mark

                readonly property real size: Tokens.font.icon.large.pointSize * 1.6

                visible: !!source.toString() && status === Image.Ready
                Layout.preferredWidth: size
                Layout.preferredHeight: size
                source: Agents.iconOf(root.agent)
                sourceSize: Qt.size(size * 2, size * 2)
                fillMode: Image.PreserveAspectFit
            }

            MaterialIcon {
                visible: !mark.visible
                text: "smart_toy"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font: Tokens.font.title.small
                text: {
                    const name = root.usage?.name || Agents.nameOf(root.agent);
                    if (!root.usage)
                        return root.agent ? `${name}  ·  ${Tr.tr("Usage not tracked")}` : Tr.tr("No default agent");
                    const plan = root.planText(root.usage);
                    return plan ? `${name}  ·  ${plan}` : name;
                }
            }

            IconTextButton {
                icon: root.running ? "restart_alt" : "play_arrow"
                text: root.running ? Tr.tr("Restart") : Tr.tr("Start")
                inactiveColour: Colours.palette.m3secondaryContainer
                inactiveOnColour: Colours.palette.m3onSecondaryContainer
                verticalPadding: Tokens.padding.extraSmall
                onClicked: AgentTerminal.restart()
            }
        }

        // ---------- Limits, side by side ----------
        RowLayout {
            Layout.fillWidth: true
            visible: root.limits.length > 0
            spacing: Tokens.spacing.large

            Repeater {
                model: root.limits

                ColumnLayout {
                    id: cell

                    required property var modelData
                    readonly property bool alarming: modelData.percent >= 0.9

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: cell.modelData.title
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: `${Math.round(cell.modelData.percent * 100)}%`
                            font: Tokens.font.label.medium
                            color: cell.alarming ? Colours.palette.m3error : Colours.palette.m3onSurface
                        }
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        implicitHeight: Tokens.padding.small
                        value: Math.max(0, Math.min(1, cell.modelData.percent))
                        fgColour: cell.alarming ? Colours.palette.m3error : Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.resetText(cell.modelData)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3outline
                        elide: Text.ElideRight
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        // ---------- The agent's own terminal interface ----------
        StyledClippingRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLowest

            // AgentTerminal's terminal goes in here while the tab is shown
            Item {
                id: terminalFrame

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium

            }

            StyledText {
                visible: !root.running
                anchors.centerIn: parent
                width: parent.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Tr.tr("The agent exited. Press Start to open a new session.")
                color: Colours.palette.m3outline
            }
        }
    }
}

// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import QMLTermWidget
import qs.components
import qs.utils

// The Agent tab's terminal, running the default agent through assets/agent/launch.sh. It lives as
// long as the shell: the dashboard unloads its content whenever it closes, and a terminal there
// would hang up the agent (and anything it started, like a sign-in browser) every time. The tab
// borrows the terminal while it's on screen.
Singleton {
    id: root

    readonly property Item terminal: loader.item
    property bool running
    // The agent the running session started with
    property string sessionAgent

    // Starts the session the first time the tab is shown
    function start(): void {
        wanted = true;
    }

    function restart(): void {
        wanted = true;
        loader.active = false;
        loader.active = Qt.binding(() => root.wanted && root.schemeReady);
    }

    property bool wanted
    property bool schemeReady

    // The terminal's colours, from Taris's scheme. QMLTermWidget only reads schemes from its own
    // folder, so install.sh links this file there as Taris.colorscheme. It looks schemes up once,
    // so the terminal starts only once the file is written, and new colours apply when the shell
    // restarts.
    FileView {
        readonly property string scheme: {
            const p = Colours.palette;
            const rgb = c => `${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)}`;
            let out = `[General]\nDescription=Taris\nOpacity=1\n\n`;
            out += `[Background]\nColor=${rgb(p.m3surfaceContainerLowest)}\n\n[BackgroundIntense]\nColor=${rgb(p.m3surfaceContainerLowest)}\n\n`;
            out += `[Foreground]\nColor=${rgb(p.m3onSurface)}\n\n[ForegroundIntense]\nColor=${rgb(p.m3onSurface)}\n\n`;
            for (let i = 0; i < 8; i++)
                out += `[Color${i}]\nColor=${rgb(p[`term${i}`])}\n\n[Color${i}Intense]\nColor=${rgb(p[`term${i + 8}`])}\n\n`;
            return out;
        }

        path: `${Paths.state}/agent-terminal.colorscheme`
        printErrors: false
        onSchemeChanged: setText(scheme)
        onSaved: root.schemeReady = true
        onSaveFailed: root.schemeReady = true
        Component.onCompleted: setText(scheme)
    }

    Loader {
        id: loader

        active: root.wanted && root.schemeReady

        sourceComponent: QMLTermWidget {
            id: terminal

            // Kept while no tab holds it, so the agent's screen doesn't reflow to nothing
            width: 700
            height: 360

            font.family: "CaskaydiaCove NF"
            // Same size as the Witcher's Tweaks agent terminal
            font.pixelSize: 12
            colorScheme: "Taris"
            // A blink redraws the shell's whole screen twice a second (agents draw their own
            // cursor anyway)
            blinkingCursor: false
            enableBold: true
            antialiasText: true
            smooth: true
            focus: true

            session: QMLTermSession {
                id: agentSession

                initialWorkingDirectory: Quickshell.env("HOME")
                shellProgram: `${Agents.scriptDir}/launch.sh`
                shellProgramArgs: [Agents.defaultAgent]
                onFinished: {
                    root.running = false;
                    root.sessionAgent = "";
                }
            }

            Component.onCompleted: {
                root.sessionAgent = Agents.defaultAgent;
                agentSession.startShellProgram();
                root.running = true;
            }

            // The terminal renders scrollback itself; the wheel scrolls it
            QMLTermScrollbar {
                terminal: terminal
                width: 6

                StyledRect {
                    anchors.fill: parent
                    radius: width / 2
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.35
                }
            }
        }
    }
}

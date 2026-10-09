// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import Taris.Config
import qs.components
import qs.components.controls
import qs.services

// Close, minimize and restore for the active window, shown in the bar while it's
// maximized or fullscreen. Minimized windows wait in special:minimized; the dock restores them.
StyledRect {
    id: root

    readonly property var win: Hypr.activeToplevel
    readonly property bool shown: !!win && (Hypr.focusedWorkspace?.hasFullscreen ?? false)
    readonly property string addr: win ? `address:0x${win.address}` : ""

    function run(lua: string, legacy: string): void {
        Hypr.dispatch(Hypr.usingLua ? lua : legacy);
    }

    implicitWidth: column.implicitWidth + Tokens.padding.small * 2
    implicitHeight: shown ? column.implicitHeight + Tokens.padding.small * 2 : 0
    opacity: shown ? 1 : 0
    clip: true
    radius: Tokens.rounding.full
    color: Colours.tPalette.m3surfaceContainer

    Behavior on implicitHeight {
        Anim {}
    }
    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Column {
        id: column

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        IconButton {
            icon: "close"
            type: IconButton.Tonal
            isRound: true
            onClicked: root.run(`hl.dsp.window.close({ window = "${root.addr}" })`, `closewindow ${root.addr}`)
        }

        IconButton {
            icon: "minimize"
            type: IconButton.Text
            isRound: true
            onClicked: root.run(`hl.dsp.window.move({ window = "${root.addr}", workspace = "special:minimized", follow = false })`, `movetoworkspacesilent special:minimized,${root.addr}`)
        }

        IconButton {
            icon: "fullscreen_exit"
            type: IconButton.Text
            isRound: true
            onClicked: root.run(`hl.dsp.window.fullscreen({ mode = "maximized" })`, "fullscreen 1")
        }
    }
}

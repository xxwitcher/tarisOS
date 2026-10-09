// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import Taris.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

// The taskbar's launcher button: the logo (Taris's or the distro's), or a Material symbol when
// general.logo is "symbol:<name>" (Settings > Panels > Taskbar)
Item {
    id: root

    readonly property string symbol: (GlobalConfig.general.logo ?? "").startsWith("symbol:") ? GlobalConfig.general.logo.slice(7) : ""

    implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.2)
    implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.2)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const screenState = ShellState.forActive();
            screenState.launcher = !screenState.launcher;
        }
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent
        sourceComponent: root.symbol ? symbolIcon : SysInfo.isDefaultLogo ? tarisLogo : distroIcon
    }

    Component {
        id: symbolIcon

        MaterialIcon {
            text: root.symbol
            color: Colours.palette.m3tertiary
            fontStyle: Tokens.font.icon.medium
        }
    }

    Component {
        id: tarisLogo

        Logo {
            implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.6)
            implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.6)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(Tokens.font.body.large.pointSize * 1.2)
            colour: Colours.palette.m3tertiary
        }
    }
}

// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Taris.Config
import Taris.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Taskbar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Behaviour
        SectionHeader {
            first: true
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Persistent")
            subtext: Tr.tr("Keep the bar visible at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal the bar when the cursor reaches the screen edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the bar reveals")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // The launcher button at the top
        SectionHeader {
            text: Tr.tr("Launcher button")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Show the launcher button")
            subtext: Tr.tr("At the top of the taskbar; opens the app launcher")
            checked: Config.bar.entries.values.find(e => e.id === "logo")?.enabled ?? false
            onToggled: {
                const e = GlobalConfig.bar.entries.values.find(e => e.id === "logo");
                if (e)
                    e.enabled = checked;
            }
        }

        ChoiceRow {
            last: true
            icon: "apps"
            label: Tr.tr("Icon")
            options: [
                {
                    value: "",
                    label: Tr.tr("Distro logo")
                },
                {
                    value: "taris",
                    label: Tr.tr("Logo")
                },
                {
                    value: "symbol:apps",
                    label: Tr.tr("Apps grid")
                },
                {
                    value: "symbol:grid_view",
                    label: Tr.tr("Tiles")
                },
                {
                    value: "symbol:widgets",
                    label: Tr.tr("Widgets")
                },
                {
                    value: "symbol:rocket_launch",
                    label: Tr.tr("Rocket")
                },
                {
                    value: "symbol:search",
                    label: Tr.tr("Search")
                },
                {
                    value: "symbol:menu",
                    label: Tr.tr("Menu")
                },
                {
                    value: "symbol:blur_on",
                    label: Tr.tr("Dots")
                },
                {
                    value: "symbol:star",
                    label: Tr.tr("Star")
                }
            ]
            current: GlobalConfig.general.logo ?? ""
            onChosen: v => GlobalConfig.general.logo = v
        }

        // Components
        SectionHeader {
            text: Tr.tr("Components")
        }

        NavRow {
            first: true
            icon: "workspaces"
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "web_asset"
            text: Tr.tr("Active window")
            subtext: Tr.tr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "widgets"
            text: Tr.tr("Tray")
            subtext: Tr.tr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            text: Tr.tr("Status icons")
            subtext: Tr.tr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            last: true
            icon: "schedule"
            text: Tr.tr("Clock")
            subtext: Tr.tr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        // Scroll actions
        SectionHeader {
            text: Tr.tr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Scroll over the workspace indicator to switch workspaces")
            checked: Config.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: Tr.tr("Volume")
            subtext: Tr.tr("Scroll on the top half of the bar to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Brightness")
            subtext: Tr.tr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }
    }
}

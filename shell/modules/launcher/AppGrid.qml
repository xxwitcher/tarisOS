// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Taris.Config
import Taris.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.services
import qs.utils

// App drawer: apps as a grid of icons, filtered by the search text. Drag one to the dock to pin it.
// Right click for its menu, as in the Witcher's Tweaks app drawer: Open, Keep in Dock, Open at
// Login and Remove… (asks first, then uninstalls it: Installer.remove).
GridView {
    id: root

    required property var search
    required property ScreenState screenState
    readonly property int columns: 6
    readonly property int rows: Math.min(4, Math.ceil(count / columns))
    // The open menu's rows: { label, icon, action }
    property var menuRows: []

    function launch(entry: DesktopEntry): void {
        Apps.launch(entry);
        root.screenState.launcher = false;
    }

    function openMenu(cell: Item, entry: DesktopEntry): void {
        const pinned = Dock.isPinned(entry.id);
        const atLogin = Dock.opensAtLogin(entry);
        menuRows = [
            {
                label: Tr.tr("Open"),
                icon: "open_in_new",
                action: () => root.launch(entry)
            },
            {
                label: Tr.tr("Keep in Dock"),
                icon: pinned ? "check_box" : "check_box_outline_blank",
                action: () => Dock.togglePin(entry.id)
            },
            {
                label: Tr.tr("Open at Login"),
                icon: atLogin ? "check_box" : "check_box_outline_blank",
                action: () => Dock.setOpensAtLogin(entry, !atLogin)
            },
            {
                label: Tr.tr("Remove…"),
                icon: "delete",
                // Once this menu has closed, it opens again to ask
                action: () => Qt.callLater(() => root.askRemove(entry))
            }
        ];
        Dock.refreshAutostart();

        // Opens over the grid, towards its middle, so it stays on the drawer
        const p = cell.mapToItem(root, 0, 0);
        const left = p.x + cell.width / 2 < root.width / 2;
        const down = p.y + cell.height / 2 < root.height / 2;
        appMenu.attachTo = cell;
        appMenu.attachSideX = left ? Menu.Left : Menu.Right;
        appMenu.thisSideX = appMenu.attachSideX;
        appMenu.attachSideY = down ? Menu.Bottom : Menu.Top;
        appMenu.thisSideY = down ? Menu.Top : Menu.Bottom;
        appMenu.expanded = true;
    }

    function askRemove(entry: DesktopEntry): void {
        menuRows = [
            {
                label: Tr.tr("Remove %1").arg(entry.name),
                icon: "delete_forever",
                action: () => {
                    // A stand-in is only hidden: uninstalling its entry would remove taris-desktop
                    if (OnDemand.isPlaceholder(entry)) {
                        Dock.removeStandIn(entry);
                    } else {
                        Installer.remove(entry);
                        root.screenState.launcher = false;
                    }
                }
            },
            {
                label: Tr.tr("Cancel"),
                icon: "close",
                action: () => {}
            }
        ];
        appMenu.expanded = true;
    }

    model: ScriptModel {
        values: Apps.search(root.search.text)
        onValuesChanged: root.currentIndex = 0
    }

    clip: true
    cellWidth: width / columns
    cellHeight: Math.round(cellWidth * 1.05)
    implicitHeight: cellHeight * rows
    keyNavigationWraps: true
    highlightFollowsCurrentItem: false
    // Keeps every app's tile around once made (as the settings pages keep their rows), so a glide
    // never stalls building tiles and loading their icons as rows scroll into view
    cacheBuffer: 100000

    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08
        x: root.currentItem?.x ?? 0
        y: root.currentItem?.y ?? 0
        implicitWidth: root.cellWidth
        implicitHeight: root.cellHeight

        Behavior on x {
            Anim {}
        }
        Behavior on y {
            Anim {}
        }
    }

    delegate: Item {
        id: app

        required property DesktopEntry modelData
        required property int index

        implicitWidth: root.cellWidth
        implicitHeight: root.cellHeight
        // An app installed on first use, not installed yet
        opacity: OnDemand.isPlaceholder(modelData) ? 0.5 : 1

        // Dragged to the dock (at the bottom of the drawer) to pin the app there
        AppDragLayer {
            entry: app.modelData
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            radius: Tokens.rounding.large
            onActivated: event => {
                if (event.button === Qt.RightButton)
                    root.openMenu(app, app.modelData);
                else
                    root.launch(app.modelData);
            }
        }

        IconImage {
            id: icon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.medium
            implicitSize: Math.round(root.cellWidth * 0.5)
            asynchronous: true
            source: Quickshell.iconPath(app.modelData.icon, "image-missing")
        }

        StyledText {
            anchors.top: icon.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: app.modelData.name
            font: Tokens.font.label.medium
        }
    }

    Variants {
        id: menuItems

        model: root.menuRows

        MenuItem {
            required property var modelData

            text: modelData.label
            icon: modelData.icon
            onClicked: modelData.action()
        }
    }

    Menu {
        id: appMenu

        attachTo: root
        items: menuItems.instances
        active: null
    }

    // Momentum scrolling for wheels and touchpads
    Glide {
        flickable: root
    }
}

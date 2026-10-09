// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

import "navpane"
import QtQuick
import QtQuick.Layouts
import Taris.Config
import Taris.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    SearchBar {
        id: searchField

        Layout.fillWidth: true

        placeholderText: Tr.tr("Search settings")
        font: Tokens.font.body.large

        bg.color: Colours.tPalette.m3surfaceContainerLowest
        bg.border.color: Colours.palette.m3outlineVariant
        searchIcon.fontStyle: Tokens.font.icon.medium
        searchIcon.anchors.leftMargin: Tokens.padding.largeIncreased
        clearIcon.font: Tokens.font.icon.medium
        clearIcon.padding: Tokens.padding.extraSmall

        // Enter opens the first page found
        onAccepted: {
            const first = PageRegistry.pages.findIndex(p => PageRegistry.matches(p, text));
            if (first >= 0) {
                root.nState.currentPageIdx = first;
                text = "";
            }
        }

        Behavior on bg.border.color {
            CAnim {}
        }

        Binding {
            target: root.nState
            property: "searchOpen"
            value: searchField.text.length > 0
        }

        Binding {
            target: root.nState
            property: "searchText"
            value: searchField.text.trim()
        }
    }

    NavLocations {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        Layout.bottomMargin: -bottomMargin
        nState: root.nState
    }
}

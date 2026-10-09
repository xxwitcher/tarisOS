// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

import "center"
import QtQuick
import QtQuick.Layouts
import Taris.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: Tokens.spacing.largeIncreased

    Clock {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.padding.large
        centerScale: root.centerScale
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter

        text: Time.format("dddd • d MMM").toUpperCase()
        color: Colours.palette.m3onSurface
        font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
    }

    ProfilePic {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.extraExtraLarge * root.centerScale
        Layout.bottomMargin: (root.lock.pam.greeter ? Tokens.spacing.large : Tokens.spacing.extraLarge) * root.centerScale
        centerWidth: root.centerWidth
        path: root.lock.pam.facePath
    }

    // The greeter: whose account it is, with arrows to the others
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Tokens.spacing.large * root.centerScale
        visible: root.lock.pam.greeter
        spacing: Tokens.spacing.small

        IconButton {
            visible: root.lock.pam.users.length > 1
            type: IconButton.Text
            icon: "chevron_left"
            disabled: root.lock.pam.busy
            onClicked: root.lock.pam.switchUser(-1)
        }

        StyledText {
            text: root.lock.pam.userRealName
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
        }

        IconButton {
            visible: root.lock.pam.users.length > 1
            type: IconButton.Text
            icon: "chevron_right"
            disabled: root.lock.pam.busy
            onClicked: root.lock.pam.switchUser(1)
        }
    }

    PasswordInput {
        Layout.alignment: Qt.AlignHCenter
        centerScale: Math.max(0.8, root.centerScale)
        centerWidth: root.centerWidth
        lock: root.lock
    }

    StateMessage {
        Layout.fillWidth: true
        pam: root.lock.pam
    }
}

// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QMLTermWidget
import Taris.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.modules.nexus
import qs.modules.store
import qs.modules.windowinfo

Item {
    id: root

    required property ShellScreen screen
    required property real offsetScale

    readonly property alias content: content
    readonly property alias winfo: winfo
    readonly property alias nexus: nexus

    readonly property real nonAnimWidth: children.find(c => c.shouldBeActive)?.implicitWidth ?? content.implicitWidth
    readonly property real nonAnimHeight: children.find(c => c.shouldBeActive)?.implicitHeight ?? content.implicitHeight
    readonly property Item current: (content.item as Content)?.current ?? null
    readonly property bool isDetached: detachedMode.length > 0

    property alias currentName: popoutState.currentName
    property alias hasCurrent: popoutState.hasCurrent
    property alias held: popoutState.held
    property real currentCenter

    property string detachedMode
    property string queuedMode
    // A FileDialog shown here (detachedMode "file"), and what was showing before it (the settings,
    // when it was opened from them), which comes back when it's done
    property var fileDialog: null
    property string modeBeforeFile
    // A command run in a terminal here (detachedMode "terminal": the app drawer's Remove…), and its
    // title; it closes when the command ends
    property string terminalCommand
    property string terminalTitle

    // Dummy object so Tokens attached prop resolves to global config
    // Anim configs are not per-monitor
    readonly property QtObject dummy: QtObject {}
    property int animLength: dummy.Tokens.anim.durations.expressiveDefaultSpatial
    property var animCurve: dummy.Tokens.anim.expressiveDefaultSpatial // The easingCurve type is Qt 6.11+ so we gotta use var for now

    function setAnims(detach: bool): void {
        const type = `expressive${detach ? "Slow" : "Default"}Spatial`;
        animLength = dummy.Tokens.anim.durations[type];
        animCurve = dummy.Tokens.anim[type];
    }

    function detach(mode: string): void {
        setAnims(true);
        if (mode === "winfo" || mode === "store") {
            detachedMode = mode;
        } else {
            queuedMode = mode;
            detachedMode = "any";
        }
        setAnims(false);
        focus = true;
    }

    // reason: what closed it, logged while the settings overlay is open (to find what closes it)
    function close(reason: string): void {
        if (isDetached)
            console.info(`Detached popout (${detachedMode}) closed: ${reason || "unknown"}`);
        const dialog = detachedMode === "file" ? fileDialog : null;
        fileDialog = null;
        modeBeforeFile = "";
        hasCurrent = false;
        detachedMode = "";
        dialog?.rejected(); // Closing the overlay cancels the pick
    }

    function showTerminal(title: string, command: string): void {
        terminalTitle = title;
        terminalCommand = command;
        setAnims(true);
        detachedMode = "terminal";
        setAnims(false);
        focus = true;
    }

    function showFileDialog(dialog: var): void {
        if (fileDialog && fileDialog !== dialog)
            fileDialog.rejected();
        if (detachedMode !== "file")
            modeBeforeFile = detachedMode;
        fileDialog = dialog;
        setAnims(true);
        detachedMode = "file";
        setAnims(false);
        focus = true;
    }

    // The dialog picked or was cancelled: back to what was showing before it
    function closeFileDialog(dialog: var): void {
        if (fileDialog !== dialog)
            return;
        fileDialog = null;
        if (detachedMode === "file") {
            detachedMode = modeBeforeFile;
            if (!detachedMode)
                hasCurrent = false;
        }
        modeBeforeFile = "";
    }

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    focus: hasCurrent
    Keys.onEscapePressed: {
        // Forward escape to password popout if active, otherwise close
        if (currentName === "wirelesspassword" && content.item) {
            const passwordPopout = (content.item as Content)?.children.find(c => c.name === "wirelesspassword");
            if (passwordPopout && passwordPopout.item) {
                passwordPopout.item.closeDialog();
                return;
            }
        }
        close("escape");
    }

    Keys.onPressed: event => {
        // Don't intercept keys when password popout is active - let it handle them
        if (currentName === "wirelesspassword") {
            event.accepted = false;
        }
    }

    PopoutState {
        id: popoutState

        onDetachRequested: mode => root.detach(mode)
    }

    HyprlandFocusGrab {
        id: detachedGrab

        // Briefly off to take the grab again when it's dropped without the user clicking away: after
        // a reload the shell asked for (Window style changes), or while the pointer is on the
        // overlay itself (clicking its colour picker drops it)
        property bool regrabbing

        // Off while a password prompt is up (ShellState.authenticating): it gets the clicks and the
        // keyboard, and the overlay stays open under it
        active: root.isDetached && !regrabbing && !ShellState.authenticating
        windows: [QsWindow.window]
        onCleared: {
            if (Hypr.reloading() || detachedHover.hovered || fileDialogHover.hovered || terminalHover.hovered || storeHover.hovered) {
                regrabbing = true;
                Qt.callLater(() => regrabbing = false);
            } else {
                root.close("focus grab cleared");
            }
        }
    }

    Binding {
        when: root.isDetached || (root.hasCurrent && root.currentName === "wirelesspassword")

        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }

    Comp {
        id: content

        shouldBeActive: root.hasCurrent && !root.detachedMode
        anchors.fill: parent

        sourceComponent: Content {
            popouts: popoutState
        }
    }

    Comp {
        id: winfo

        shouldBeActive: root.detachedMode === "winfo"
        anchors.centerIn: parent

        sourceComponent: WindowInfo {
            screen: root.screen
            client: Hypr.activeToplevel
        }
    }

    Comp {
        id: terminalComp

        shouldBeActive: root.detachedMode === "terminal"
        anchors.centerIn: parent

        sourceComponent: StyledClippingRect {
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainerLowest
            implicitWidth: 760
            implicitHeight: 420

            StyledText {
                id: titleText

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Tokens.padding.large
                text: root.terminalTitle
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            QMLTermWidget {
                id: terminal

                anchors.top: titleText.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.large

                font.family: "CaskaydiaCove NF"
                font.pixelSize: 13
                colorScheme: "Taris"
                blinkingCursor: true
                enableBold: true
                antialiasText: true
                smooth: true
                focus: true

                session: QMLTermSession {
                    id: terminalSession

                    initialWorkingDirectory: Quickshell.env("HOME")
                    shellProgram: "bash"
                    shellProgramArgs: ["-c", `${root.terminalCommand}; printf '\\nDone. Press Enter to close.'; read -r`]
                    onFinished: root.close("terminal finished")
                }

                Component.onCompleted: {
                    terminalSession.startShellProgram();
                    forceActiveFocus();
                }
            }
        }

        HoverHandler {
            id: terminalHover
        }
    }

    Comp {
        id: fileDialogComp

        shouldBeActive: root.detachedMode === "file"
        anchors.centerIn: parent

        sourceComponent: StyledClippingRect {
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surface
            implicitWidth: Math.min(1000, (QsWindow.window as QsWindow)?.width * 0.8 || 1000)
            implicitHeight: Math.min(600, (QsWindow.window as QsWindow)?.height * 0.8 || 600)

            DialogContent {
                anchors.fill: parent
                loader: root.fileDialog
            }
        }

        HoverHandler {
            id: fileDialogHover
        }
    }

    Comp {
        id: nexus

        shouldBeActive: root.detachedMode === "any"
        anchors.centerIn: parent

        sourceComponent: StyledClippingRect {
            radius: Tokens.rounding.extraLarge
            implicitWidth: nexusInner.implicitWidth
            implicitHeight: nexusInner.implicitHeight

            Nexus {
                id: nexusInner

                anchors.fill: parent
                nState.screen: root.screen
                nState.animatingContainer: nexus.opacity < 1
                // The page whose id is the mode ("bluetooth", "audio"...), else the default one
                nState.currentPageIdx: PageRegistry.indexOf(root.queuedMode)
                onClose: root.close("closed from settings")
                Component.onDestruction: console.info(`Detached settings destroyed (detachedMode "${root.detachedMode}")`)
            }
        }

        HoverHandler {
            id: detachedHover
        }
    }

    // The Store (modules/store), the same way: its corner button turns it into a window
    Comp {
        id: store

        shouldBeActive: root.detachedMode === "store"
        anchors.centerIn: parent

        sourceComponent: StyledClippingRect {
            radius: Tokens.rounding.extraLarge
            implicitWidth: storeInner.implicitWidth
            implicitHeight: storeInner.implicitHeight

            Store {
                id: storeInner

                anchors.fill: parent
                sState.screen: root.screen
                sState.animatingContainer: store.opacity < 1
                onClose: root.close("closed from the Store")
            }
        }

        HoverHandler {
            id: storeHover
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.offsetScale < 1

        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }

    component Comp: Loader {
        id: comp

        property bool shouldBeActive

        active: false
        opacity: 0

        // Makes the loader load on the same frame shouldBeActive becomes true, which ensures size is set
        states: State {
            name: "active"
            when: comp.shouldBeActive

            PropertyChanges {
                comp.opacity: 1
                comp.active: true
            }
        }

        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }
}

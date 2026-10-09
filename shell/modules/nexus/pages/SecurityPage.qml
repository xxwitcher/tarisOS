// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Taris.Config
import Taris.I18n
import qs.components
import qs.modules.nexus.common

// Security: lock screen behaviour, fingerprint unlock (enrolment in a terminal) and password
PageBase {
    id: root

    property bool hasFprint
    property list<string> fingers: []

    function inTerminal(cmd: string): void {
        Quickshell.execDetached(["sh", "-c", `exec ${GlobalConfig.general.apps.terminal.join(" ")} -e sh -c '${cmd}; echo; read -p "Press Enter to close" _'`]);
    }

    title: Tr.tr("Security")

    // Remote login: whether sshd is installed, and running
    property bool hasSshd
    property bool sshd

    // Disk encryption (/usr/lib/taris/encrypt): plain, pending (at the next restart), encrypted or
    // unsupported (not a TarisOS disk layout)
    property string encryption
    property bool encryptOpen
    property string encryptError
    // The disk: the partition the root is on (for changing its password)
    property string encryptedPartition

    // Factory reset: the system as installed is there to go back to (TarisOS images); armed
    // after the first click, the second erases
    property bool hasFactory
    property bool resetArmed

    property Process _encryptionGet: Process {
        id: encryptionGet

        running: true
        command: ["sh", "-c", "[ -x /usr/lib/taris/encrypt ] && /usr/lib/taris/encrypt status; lsblk -n -s -o PATH,TYPE \"$(findmnt -n -o SOURCE / | sed 's/\\[.*//')\" | awk '$2 == \"part\" { print \"part \" $1; exit }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l);
                root.encryption = lines.find(l => !l.startsWith("part ")) ?? "unsupported";
                root.encryptedPartition = (lines.find(l => l.startsWith("part ")) ?? "").slice(5);
            }
        }
    }

    // Encrypting: the password checked (it's the keyring's), the system marked and made ready (as
    // root), the keyring's own password removed (the disk password is the login from then on), then
    // the restart that encrypts
    property Process _keyringCheck: Process {
        id: keyringCheck

        command: ["/usr/lib/taris/keyring-unprotect", "--check"]
        stdinEnabled: true
        stderr: StdioCollector {
            id: keyringCheckErr
        }
        onStarted: {
            write(encryptPassword.field.text);
            stdinEnabled = false;
        }
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code === 0)
                encryptPrepare.running = true;
            else
                root.encryptError = keyringCheckErr.text.trim().split("\n").pop() || Tr.tr("Wrong password");
        }
    }

    property Process _encryptPrepare: Process {
        id: encryptPrepare

        command: ["pkexec", "/usr/lib/taris/encrypt", "prepare"]
        stderr: StdioCollector {
            id: encryptPrepareErr
        }
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code === 0) {
                keyringUnprotect.running = true;
            } else {
                root.encryptError = encryptPrepareErr.text.trim().split("\n").pop() || Tr.tr("Encryption couldn't be set up");
                encryptionGet.running = true;
            }
        }
    }

    property Process _keyringUnprotect: Process {
        id: keyringUnprotect

        command: ["/usr/lib/taris/keyring-unprotect"]
        stdinEnabled: true
        onStarted: {
            write(encryptPassword.field.text);
            stdinEnabled = false;
        }
        onExited: {
            encryptPassword.field.text = "";
            root.encryption = "pending";
            Quickshell.execDetached(["systemctl", "reboot"]);
        }
    }

    property Process _factoryCheck: Process {
        running: true
        command: ["test", "-e", "/etc/taris/factory"]
        onExited: code => root.hasFactory = code === 0 // qmllint disable signal-handler-parameters
    }

    property Process _factoryReset: Process {
        id: factoryReset

        command: ["pkexec", "/usr/lib/taris/factory-reset"]
        onExited: root.resetArmed = false
    }

    property Timer _resetDisarm: Timer {
        id: resetDisarm

        interval: 5000
        onTriggered: root.resetArmed = false
    }

    property Process _sshdGet: Process {
        id: sshdGet

        running: true
        command: ["sh", "-c", "systemctl list-unit-files sshd.service --no-legend | grep -q . && echo installed; systemctl is-active --quiet sshd && echo active"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasSshd = text.includes("installed");
                root.sshd = text.includes("active");
            }
        }
    }

    property Process _sshdSet: Process {
        id: sshdSet

        onExited: sshdGet.running = true
    }

    property Process _process1: Process {
        running: true
        command: ["sh", "-c", "command -v fprintd-list >/dev/null && fprintd-list \"$USER\" 2>/dev/null | sed -n 's/^ *- #[0-9]*: //p'; command -v fprintd-list >/dev/null && echo __fprint__"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim());
                root.hasFprint = lines.includes("__fprint__");
                root.fingers = lines.filter(l => l !== "__fprint__");
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Lock screen")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Use the wallpaper as the lock screen background")
            checked: Config.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
        }

        ToggleRow {
            text: Tr.tr("Hide notifications on the lock screen")
            checked: Config.lock.hideNotifs
            onToggled: GlobalConfig.lock.hideNotifs = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Power buttons on the lock screen")
            subtext: Tr.tr("Shut down, restart and sleep without unlocking")
            checked: GlobalConfig.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
        }

        SectionHeader {
            text: Tr.tr("Fingerprint")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Unlock with fingerprint")
            subtext: root.hasFprint ? (root.fingers.length > 0 ? Tr.tr("Enrolled: %1").arg(root.fingers.join(", ")) : Tr.tr("No fingers enrolled yet")) : Tr.tr("Install fprintd to use a fingerprint reader")
            checked: GlobalConfig.lock.enableFprint
            onToggled: GlobalConfig.lock.enableFprint = checked
        }

        RowButton {
            last: true
            icon: "fingerprint"
            text: Tr.tr("Enrol a finger")
            disabled: !root.hasFprint
            onClicked: root.inTerminal("fprintd-enroll")
        }

        SectionHeader {
            visible: root.hasSshd
            text: Tr.tr("Access")
        }

        ToggleRow {
            visible: root.hasSshd
            first: true
            last: true
            text: Tr.tr("Remote login (SSH)")
            subtext: Tr.tr("Let other computers sign in to this one over the network")
            checked: root.sshd
            onToggled: {
                sshdSet.command = ["pkexec", "systemctl", checked ? "enable" : "disable", "--now", "sshd.service"];
                sshdSet.running = true;
            }
        }

        SectionHeader {
            visible: root.encryption !== "" && root.encryption !== "unsupported"
            text: Tr.tr("Disk encryption")
        }

        InfoRow {
            visible: root.encryption === "pending" || root.encryption === "encrypted"
            first: true
            last: root.encryption !== "encrypted"
            icon: root.encryption === "encrypted" ? "lock" : "lock_clock"
            label: root.encryption === "encrypted" ? Tr.tr("Encrypted") : Tr.tr("Encrypts at the next restart")
        }

        RowButton {
            visible: root.encryption === "encrypted" && root.encryptedPartition !== ""
            last: true
            icon: "key"
            text: Tr.tr("Change disk password")
            onClicked: root.inTerminal(`sudo cryptsetup luksChangeKey ${root.encryptedPartition}`)
        }

        RowButton {
            visible: root.encryption === "plain"
            first: true
            last: !root.encryptOpen
            icon: "enhanced_encryption"
            text: Tr.tr("Encrypt the disk")
            onClicked: root.encryptOpen = !root.encryptOpen
        }

        TextFieldRow {
            id: encryptPassword

            visible: root.encryption === "plain" && root.encryptOpen
            label: Tr.tr("User password")
            errorText: root.encryptError
            subtext: root.encryptError
            Component.onCompleted: field.echoMode = TextInput.Password
        }

        RowButton {
            visible: root.encryption === "plain" && root.encryptOpen
            last: true
            icon: "restart_alt"
            text: Tr.tr("Encrypt and restart")
            disabled: encryptPassword.field.text === "" || keyringCheck.running || encryptPrepare.running || keyringUnprotect.running
            onClicked: {
                root.encryptError = "";
                keyringCheck.stdinEnabled = true;
                keyringUnprotect.stdinEnabled = true;
                keyringCheck.running = true;
            }
        }

        SectionHeader {
            text: Tr.tr("Account")
        }

        RowButton {
            first: true
            last: true
            icon: "password"
            text: Tr.tr("Change password")
            onClicked: root.inTerminal("passwd")
        }

        SectionHeader {
            visible: root.hasFactory
            text: Tr.tr("Factory reset")
        }

        RowButton {
            visible: root.hasFactory
            first: true
            last: true
            icon: "restore"
            text: root.resetArmed ? Tr.tr("Click again to erase everything and restart") : Tr.tr("Erase everything")
            disabled: factoryReset.running
            onClicked: {
                if (root.resetArmed) {
                    resetDisarm.stop();
                    factoryReset.running = true;
                } else {
                    root.resetArmed = true;
                    resetDisarm.restart();
                }
            }
        }
    }
}

// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma Singleton

import Quickshell
import Quickshell.Io
import Taris.Config

// Pending updates for the Updates settings (the page in General and its full list share them):
// packages (checkupdates: Arch Linux ARM, Asahi, the TarisOS repository; yay's AUR ones) and
// Flatpak apps
Singleton {
    id: root

    property list<string> pending: []
    property bool checking

    function check(): void {
        checking = true;
        proc.running = true;
    }

    // Everything, in a terminal: TarisOS's update (/usr/lib/taris/update: packages, with a snapshot
    // first, then Flatpak apps), else yay or pacman
    function update(): void {
        Quickshell.execDetached(["sh", "-c", `exec ${GlobalConfig.general.apps.terminal.join(" ")} -e sh -c 'if [ -x /usr/lib/taris/update ]; then /usr/lib/taris/update; elif command -v yay >/dev/null; then yay -Syu; else sudo pacman -Syu; fi; echo; read -p "Done. Press Enter to close" _'`]);
    }

    Process {
        id: proc

        command: ["sh", "-c", "checkupdates 2>/dev/null; command -v yay >/dev/null && yay -Qua 2>/dev/null; command -v flatpak >/dev/null && flatpak remote-ls --system --updates --columns=application,version 2>/dev/null | tr '\\t' ' '; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pending = text.split("\n").filter(l => l.trim().length > 0);
                root.checking = false;
            }
        }
    }
}

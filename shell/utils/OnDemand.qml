// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma Singleton

import Quickshell

// Apps installed on first use (taris-desktop's taris-install-*.desktop entries, which install the
// app and open it): shown greyed out in the launcher and the dock until the app is installed, then
// the app's own entry takes their place
Singleton {
    // The stand-in's entry id -> the ids the installed app's entry can have (VS Code's arm64
    // package names it com.microsoft.VSCode, other builds code)
    readonly property var apps: ({
            "taris-install-code": ["com.microsoft.VSCode", "code", "visual-studio-code"]
        })

    function isPlaceholder(entry: var): bool {
        return !!entry && Object.prototype.hasOwnProperty.call(apps, entry.id);
    }

    // The installed app's entry for a stand-in's id (null until it's installed)
    function installedFor(id: string): var {
        DesktopEntries.applications.values; // Again when apps are installed or removed
        for (const real of apps[id] ?? []) {
            const entry = DesktopEntries.byId(real);
            if (entry)
                return entry;
        }
        return null;
    }

    function hidden(entry: var): bool {
        return isPlaceholder(entry) && installedFor(entry.id) !== null;
    }
}

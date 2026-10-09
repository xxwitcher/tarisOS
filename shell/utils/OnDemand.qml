// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma Singleton

import Quickshell

// Apps installed on first use (taris-desktop's taris-install-*.desktop entries, which install the
// app and open it): shown greyed out in the launcher and the dock until the app is installed, then
// the app's own entry takes their place
Singleton {
    // The stand-in's entry id -> the installed app's entry id
    readonly property var apps: ({
            "taris-install-code": "code"
        })

    function isPlaceholder(entry: var): bool {
        return !!entry && Object.prototype.hasOwnProperty.call(apps, entry.id);
    }

    // The installed app's entry for a stand-in's id (null until it's installed)
    function installedFor(id: string): var {
        const real = apps[id];
        return real ? DesktopEntries.byId(real) : null;
    }

    function hidden(entry: var): bool {
        return isPlaceholder(entry) && installedFor(entry.id) !== null;
    }
}

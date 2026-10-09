// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Window style (Settings > Window style): window-style.conf, key=value lines read by
// hypr-taris.lua; saving reloads Hyprland. With bordertheme on, the border takes its colours
// from the colour scheme (theme-border.conf, which Colours writes) instead of colors/inactive.
// With gradient off the border is one colour: solid (empty: the first of colors).
Singleton {
    id: root

    // A fresh install: one border colour, the scheme's accent, following scheme changes
    readonly property var defaults: ({
            gradient: "0",
            bordertheme: "1",
            colors: "c4b5fd a855f7 da70d6",
            solid: "",
            inactive: "5b3a7a",
            fade: "1",
            swipe: "1",
            titlebars: "1",
            borderresize: "1",
            roundingon: "1",
            rounding: "60",
            bordersize: "1",
            gapsin: "1",
            gapsout: "3",
            columns: "0",
            floatnew: "0"
        })
    property var style: Object.assign({}, defaults)

    function save(changes: var): void {
        style = Object.assign({}, style, changes);
        file.setText(Object.entries(style).map(([k, v]) => `${k}=${v}`).join("\n") + "\n");
        Hypr.reload();
    }

    FileView {
        id: file

        path: `${Paths.config}/window-style.conf`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const s = Object.assign({}, root.defaults);
            for (const line of text().split("\n")) {
                const m = line.match(/^\s*(\w+)\s*=\s*(.*?)\s*$/);
                if (m)
                    s[m[1]] = m[2];
            }
            root.style = s;
        }
    }
}

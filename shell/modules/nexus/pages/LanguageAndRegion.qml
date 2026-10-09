// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Taris
import Taris.Config
import Taris.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Time zone and network time (timedatectl)
    property list<string> zones: []
    property string zone
    property bool ntp

    // Weather location search (Open-Meteo's geocoding, as the weather service uses)
    property string placeQuery
    property list<var> placeResults: []

    function refreshTime(): void {
        timeGet.running = true;
    }

    function searchPlaces(): void {
        const query = placeQuery;
        if (query.length < 2) {
            placeResults = [];
            return;
        }
        const lang = Qt.locale().name.split("_")[0] || "en";
        Requests.get(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=6&language=${lang}&format=json`, text => {
            if (query !== root.placeQuery)
                return; // Typed on since
            try {
                root.placeResults = JSON.parse(text).results ?? [];
            } catch (e) {
                root.placeResults = [];
            }
        });
    }

    // Searches once typing pauses
    property Timer _placeTimer: Timer {
        id: placeTimer

        interval: 350
        onTriggered: root.searchPlaces()
    }

    property Process _process1: Process {
        running: true
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: root.zones = text.split("\n").filter(z => z)
        }
    }

    property Process _process2: Process {
        id: timeGet

        running: true
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.zone = text.match(/^Timezone=(.*)$/m)?.[1] ?? "";
                root.ntp = text.match(/^NTP=(.*)$/m)?.[1] === "yes";
            }
        }
    }

    property Process _process3: Process {
        id: timeSet

        onExited: root.refreshTime()
    }

    // Chinese, Japanese and Korean typing (/usr/lib/taris/input-method: installed when turned on)
    readonly property var inputMethods: [
        { id: "zh", engine: "fcitx5-chinese-addons", label: Tr.tr("Chinese (Pinyin)") },
        { id: "ja", engine: "fcitx5-mozc", label: Tr.tr("Japanese") },
        { id: "ko", engine: "fcitx5-hangul", label: Tr.tr("Korean") }
    ]
    property list<string> installedInputMethods: []

    function refreshInputMethods(): void {
        imGet.running = true;
    }

    property Process _imGet: Process {
        id: imGet

        running: true
        command: ["sh", "-c", "pacman -Qq fcitx5-chinese-addons fcitx5-mozc fcitx5-hangul 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: root.installedInputMethods = text.split("\n").filter(l => l)
        }
    }

    // In a terminal (pacman asks for the password there); the switches catch up when it closes
    property Process _imSet: Process {
        id: imSet

        onExited: root.refreshInputMethods()
    }

    // Temperature units (there must be one for each value of the TemperatureUnit enum)
    readonly property list<MenuItem> tempItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: TemperatureUnit.Auto
        },
        MenuItem {
            text: Tr.tr("°C")
            value: TemperatureUnit.Celsius
        },
        MenuItem {
            text: Tr.tr("°F")
            value: TemperatureUnit.Fahrenheit
        },
        MenuItem {
            text: Tr.tr("K")
            value: TemperatureUnit.Kelvin
        }
    ]

    // Data size units (there must be one for each value of the DataUnit enum)
    readonly property list<MenuItem> dataItems: [
        MenuItem {
            text: Tr.tr("Binary (KiB, MiB)")
            value: DataUnit.Binary
        },
        MenuItem {
            text: Tr.tr("Decimal (KB, MB)")
            value: DataUnit.Decimal
        }
    ]

    // Clock formats (there must be one for each value of the ClockFormat enum)
    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: ClockFormat.Auto
        },
        MenuItem {
            text: Tr.tr("12-hour")
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: Tr.tr("24-hour")
            value: ClockFormat.TwentyFourHour
        }
    ]

    title: Tr.tr("Language & region")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Language
        SectionHeader {
            first: true
            text: Tr.tr("Language")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("UI language")
            subtext: Tr.tr("The language used in the shell UI")
            active: menuItems.find(i => i.modelData === Tr.language) ?? autoLang
            onSelected: item => {
                Tr.language = item.modelData ?? ""; // qmllint disable missing-property
            }

            menuItems: [autoLang, ...langItems.instances]

            MenuItem {
                id: autoLang

                text: Tr.tr("Auto")
            }

            Variants {
                id: langItems

                model: Tr.supportedLanguages

                MenuItem {
                    required property string modelData

                    text: {
                        const locale = Qt.locale(modelData);
                        return locale.name === "C" ? modelData : locale.nativeLanguageName || locale.name;
                    }
                }
            }
        }

        // Typing in other scripts
        SectionHeader {
            text: Tr.tr("Input methods")
        }

        // (Made again whenever what's installed is read: each switch shows that, also after a
        // terminal that didn't do it)
        Repeater {
            model: root.inputMethods.map(m => Object.assign({}, m, {
                        installed: root.installedInputMethods.includes(m.engine)
                    }))

            ToggleRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.inputMethods.length - 1
                text: modelData.label
                checked: modelData.installed
                enabled: !imSet.running
                onToggled: {
                    imSet.command = ["sh", "-c", `exec ${GlobalConfig.general.apps.terminal.join(" ")} -e sh -c '/usr/lib/taris/input-method ${checked ? "add" : "remove"} ${modelData.id}; echo; read -p "Press Enter to close" _'`];
                    imSet.running = true;
                }

            }
        }

        // Weather
        SectionHeader {
            text: Tr.tr("Weather")
        }

        // Where the weather is for: a place found by name (its coordinates are kept), or the one
        // the network says (empty)
        TextFieldRow {
            id: placeSearch

            first: true
            label: Tr.tr("Location")
            subtext: GlobalConfig.services.weatherLocation ? (Weather.city || GlobalConfig.services.weatherLocation) : Tr.tr("Automatic") + (Weather.city ? ` (${Weather.city})` : "")
            placeholderText: Tr.tr("Search for a city")
            onValueEdited: v => {
                root.placeQuery = v.trim();
                placeTimer.restart();
            }
        }

        Repeater {
            model: root.placeResults

            RowButton {
                required property var modelData

                icon: "location_on"
                text: modelData.name
                subtext: [modelData.admin1, modelData.country].filter(p => p).join(", ")
                onClicked: {
                    GlobalConfig.services.weatherLocation = `${modelData.latitude},${modelData.longitude}`;
                    root.placeResults = [];
                    root.placeQuery = "";
                    placeSearch.clear();
                }
            }
        }

        RowButton {
            last: true
            visible: GlobalConfig.services.weatherLocation.length > 0
            icon: "my_location"
            text: Tr.tr("Automatic")
            onClicked: GlobalConfig.services.weatherLocation = ""
        }

        // Units
        SectionHeader {
            text: Tr.tr("Units")
        }

        SelectRow {
            first: true
            label: Tr.tr("Temperature")
            subtext: Tr.tr("Units for weather temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.weatherUnits)
            onSelected: item => GlobalConfig.services.weatherUnits = item.value
        }

        SelectRow {
            label: Tr.tr("System temperatures")
            subtext: Tr.tr("Units for CPU and GPU temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.sensorUnits)
            onSelected: item => GlobalConfig.services.sensorUnits = item.value
        }

        SelectRow {
            last: true
            label: Tr.tr("Data sizes")
            subtext: Tr.tr("Units for data sizes and network speeds")
            menuItems: root.dataItems
            active: root.dataItems.find(i => i.value === GlobalConfig.services.dataUnits)
            onSelected: item => GlobalConfig.services.dataUnits = item.value
        }

        // Time & date
        SectionHeader {
            text: Tr.tr("Time & date")
        }

        ChoiceRow {
            first: true
            icon: "schedule"
            label: Tr.tr("Time zone")
            options: root.zones.map(z => ({
                        value: z,
                        label: z.replace(/_/g, " ").replace(/\//g, " / ")
                    }))
            current: root.zone
            onChosen: v => {
                timeSet.command = ["timedatectl", "set-timezone", v];
                timeSet.running = true;
            }
        }

        ToggleRow {
            text: Tr.tr("Set the time from the internet")
            checked: root.ntp
            onToggled: {
                timeSet.command = ["timedatectl", "set-ntp", checked ? "true" : "false"];
                timeSet.running = true;
            }
        }

        SelectRow {
            last: true
            label: Tr.tr("Clock format")
            subtext: Tr.tr("How times are shown across the shell")
            menuOnTop: true
            menuItems: root.clockItems
            active: root.clockItems.find(i => i.value === GlobalConfig.services.clockFormat)
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }
    }
}

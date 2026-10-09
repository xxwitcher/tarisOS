#!/bin/sh
# Copyright (C) 2026 George Dobreff ("Witcher") and contributors
# SPDX-License-Identifier: GPL-3.0-only

# TarisOS's installer, run in macOS: curl -fsSL https://github.com/xxwitcher/tarisOS-packages/releases/download/image/install.sh | sh
# Starts the Asahi Linux installer (Asahi's Arch Linux ARM build of it) with TarisOS's list of
# systems to install (installer_data.json). The installer makes room next to macOS, installs
# TarisOS there and walks through Apple's step of allowing it to start (in recoveryOS).

# Nothing runs unless the whole script arrived
if true; then
	set -e

	if [ ! -e /System ]; then
		echo "TarisOS is installed from macOS (on an Apple Silicon Mac): run this in macOS's Terminal."
		exit 1
	fi
	if [ "$(uname -m)" != arm64 ]; then
		echo "TarisOS is for Apple Silicon Macs (M1, M2) only."
		exit 1
	fi
	if ! curl --no-progress-meter file:/// >/dev/null 2>&1; then
		echo "This Mac's macOS is too old: the installer needs macOS 13.5 or newer."
		exit 1
	fi

	export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
	export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

	# Asahi's installer (its Arch Linux ARM build) and TarisOS's list for it
	export VERSION_FLAG=https://asahi-alarm.org/latest
	export INSTALLER_BASE=https://asahi-alarm.org
	export REPO_BASE=https://asahi-alarm.org
	export INSTALLER_DATA=@INSTALLER_DATA@
	export REPORT=https://stats.asahilinux.org/report
	export REPORT_TAG=tarisos

	tmp=/tmp/tarisos-install
	[ -e "$tmp" ] && mv "$tmp" "$tmp-$(date +%Y%m%d-%H%M%S)"
	mkdir -p "$tmp"
	cd "$tmp"

	echo
	echo "Getting the installer..."
	version="$(curl --no-progress-meter -fL "$VERSION_FLAG")"
	package="installer-$version.tar.gz"
	curl --no-progress-meter -fL -o "$package" "$INSTALLER_BASE/$package"
	if ! curl --no-progress-meter -fL -o installer_data.json "$INSTALLER_DATA"; then
		echo "TarisOS's installer list couldn't be downloaded (is GitHub reachable from here?)."
		exit 1
	fi
	tar xf "$package"

	echo
	if [ "$(id -u)" != 0 ]; then
		echo "The installer runs as the administrator: enter your macOS password if asked."
		exec caffeinate -dis sudo -E ./install.sh "$@"
	else
		exec caffeinate -dis ./install.sh "$@"
	fi
fi

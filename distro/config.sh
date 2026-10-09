# Copyright (C) 2026 George Dobreff ("Witcher") and contributors
# SPDX-License-Identifier: GPL-3.0-only

# TarisOS's distribution settings, shared by the repository and image builds (sourced)

# The package repository (pacman's [taris]): a GitHub release's assets
TARIS_REPO=taris
TARIS_REPO_SERVER=https://github.com/xxwitcher/tarisOS/releases/download/packages

# Where the installer image (the zip) and installer_data.json are published
TARIS_IMAGE_BASE=https://github.com/xxwitcher/tarisOS/releases/download/image
TARIS_IMAGE_NAME=tarisos

# Built from the AUR into the repository (fetched when the repository is built; a changed
# PKGBUILD is shown for review before it's built)
TARIS_AUR_PACKAGES=(yay visual-studio-code-bin nordvpn-bin)

# This repository's own packages, in build order (each needs the ones before it installed to build)
TARIS_PACKAGES=(
	libcava qt6-m3shapes-git ttf-rubik-vf python-materialyoucolor mise-bin libva-v4l2-request-avd
	quickshell-taris taris-cli qmltermwidget-taris taris-shell
	taris-keyring taris-hardware taris-desktop taris-login taris-chromium taris-snapshots taris-firewall taris-wallpapers taris
)

# Where builds go (big: not in /tmp, which is RAM here)
TARIS_OUT="${TARIS_OUT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/out}"

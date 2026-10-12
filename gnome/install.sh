#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
set -eu
if [ "$(uname -s)" != Linux ]; then
    echo 'Run this installer on a Linux GNOME desktop.' >&2
    exit 1
fi
if [ ! -x /usr/bin/python3 ]; then
    echo 'Install Python 3.10 or newer first.' >&2
    exit 1
fi
/usr/bin/python3 -c 'import sys; assert sys.version_info >= (3, 10), "Python 3.10 or newer is required"'
command -v gnome-extensions >/dev/null 2>&1 || { echo 'GNOME Shell is required.' >&2; exit 1; }
task_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
/usr/bin/python3 "$task_dir/package.py"
uuid='ai-limitshower@mermalat'
target="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"
if [ -e "$target" ]; then
    backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
    cp -R "$target" "$backup"
    echo "Previous version backed up: $backup"
fi
gnome-extensions install --force "$task_dir/dist/$uuid.shell-extension.zip"
if gnome-extensions enable "$uuid"; then
    echo 'Installed and enabled. If the indicators do not appear, log out and log in again.'
else
    echo "Installed. Log out and log in, then run: gnome-extensions enable $uuid"
fi

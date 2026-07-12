#!/usr/bin/env sh
set -eu

if [ "${MPV_CONFIG_DIR:-}" ]; then
  TARGET="$MPV_CONFIG_DIR"
elif [ "$(uname -s)" = "Darwin" ]; then
  TARGET="${HOME}/.config/mpv"
else
  TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/mpv"
fi

rm -f "$TARGET/scripts/ddys-mpv.lua" "$TARGET/script-opts/ddys-mpv.conf"
printf '%s\n' "removed ddys-mpv from $TARGET"

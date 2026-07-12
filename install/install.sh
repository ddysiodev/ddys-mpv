#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ "${MPV_CONFIG_DIR:-}" ]; then
  TARGET="$MPV_CONFIG_DIR"
elif [ "$(uname -s)" = "Darwin" ]; then
  TARGET="${HOME}/.config/mpv"
else
  TARGET="${XDG_CONFIG_HOME:-${HOME}/.config}/mpv"
fi

mkdir -p "$TARGET/scripts" "$TARGET/script-opts"
cp "$ROOT/scripts/ddys-mpv.lua" "$TARGET/scripts/ddys-mpv.lua"

if [ ! -f "$TARGET/script-opts/ddys-mpv.conf" ] || [ "${FORCE:-0}" = "1" ]; then
  cp "$ROOT/script-opts/ddys-mpv.conf" "$TARGET/script-opts/ddys-mpv.conf"
fi

printf '%s\n' "installed ddys-mpv"
printf '%s\n' "script: $TARGET/scripts/ddys-mpv.lua"
printf '%s\n' "config: $TARGET/script-opts/ddys-mpv.conf"

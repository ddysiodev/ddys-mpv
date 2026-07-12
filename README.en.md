# ddys-mpv

`ddys-mpv` is an mpv Lua script for the DDYS API. It lets mpv users browse DDYS categories, search titles, select playback sources, and play direct URLs from the player.

## Features

- Home menu: latest, hot, movies, series, anime, variety, documentaries
- Search through mpv console
- Detail page and source selection
- Direct playback with mpv `loadfile`
- Preference-based source sorting
- External resource display
- Local history and favorites
- M3U and PLS playlist export
- Configurable API Base, API Key, paging, key bindings, and direct-only mode
- Windows, macOS, and Linux install scripts

## Install

Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install\install.ps1
```

macOS/Linux:

```bash
sh install/install.sh
```

## Keys

```text
Ctrl+d  DDYS menu
Ctrl+s  Search
Ctrl+l  Latest
Ctrl+h  History
Ctrl+f  Favorites
```

While the menu is open:

```text
Up/Down    Select
Enter      Open or play
Backspace  Home
Esc        Close
```

## Config

Edit `script-opts/ddys-mpv.conf`:

```text
api_base=https://ddys.io/api/v1
site_base=https://ddys.io
api_key=
http_command=curl
direct_only=no
include_external=yes
auto_play_best=no
```

## License

MIT

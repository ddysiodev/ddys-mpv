# Architecture

`ddys-mpv` is intentionally small: one Lua script, one script-options file, install scripts, and tests.

## Runtime

- `scripts/ddys-mpv.lua` is loaded by mpv from the user `scripts` directory.
- `script-opts/ddys-mpv.conf` is read by mpv through `mp.options`.
- API requests are made with `mp.command_native({ name = "subprocess" })` and a curl-compatible command.
- JSON is parsed with `mp.utils.parse_json`.
- Playback uses `mp.commandv("loadfile", url, "replace")`.
- OSD UI uses `mp.osd_message`.

## Menu Model

The script keeps an in-memory menu state:

- `home`: source list and local tools
- `movies`: category/search result list
- `detail`: playback resources and playlist actions
- `history`: local playback history
- `favorites`: local saved titles

Navigation keys are bound only while the DDYS menu is open, then removed when playback starts or the menu is closed.

## DDYS API Mapping

```text
GET /latest?limit=<homeLimit>
GET /hot?limit=<homeLimit>
GET /movies?type=<type>&page=<page>&per_page=<pageSize>
GET /search?q=<query>&page=<page>&per_page=<pageSize>
GET /movies/{slug}/sources
```

The parser accepts common list wrappers such as `items`, `list`, `results`, `movies`, `records`, and `data`. Resource groups accept `items`, `resources`, `episodes`, `playlist`, `play`, `urls`, `online`, `download`, `cloud`, `netdisk`, and magnet variants.

## Local Files

By default, files are stored in the mpv config directory:

```text
ddys-mpv-history.json
ddys-mpv-favorites.json
<slug>.m3u
<slug>.pls
```

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Dank Material Shell (DMS) plugin showing the next calendar event from
[dcal](https://github.com/AvengeMedia/dcal) with a live countdown, plus a popout listing
today's events. Plugin ID: `dankCalendarAgendaLocal`. Enhanced fork by luckjokerwang
based on `arqueon/dms-dankcalendar` and `leoamaro01/dms-dcal`.

## Development

No build step, tests, or linter. Pure QML + two bash helper scripts, loaded by the DMS
plugin runtime. Test locally by placing the repo in
`~/.config/DankMaterialShell/plugins/dankCalendarAgendaLocal/` (script paths are resolved as
`PluginService.pluginDirectory + "/dankCalendarAgendaLocal/..."`), then
`dms ipc plugin-scan reload dankCalendarAgendaLocal` or restart the shell.

Runtime dependencies: `dcal` (calendar daemon with IPC) and `jq`.

## Architecture

- **`plugin.json`** — DMS plugin manifest.
- **`DankCalendarWidget.qml`** — Main widget. Fetches the next event via `get-next-event`
  (key=value lines, SplitParser) and the agenda via `get-agenda-events` (raw JSON,
  StdioCollector) on the same refresh timer. Renders the countdown pill (horizontal and
  vertical), the hover tooltip (layer-shell PanelWindow, empty input region), and the
  popout: a dankmail-style custom header plus a flat display model built by
  `buildAgenda()` — "week" divider / shaded "day" header / "event" rows with fixed
  per-kind heights, so the total height (and the scroll offset of today, used to pin
  the list to today on open) is known before DankPopout positions the surface. Rows dim
  when past and go green while happening.
- **`DankCalendarSettings.qml`** — `PluginSettings` form writing to `pluginData`.
- **`get-next-event`** — Upstream script: next upcoming event within the look-ahead
  window, emits `EVENT_SUMMARY=` / `EVENT_START=` / `EVENT_END=` lines.
- **`get-agenda-events PAST FUTURE`** — Emits `dcal ipc events.list` JSON for local
  midnight−PAST days → local midnight+FUTURE days. Local→UTC conversion goes through an
  epoch because `date -u -d` parses its input as UTC; the widget sorts (by day, all-day
  first within a day, then by start).

## DMS Plugin Conventions

QML files import DMS-provided namespaces (`qs.Common`, `qs.Widgets`, `qs.Services`,
`qs.Modules.Plugins`) that have no external documentation. Settings are read as
`pluginData.<key> || <default>`. With `popoutContent` set, left click opens the popout
automatically; `pillRightClickAction` handles right click; middle click needs a
`MouseArea` with `acceptedButtons: Qt.MiddleButton` (and negative margins to cover the
BasePill padding) so left/right fall through.

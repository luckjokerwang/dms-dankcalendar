# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Dank Material Shell (DMS) plugin showing the next calendar event from
[dcal](https://github.com/AvengeMedia/dcal) with a live countdown, plus a popout listing
today's events. Plugin ID: `dankCalendar`. Fork of
[leoamaro01/dms-dcal](https://github.com/leoamaro01/dms-dcal) with the dms-dankmail click
model: left click opens the popout, clicking an event runs `dcal ipc ui.openEvent`, right
click refreshes, middle click runs `dcal ipc ui.toggle view=day`. Hover still shows the
next-event tooltip.

## Development

No build step, tests, or linter. Pure QML + two bash helper scripts, loaded by the DMS
plugin runtime. Test locally by symlinking the repo to
`~/.config/DankMaterialShell/plugins/dankCalendar/` (the directory name matters — script
paths are resolved as `PluginService.pluginDirectory + "/dankCalendar/..."`), then
`dms ipc plugin-scan reload dankCalendar` or restart the shell.

Runtime dependencies: `dcal` (calendar daemon with IPC) and `jq`.

## Architecture

- **`plugin.json`** — DMS plugin manifest.
- **`DankCalendarWidget.qml`** — Main widget. Fetches the next event via `get-next-event`
  (key=value lines, SplitParser) and today's events via `get-today-events` (raw JSON,
  StdioCollector) on the same refresh timer. Renders the countdown pill (horizontal and
  vertical), the hover tooltip (layer-shell PanelWindow, empty input region), and the
  popout (dankmail-style custom header + event list; rows dim when past, go green while
  happening).
- **`DankCalendarSettings.qml`** — `PluginSettings` form writing to `pluginData`.
- **`get-next-event`** — Upstream script: next upcoming event within the look-ahead
  window, emits `EVENT_SUMMARY=` / `EVENT_START=` / `EVENT_END=` lines.
- **`get-today-events`** — Emits `dcal ipc events.list` JSON for the local calendar day
  (midnight→midnight converted to UTC); the widget sorts (all-day first, then by start).

## DMS Plugin Conventions

QML files import DMS-provided namespaces (`qs.Common`, `qs.Widgets`, `qs.Services`,
`qs.Modules.Plugins`) that have no external documentation. Settings are read as
`pluginData.<key> || <default>`. With `popoutContent` set, left click opens the popout
automatically; `pillRightClickAction` handles right click; middle click needs a
`MouseArea` with `acceptedButtons: Qt.MiddleButton` (and negative margins to cover the
BasePill padding) so left/right fall through.

# dms-dankcalendar

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget for
[dcal / DankCalendar](https://github.com/AvengeMedia/dcal): your next event with a live
countdown in the bar, and today's agenda one click away.

Fork of [leoamaro01/dms-dcal](https://github.com/leoamaro01/dms-dcal) with the click
model of [dms-dankmail](https://github.com/arqueon/dms-dankmail).

## Behavior

| Action | Result |
|---|---|
| Left click | Popout with today's events |
| Click an event in the popout | Opens that event's details in DankCalendar |
| Right click | Refreshes the countdown and today's list |
| Middle click | Toggles the DankCalendar window |
| Hover | Tooltip with the full next-event summary |

The bar pill keeps everything from upstream dms-dcal: scrolling event name, dot
separator, live countdown ("2h30m", "Now" while an event is starting), compact
vertical-bar layout, and the hover tooltip.

## Requirements

- `dcal` (DankCalendar daemon with IPC) running
- `jq`

## Install

```bash
git clone https://github.com/arqueon/dms-dankcalendar \
  ~/.config/DankMaterialShell/plugins/dankCalendar
```

Then Settings → Plugins → Scan for Plugins, enable **Dank Calendar**, and add it to a
DankBar section.

> The install directory must be named `dankCalendar` — the widget resolves its helper
> scripts through that path.

## Settings

- **Refresh Interval** — how often to re-fetch events (seconds)
- **Dynamic Width** — shrink the pill to fit the event name
- **Hover Tooltip** — toggle the next-event hover tooltip
- **Event Name Width** — max pill width for the event name
- **Now Duration** — how long to show "Now" after an event starts
- **Look Ahead** — how many days ahead the countdown searches

## Credits

- Original plugin by [Leonardo Amaro](https://github.com/leoamaro01) (MIT).
- Popout/click pattern from [dms-dankmail](https://github.com/arqueon/dms-dankmail).

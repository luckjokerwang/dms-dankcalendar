# dms-dankcalendar

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget for
[dcal / DankCalendar](https://github.com/AvengeMedia/dcal): your next event with a live
countdown in the bar, and a scrollable agenda one click away.

Fork of [leoamaro01/dms-dcal](https://github.com/leoamaro01/dms-dcal) with the click
model of [dms-dankmail](https://github.com/arqueon/dms-dankmail).

![Screenshot](assets/screenshot.png)

The agenda popout: shaded day headers, today tinted, happening-now events in green, past
events dimmed, and a floating **Today** chip to jump back when you scroll away.

## Behavior

| Action | Result |
|---|---|
| Left click | Agenda popout, opened at today |
| Click an event in the popout | Opens that event's details in DankCalendar |
| `+` in the popout header | Opens DankCalendar in day view to create an event |
| Right click | Refreshes the countdown and the agenda |
| Middle click | Toggles the DankCalendar window |
| Hover | Tooltip with the full next-event summary |

The agenda covers a configurable window (default 7 days back, 30 ahead), grouped by
day with shaded headers — today tinted, happening-now events in green, past events
dimmed — and a divider each time the week changes. It always opens scrolled to today.

The bar pill keeps everything from upstream dms-dcal: scrolling event name, dot
separator, live countdown ("2h30m", "Now" while an event is starting), compact
vertical-bar layout, and the hover tooltip.

<img src="assets/screenshot-bar.png" width="420" alt="Pill in a vertical bar with the agenda popout">


## Requirements

- `dcal` (DankCalendar daemon with IPC) running
- `jq`

## Install

```bash
git clone https://github.com/arqueon/dms-dankcalendar \
  ~/.config/DankMaterialShell/plugins/dankCalendarAgenda
```

Then Settings → Plugins → Scan for Plugins, enable **Dank Calendar Agenda**, and add it
to a DankBar section.

> The install directory must be named `dankCalendarAgenda` — the widget resolves its helper
> scripts through that path.

## Settings

- **Refresh Interval** — how often to re-fetch events (seconds)
- **Dynamic Width** — shrink the pill to fit the event name
- **Hover Tooltip** — toggle the next-event hover tooltip
- **Event Name Width** — max pill width for the event name
- **Now Duration** — how long to show "Now" after an event starts
- **Agenda: Days Back** — past days kept scrollable in the popout (0–90, default 7)
- **Agenda: Days Ahead** — upcoming days the popout covers (7–90, default 30)
- **Look Ahead** — how many days ahead the countdown searches

## License

GPL-3.0-or-later. The upstream code this plugin forks from is MIT © 
[Leonardo Amaro](https://github.com/leoamaro01) — see `LICENSE.upstream`.

## Credits

- Original plugin by [Leonardo Amaro](https://github.com/leoamaro01) (MIT).
- Popout/click pattern from [dms-dankmail](https://github.com/arqueon/dms-dankmail).
- The screenshot shows fictitious demo events.

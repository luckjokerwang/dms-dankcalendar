# dms-dankcalendar 扩展 (Dank Calendar Extension)

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget for
[dcal / DankCalendar](https://github.com/AvengeMedia/dcal): your next event with a live
countdown in the bar, and a scrollable agenda one click away.

Enhanced fork maintained by **luckjokerwang**, based on `arqueon/dms-dankcalendar` and `leoamaro01/dms-dcal`.

![Screenshot](assets/screenshot.png)

The agenda popout: shaded day headers, today tinted, happening-now events in green, past
events dimmed, and a floating **Today** chip to jump back when you scroll away.

## Key Features & Enhancements

- **Pill Display Modes**: Full (`Title • Countdown`), `Countdown Only` (compact), or `Title Only`.
- **Text Scrolling / Ellipsis Control**: Toggle title marquee animation or truncate with ellipsis `...` when text overflows.
- **Manual Sync Integration**: Right click on the pill or refresh button in the popout triggers `dcal ipc accounts.refresh` with auto-reload.
- **Interactive Agenda**: Popout with day grouping, week headers, and quick event inspection.

## Behavior

| Action | Result |
|---|---|
| Left click | Agenda popout, opened at today |
| Click an event in the popout | Opens that event's details in DankCalendar |
| `+` in the popout header | Opens DankCalendar in day view to create an event |
| Right click | Refreshes provider accounts and reloads countdown & agenda |
| Middle click | Toggles the DankCalendar window |
| Hover | Privacy-conscious event card with schedule, location, a short description and link availability |

## Requirements

- `dcal` (DankCalendar daemon with IPC) running
- `jq`

## Install

```bash
git clone https://github.com/luckjokerwang/dms-dankcalendar.git \
  ~/.config/DankMaterialShell/plugins/dankCalendarAgendaLocal
```

Then Settings → Plugins → Scan for Plugins, enable **Dank Calendar Extension**, and add it
to a DankBar section.

## Settings

- **Pill Display Mode** — Full, Countdown Only, or Title Only
- **Scroll Long Titles** — Toggle marquee scrolling for long event names
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

- Maintained & enhanced by [luckjokerwang](https://github.com/luckjokerwang).
- Forked from [arqueon/dms-dankcalendar](https://github.com/arqueon/dms-dankcalendar) (GPL-3.0).
- Original plugin by [Leonardo Amaro](https://github.com/leoamaro01) (MIT).


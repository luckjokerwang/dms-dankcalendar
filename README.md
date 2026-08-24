# dms-dankcalendar 扩展 (Dank Calendar Extension)

A powerful, all-in-one [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget for [dcal / DankCalendar](https://github.com/AvengeMedia/dcal): seamlessly manage your **Agenda (日程)** and **Tasks (待办任务)** from your top bar.

Enhanced fork maintained by **luckjokerwang**, based on `arqueon/dms-dankcalendar` and `leoamaro01/dms-dcal`.

![Screenshot](assets/screenshot.png)

## 🌟 Key Features & Enhancements

### 📅 Agenda & 📋 Tasks Integration (日程与待办双模式)
- **Dual-Mode Bar Pill**: Left-click the pill icon to cycle between **Agenda Mode** and **Tasks Mode**. In Tasks mode, the pill displays your pending task count and the current task name with smooth marquee scrolling / ellipsis truncation.
- **Unified Tabbed Popout**: Header with `timeManager`-style tabs `[ 📅 日程 ]` and `[ ✓ 待办 (N) ]` with a stable, fixed viewport (`420 x 540`) — zero jitter or sizing jump when switching.
- **Cross-Display State Sync**: Leverages DMS `PluginGlobalVar` to synchronize mode and state across all connected monitors in real-time.

### ⚡ Tasks Management (待办全功能)
- **0ms Instant Optimistic UI**: Check off, uncheck, or add tasks with instantaneous feedback and a robust FIFO sequential action queue to prevent race conditions or database lockups.
- **Smart Priority Badging & Shortcuts**: Supports RFC 5545 priorities with color-coded badges (🔴 高优, 🟡 中优, 🔵 低优). Quickly set priority upon creation via shortcuts like `!1` (or `!h`), `!2` (or `!m`), `!3` (or `!l`).
- **Multi-Calendar Filtering**: Easily switch between task lists / calendars with filter pills.
- **Collapsible Completed Tasks**: Group finished items into an expandable `已完成 (N)` section.
- **Stable Multi-Level Sorting**: Ordered by Priority → Due Date → Creation Date.

### 🎨 Visual & UX Polish
- **360° Smooth Refresh Animation**: GPU-accelerated rotating feedback on manual refresh (`↻` or right-click).
- **Graceful Error Feedback**: Integrated sync failure warnings with direct retry action.
- **Customizable Sizing**: Minimum pill event width adjustable down to `40px` in settings.

## 🕹️ Quick Actions

| Action | Result |
|---|---|
| Click Pill Icon | Cycles between **Agenda** and **Tasks** mode (synced across all monitors) |
| Left Click Pill Body | Opens the popout window |
| Middle Click | Toggles the full DankCalendar application window |
| Right Click / ↻ | Triggers account sync (`dcal ipc accounts.refresh`) with rotation feedback |
| Popout `+` Button | Opens DankCalendar in day view to create a new event |
| Popout Quick Add Bar | Quickly creates a task (supports `!1`, `!2`, `!3` priority prefix) |
| Click Task Checkbox | Toggles task completion state |
| Hover on Pill | Displays detailed event card / task summary tooltip |

## 📦 Requirements

- `dcal` (DankCalendar daemon with IPC) running
- `jq`
- Python 3

## ⚙️ Settings

- **Pill Display Mode** — Full (`Title • Countdown`), Countdown Only, or Title Only
- **Scroll Long Titles** — Toggle marquee scrolling for long event / task names
- **Refresh Interval** — Polling interval for upcoming events (seconds)
- **Dynamic Width** — Automatically shrink the pill to fit the text
- **Hover Tooltip** — Toggle the hover details card
- **Event Name Width** — Maximum pill text width (40px – 300px)
- **Now Duration** — How long to display "Now" after an event starts
- **Agenda: Days Back / Days Ahead** — Scope of scrollable historical / future agenda items

## License

GPL-3.0-or-later. The upstream code this plugin forks from is MIT © 
[Leonardo Amaro](https://github.com/leoamaro01) — see `LICENSE.upstream`.

## Credits

- Maintained & enhanced by [luckjokerwang](https://github.com/luckjokerwang).
- Forked from [arqueon/dms-dankcalendar](https://github.com/arqueon/dms-dankcalendar) (GPL-3.0).
- Original plugin by [Leonardo Amaro](https://github.com/leoamaro01) (MIT).


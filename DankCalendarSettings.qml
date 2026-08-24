import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankCalendarAgendaLocal"

    StyledText {
        width: parent.width
        text: "Dank Calendar Extension"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Shows your next calendar event from dcal with a live countdown. Left click lists today's events (click one to open it), right click refreshes, middle click toggles the DankCalendar window."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "pillDisplayMode"
        label: "Pill Display Mode"
        description: "Choose what content to display in the bar pill"
        defaultValue: "full"
        options: [
            {
                label: "Full (Title • Countdown)",
                value: "full"
            },
            {
                label: "Countdown Only",
                value: "countdownOnly"
            },
            {
                label: "Title Only",
                value: "titleOnly"
            }
        ]
    }

    ToggleSetting {
        settingKey: "scrollTitle"
        label: "Scroll Long Titles"
        description: "Scroll event names that exceed the widget width, or truncate with ellipsis when disabled"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval"
        description: "How often to fetch the next event (seconds)"
        defaultValue: 30
        minimum: 10
        maximum: 120
        unit: "sec"
        leftIcon: "schedule"
    }

    ToggleSetting {
        settingKey: "dynamicWidth"
        label: "Dynamic Width"
        description: "Shrink the widget to fit the event name instead of using a fixed width"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showTooltip"
        label: "Hover Tooltip"
        description: "Show the full event summary in a tooltip when hovering the widget"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "pillMaxWidth"
        label: "Event Name Width"
        description: "Maximum width for the event name in the bar (pixels)"
        defaultValue: 160
        minimum: 80
        maximum: 300
        unit: "px"
        leftIcon: "width"
    }

    SliderSetting {
        settingKey: "nowWindowMinutes"
        label: "Now Duration"
        description: "How long to show 'Now' after an event starts (0 to disable)"
        defaultValue: 5
        minimum: 0
        maximum: 30
        unit: "min"
        leftIcon: "timelapse"
    }

    SliderSetting {
        settingKey: "agendaPastDays"
        label: "Agenda: Days Back"
        description: "How many past days the popout agenda keeps scrollable (it opens at today)"
        defaultValue: 7
        minimum: 0
        maximum: 90
        unit: "days"
        leftIcon: "history"
    }

    SliderSetting {
        settingKey: "agendaFutureDays"
        label: "Agenda: Days Ahead"
        description: "How many upcoming days the popout agenda covers"
        defaultValue: 30
        minimum: 7
        maximum: 90
        unit: "days"
        leftIcon: "view_agenda"
    }

    SliderSetting {
        settingKey: "lookAheadDays"
        label: "Look Ahead"
        description: "How many days ahead to check for events"
        defaultValue: 1
        minimum: 1
        maximum: 7
        unit: "days"
        leftIcon: "date_range"
    }
}

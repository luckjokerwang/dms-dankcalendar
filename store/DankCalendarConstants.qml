import QtQuick

QtObject {
    id: constants

    // Module Identifiers
    readonly property string moduleAgenda: "agenda"
    readonly property string moduleTasks: "tasks"
    readonly property string moduleAi: "ai"

    // Task Priorities
    readonly property int priorityHigh: 1
    readonly property int priorityMedium: 5
    readonly property int priorityLow: 9
    readonly property int priorityNone: 0

    // UI Dimensions
    readonly property int defaultPopoutWidth: 440
    readonly property int defaultPopoutHeight: 560
    readonly property int defaultContentHeight: 420
    readonly property int defaultPillMaxWidth: 200
    readonly property int defaultIconSize: 18

    // Defaults & Intervals
    readonly property int defaultRefreshInterval: 30000
    readonly property int defaultNowWindowMinutes: 5
    readonly property int defaultLookAheadDays: 1
    readonly property int defaultAgendaPastDays: 7
    readonly property int defaultAgendaFutureDays: 30

    // Core CLI Path
    readonly property string coreScriptPath: Qt.resolvedUrl("../core/dms-calendar-core").toString().replace(/^file:\/\//, "")
}

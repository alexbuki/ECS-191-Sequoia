import AppIntents
import UserNotifications
import WidgetKit
import SequoiaCore

/// "Got it" from the medium widget: completes today without opening the app.
/// On the day the tree would be planted the widget shows "Plant your sequoia"
/// instead, which opens the app; a stale widget that still offers "Got it"
/// then only refreshes, so the planting always happens in the app.
struct GotItIntent: AppIntent {
    static let title: LocalizedStringResource = "Got it"
    static let description = IntentDescription("Marks today's word as learned and grows your tree.")

    @MainActor
    func perform() async throws -> some IntentResult {
        // Throws rather than checking in to a throwaway store that would lose it.
        let store = SequoiaStore(container: try Persistence.makeContainer())
        guard !store.todayPlantsTree else {
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        store.checkIn()
        // Today's reminder and nudge are no longer needed. The app reschedules
        // everything else the next time it opens.
        let day = store.today.dayNumber
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reminder-\(day)", "nudge-\(day)"])
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

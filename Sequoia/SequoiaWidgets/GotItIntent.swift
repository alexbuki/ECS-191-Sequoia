import AppIntents
import UserNotifications
import WidgetKit
import SequoiaCore

/// "Got it" from the medium widget: completes today without opening the app.
struct GotItIntent: AppIntent {
    static let title: LocalizedStringResource = "Got it"
    static let description = IntentDescription("Marks today's word as learned and grows your tree.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = SequoiaStore(container: Persistence.makeContainerOrFallback())
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

import Foundation
import UserNotifications
import SequoiaCore

/// Schedules the daily reminder (a teaser that keeps the word a surprise), the
/// optional evening streak nudge, and handles taps by opening Today.
@MainActor
final class NotificationService: NSObject {
    nonisolated static let categoryID = "DAILY_WORD"
    nonisolated static let dayNumberKey = "dayNumber"
    /// How many days of reminders are queued ahead. Each carries its own word.
    nonisolated static let daysAhead = 14

    private let center = UNUserNotificationCenter.current()
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    weak var app: AppModel?

    func configure() {
        center.delegate = self
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Prompts at most once. Returns whether notifications are allowed.
    @discardableResult
    func requestPermissionIfNeeded(store: SequoiaStore) async -> Bool {
        await refreshAuthorization()
        if authorization == .notDetermined, !store.settings.hasRequestedNotificationPermission {
            store.updateSettings { $0.hasRequestedNotificationPermission = true }
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorization()
            await reschedule(store: store)
            return granted
        }
        return authorization == .authorized || authorization == .provisional
    }

    /// Rebuilds every pending request from the current state.
    func reschedule(store: SequoiaStore) async {
        await refreshAuthorization()
        // Replace only the scheduled reminders and nudges, not a dev "fire now".
        let scheduled = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix("reminder-") || $0.hasPrefix("nudge-") }
        center.removePendingNotificationRequests(withIdentifiers: scheduled)
        let settings = store.settings
        guard settings.notificationsEnabled, authorization == .authorized || authorization == .provisional else { return }
        for request in Self.requests(store: store) {
            try? await center.add(request)
        }
    }

    /// The requests to schedule. Pure enough to be tested.
    static func requests(store: SequoiaStore) -> [UNNotificationRequest] {
        let clock = store.currentClock
        let calendar = clock.calendar
        let now = clock.now()
        // Scheduling uses real time; the simulated clock only picks the content.
        let realOffset = AppClock.developerOffset
        let settings = store.settings
        var requests: [UNNotificationRequest] = []

        for offset in 0..<daysAhead {
            let day = store.today.adding(days: offset)
            if offset == 0 && store.todayCompleted { continue }
            guard let fire = calendar.date(bySettingHour: settings.reminderHour, minute: settings.reminderMinute,
                                           second: 0, of: day.startDate(in: calendar)), fire > now else { continue }
            let content = reminderContent(dayNumber: day.dayNumber)
            requests.append(request(id: "reminder-\(day.dayNumber)", content: content,
                                    at: fire.addingTimeInterval(-realOffset), calendar: calendar))
        }

        if settings.streakNudgeEnabled {
            // Nudge this evening if the streak is alive but today isn't done, and
            // tomorrow evening if today is done (it will be at risk then).
            let nudgeHour = settings.reminderHour >= 19 ? 21 : 20
            let candidates: [(DayStamp, Bool)] = [
                (store.today, store.isStreakAtRisk),
                (store.today.adding(days: 1), store.todayCompleted && store.growth.currentStreak > 0),
            ]
            for (day, shouldNudge) in candidates where shouldNudge {
                guard let fire = calendar.date(bySettingHour: nudgeHour, minute: 0, second: 0, of: day.startDate(in: calendar)),
                      fire > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = nudgeTitle(for: store.stage)
                content.body = String(localized: "One word keeps your \(store.growth.currentStreak)-day streak growing.")
                content.sound = .default
                content.categoryIdentifier = categoryID
                content.userInfo = [dayNumberKey: day.dayNumber]
                requests.append(request(id: "nudge-\(day.dayNumber)", content: content,
                                        at: fire.addingTimeInterval(-realOffset), calendar: calendar))
            }
        }
        return requests
    }

    /// The daily reminder. It never reveals the word, so opening the app stays
    /// the moment of discovery. The wording rotates by day.
    static func reminderContent(dayNumber: Int) -> UNMutableNotificationContent {
        let teasers: [(title: String, body: String)] = [
            (String(localized: "A new word is waiting"), String(localized: "Check in to learn it and grow your tree.")),
            (String(localized: "Time to grow your tree"), String(localized: "Today's word is ready when you are.")),
            (String(localized: "Your daily word has arrived"), String(localized: "Open Sequoia to see what it is.")),
            (String(localized: "Ready for today's word?"), String(localized: "One minute of learning, one more ring on your tree.")),
            (String(localized: "Check in with Sequoia"), String(localized: "A fresh word is here to help your tree grow.")),
        ]
        let teaser = teasers[((dayNumber % teasers.count) + teasers.count) % teasers.count]
        let content = UNMutableNotificationContent()
        content.title = teaser.title
        content.body = teaser.body
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.threadIdentifier = "daily-word"
        content.userInfo = [dayNumberKey: dayNumber]
        return content
    }

    static func nudgeTitle(for stage: TreeStage) -> String {
        switch stage {
        case .seed: String(localized: "Your seed is waiting for water")
        case .sprout: String(localized: "Your sprout is thirsty")
        case .sapling: String(localized: "Your sapling is thirsty")
        case .youngSequoia, .grownSequoia: String(localized: "Your sequoia is thirsty")
        }
    }

    private static func request(id: String, content: UNNotificationContent, at date: Date, calendar: Calendar) -> UNNotificationRequest {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    #if SEQUOIA_DEV
    /// Delivers today's reminder in a few seconds (developer tool).
    func fireNow(store: SequoiaStore) async {
        let content = Self.reminderContent(dayNumber: store.today.dayNumber)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "dev-now", content: content, trigger: trigger))
    }

    /// Pending requests with their next fire dates, soonest first (developer tool).
    func pendingRequests() async -> [(id: String, title: String, date: Date?)] {
        await center.pendingNotificationRequests()
            .map { request in
                let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                    ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
                return (request.identifier, request.content.title, date)
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }
    #endif

    /// Handles a tap by opening Today, where the word is revealed.
    func handle(actionIdentifier: String, dayNumber: Int?) {
        guard let app else { return }
        app.store.reloadFromDisk()
        app.selectedTab = .today
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    // The completion-handler variants, not the async ones: the async thunks call
    // UIKit's completion handler off the main thread, which aborts when a
    // notification action arrives while the app is in the background.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let action = response.actionIdentifier
        let dayNumber = response.notification.request.content.userInfo[Self.dayNumberKey] as? Int
        Task { @MainActor in
            self.handle(actionIdentifier: action, dayNumber: dayNumber)
            completionHandler()
        }
    }
}

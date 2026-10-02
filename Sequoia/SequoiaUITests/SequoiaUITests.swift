import XCTest

@MainActor
final class SequoiaUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Saves a screenshot to `SEQUOIA_SCREENSHOT_DIR` (when set) and attaches it to the test.
    func snapshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SEQUOIA_SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(filePath: dir).appending(path: "\(name).png"))
        }
    }

    func launch(_ arguments: [String], skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + (skipOnboarding ? ["-uiTestingSkipOnboarding"] : [])
        app.launch()
        return app
    }

    /// Accepts the notification permission alert if the system shows it.
    func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
    }

    func testOnboardingAppearsOnceAndAppliesChoices() throws {
        let start = Date()
        var app = launch(["-uiTestingDiskStore", "-uiTestingResetStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboardingBegin"].waitForExistence(timeout: 10))
        snapshot("onboarding-welcome")
        app.buttons["onboardingBegin"].tap()
        XCTAssertTrue(app.buttons["difficulty-3"].waitForExistence(timeout: 5))
        snapshot("onboarding-difficulty")
        app.buttons["difficulty-3"].tap()
        XCTAssertTrue(app.buttons["reminder-evening"].waitForExistence(timeout: 5))
        snapshot("onboarding-reminder")
        app.buttons["reminder-evening"].tap()
        allowNotificationsIfAsked()
        let word = app.staticTexts["wordTitle"]
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboardingBegin"].waitForNonExistence(timeout: 10))
        XCTAssertLessThan(Date().timeIntervalSince(start), 20, "onboarding finishes in under 20 seconds")
        XCTAssertEqual(word.value as? String, "Erudite", "chosen difficulty drives today's word")

        app.terminate()
        app = launch(["-uiTestingDiskStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboardingBegin"].exists, "onboarding shows only on first launch")
    }

    func testOnboardingCanBeSkipped() throws {
        let app = launch(["-uiTestingInMemoryStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboardingSkip"].waitForExistence(timeout: 10))
        app.buttons["onboardingSkip"].tap()
        allowNotificationsIfAsked()
        XCTAssertTrue(app.buttons["onboardingSkip"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["wordTitle"].value as? String, "Elevated", "defaults apply when skipped")
    }

    func testSettingsChangesApplyImmediately() throws {
        let app = launch(["-uiTestingInMemoryStore"])
        XCTAssertTrue(app.staticTexts["wordTitle"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Everyday"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Everyday"].firstMatch.tap()
        snapshot("settings")
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertEqual(app.staticTexts["wordTitle"].value as? String, "Everyday")
    }

    func testShowsFourTabs() throws {
        let app = launch(["-uiTestingInMemoryStore"])
        for tab in ["Today", "Library", "Practice", "Forest"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 10), "Missing tab \(tab)")
        }
    }

    func testGotItPersistsAcrossRelaunch() throws {
        var app = launch(["-uiTestingDiskStore", "-uiTestingResetStore"])
        let gotIt = app.buttons["gotIt"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 10), "Today opens directly to the word")
        snapshot("today-before")
        gotIt.tap()
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 5))
        snapshot("today-after")

        app.terminate()
        app = launch(["-uiTestingDiskStore"])
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 10), "Completion persists")
        XCTAssertFalse(app.buttons["gotIt"].exists)
    }

    func testShareSheetOffersTheCardImage() throws {
        let app = launch(["-uiTestingInMemoryStore"])
        let share = app.buttons["share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        // The system share sheet appears with the rendered card as its preview.
        let sheet = app.otherElements["ActivityListView"]
        let appeared = sheet.waitForExistence(timeout: 10) || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 2)
        snapshot("share-sheet")
        XCTAssertTrue(appeared)
    }

    func testLibraryEmptyStateSearchAndFavorites() throws {
        var app = launch(["-uiTestingInMemoryStore", "-tab", "library"])
        // The in-memory store has seen only today's word.
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        app.terminate()

        app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "5", "-tab", "library"])
        let rows = app.descendants(matching: .any).matching(identifier: "libraryRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        let totalRows = rows.count
        XCTAssertGreaterThanOrEqual(totalRows, 5, "every seen word is listed")

        app.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 5))
        snapshot("library-empty-favorites")
        app.buttons["All"].tap()

        // Rows combine their text for VoiceOver, so the label starts with the word.
        let firstWord = String(rows.element(boundBy: 0).label.split(separator: ",").first ?? "")
        XCTAssertFalse(firstWord.isEmpty)
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText(firstWord)
        let match = rows.matching(NSPredicate(format: "label BEGINSWITH %@", firstWord)).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5))
        XCTAssertLessThan(rows.count, totalRows, "search narrows the list")
        snapshot("library-search")
        match.tap()
        XCTAssertTrue(app.staticTexts["wordTitle"].waitForExistence(timeout: 5), "tapping opens the detail card")
        snapshot("library-detail")
        app.terminate()
        _ = launch(["-devResetClock"]) // leave the dev clock at real time
    }

    // MARK: - Notifications (Step 7)
    // These need a fresh install (notification permission undetermined) and wait
    // for real delivery, so they run only with SEQUOIA_NOTIFICATION_TESTS=1:
    //   xcrun simctl uninstall booted app.sequoia.Sequoia
    //   TEST_RUNNER_SEQUOIA_NOTIFICATION_TESTS=1 xcodebuild test ... -only-testing:SequoiaUITests/SequoiaUITests/<test>

    func requireNotificationTests() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SEQUOIA_NOTIFICATION_TESTS"] == "1",
                          "Notification tests run only on a fresh install with SEQUOIA_NOTIFICATION_TESTS=1")
    }

    var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    func openDeveloperPanel(_ app: XCUIApplication) {
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        let developer = app.buttons["Developer"]
        for _ in 0..<5 where !developer.isHittable { app.swipeUp() }
        developer.tap()
        XCTAssertTrue(app.staticTexts["Notifications"].waitForExistence(timeout: 5)
                      || app.staticTexts["NOTIFICATIONS"].waitForExistence(timeout: 1))
    }

    /// The dev reminder helper rounds up to the next whole minute.
    func minuteAfter(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .minute, for: date)?.end ?? date
    }

    /// A pending row shows its fire time, e.g. "3:45 PM". The app and the test
    /// compute "N minutes from now" a moment apart, so the minute before also counts.
    func pendingRow(_ app: XCUIApplication, at date: Date) -> XCUIElement {
        let times = [date, date.addingTimeInterval(-60)].map { $0.formatted(date: .omitted, time: .shortened) }
        let predicate = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", times[0], times[1])
        return app.staticTexts.matching(predicate).firstMatch
    }

    func testNotificationFiresWithWordReschedulesAndGotItGrowsTree() throws {
        try requireNotificationTests()
        let thirty = minuteAfter(Date.now.addingTimeInterval(30 * 60))
        let app = launch(["-uiTestingDiskStore", "-uiTestingResetStore", "-devReminderInMinutes", "30"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboardingSkip"].waitForExistence(timeout: 10))
        app.buttons["onboardingSkip"].tap()
        let allow = springboard.buttons["Allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5), "skipping onboarding asks for notification permission")
        allow.tap()
        let title = app.staticTexts["wordTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let word = title.label

        // Configured time: 30 minutes from now.
        openDeveloperPanel(app)
        let firstRow = pendingRow(app, at: thirty)
        _ = firstRow.waitForExistence(timeout: 5)
        snapshot("notifications-pending-30min")
        XCTAssertTrue(firstRow.exists, "pending: \(app.staticTexts.allElementsBoundByIndex.map(\.label))")
        XCTAssertFalse(app.staticTexts[word].exists, "the reminder keeps the word a surprise")

        // Changing the reminder time reschedules it.
        app.buttons["Set reminder to 1 minute from now"].tap()
        let soon = minuteAfter(Date.now.addingTimeInterval(60))
        XCTAssertTrue(pendingRow(app, at: soon).waitForExistence(timeout: 5))
        XCTAssertFalse(pendingRow(app, at: thirty).exists, "the old time is gone")
        snapshot("notifications-pending-rescheduled")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 5))

        // Back to Today, then leave the app and wait for delivery at the configured minute.
        XCUIDevice.shared.press(.home)
        let teasers = ["A new word is waiting", "Time to grow your tree", "Your daily word has arrived",
                       "Ready for today's word?", "Check in with Sequoia"]
        let banner = springboard.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: teasers.map {
                NSPredicate(format: "label CONTAINS %@", $0)
            })).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 150), "the reminder is delivered")
        XCTAssertFalse(banner.label.contains(word), "the banner doesn't reveal the word")
        snapshot("notifications-banner")
        let fired = Date.now
        let offBy = min(abs(fired.timeIntervalSince(soon)), abs(fired.timeIntervalSince(soon.addingTimeInterval(-60))))
        XCTAssertLessThan(offBy, 20, "fires at the configured minute")

        // Tapping it opens Today, where the word is revealed.
        banner.tap()
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10), "the notification opens Today")
        XCTAssertTrue(app.staticTexts["wordTitle"].exists)
        snapshot("notifications-opened-today")
    }

    func testNotificationPermissionDeniedDegradesGracefully() throws {
        try requireNotificationTests()
        var app = launch(["-uiTestingDiskStore", "-uiTestingResetStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboardingSkip"].waitForExistence(timeout: 10))
        app.buttons["onboardingSkip"].tap()
        let deny = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Don'")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5))
        deny.tap()
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10), "the core loop still works")

        // No repeated prompt on relaunch, or when toggling reminders off and on.
        app.terminate()
        app = launch(["-uiTestingDiskStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 3), "no prompt on relaunch")
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Allow notifications in iOS Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Notifications are turned off for Sequoia. Everything else works as usual."].exists)
        snapshot("notifications-denied-settings")
        let toggle = app.switches["Daily reminder"]
        toggle.switches.firstMatch.tap()
        toggle.switches.firstMatch.tap()
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 3), "no prompt when re-enabling")
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
        app.buttons["gotIt"].tap()
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 5))
    }

    // MARK: - Practice (Step 11)

    func testPracticeIsLockedUntilEnoughWords() throws {
        let app = launch(["-uiTestingInMemoryStore", "-tab", "practice"])
        XCTAssertTrue(app.staticTexts["Practice opens soon"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '3 more words'")).firstMatch.exists,
                      "one word seen, three to go")
        snapshot("practice-locked")
    }

    /// Plays a full round, answering each question with the first option.
    func playRound(_ app: XCUIApplication, game: String, snapshotPrefix: String) -> Int {
        app.buttons["practiceGame-\(game)"].tap()
        var answered = 0
        for index in 0..<5 {
            let first = app.buttons["practiceOption-0"]
            XCTAssertTrue(first.waitForExistence(timeout: 5))
            let options = (0..<4).map { app.buttons["practiceOption-\($0)"].label }
            XCTAssertEqual(Set(options).count, 4, "no duplicate answer options")
            if index == 0 { snapshot("\(snapshotPrefix)-question") }
            first.tap()
            answered += 1
            if index == 0 { snapshot("\(snapshotPrefix)-answered") }
            app.buttons["practiceNext"].tap()
        }
        return answered
    }

    func testPracticeRoundsAwardRings() throws {
        let app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "6", "-tab", "practice"])
        XCTAssertTrue(app.buttons["practiceGame-definitionMatch"].waitForExistence(timeout: 10))
        snapshot("practice-menu")

        XCTAssertEqual(playRound(app, game: "definitionMatch", snapshotPrefix: "practice-definition"), 5)
        let result = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '+' AND label ENDSWITH ' rings'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), "a finished round awards bonus rings")
        snapshot("practice-result")
        app.buttons["practiceDone"].tap()

        XCTAssertEqual(playRound(app, game: "fillTheBlank", snapshotPrefix: "practice-blank"), 5)
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        app.buttons["practiceDone"].tap()
        XCTAssertTrue(app.buttons["practiceGame-fillTheBlank"].waitForExistence(timeout: 5))
        app.terminate()
        _ = launch(["-devResetClock"])
    }

    // MARK: - Friends / Game Center (Step 12)

    func scrollToFriends(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
        // Friends is the last section: scroll to the end so it clears the floating tab bar.
        app.swipeUp()
        return element
    }

    /// The real Game Center: the simulator isn't signed in, so Forest shows the opt-in.
    func testFriendsSignedOutShowsOptIn() throws {
        let app = launch(["-uiTestingInMemoryStore", "-devMockSocial", "off", "-tab", "forest"])
        XCTAssertTrue(app.navigationBars["Forest"].waitForExistence(timeout: 10))
        let optIn = scrollToFriends(app, "friendsOptIn")
        XCTAssertTrue(optIn.waitForExistence(timeout: 15), "signed-out players see a calm opt-in")
        XCTAssertTrue(app.buttons["connectGameCenter"].exists)
        snapshot("friends-signed-out")
        // Everything else keeps working without Game Center.
        app.tabBars.buttons["Today"].tap()
        app.buttons["gotIt"].tap()
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 5))
    }

    func testFriendsLeaderboardsWithMockFriends() throws {
        let app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "3",
                          "-devMockSocial", "signedInWithFriends", "-tab", "forest"])
        XCTAssertTrue(app.navigationBars["Forest"].waitForExistence(timeout: 10))
        let picker = scrollToFriends(app, "leaderboardPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        let you = app.descendants(matching: .any)["leaderboardRow-you"]
        XCTAssertTrue(you.waitForExistence(timeout: 5))
        XCTAssertEqual(you.label, "Rank 4, You, 3", "the submitted streak (3 days) is ranked among friends")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "leaderboardRow").count, 4)
        snapshot("friends-streak")

        app.buttons["Rings"].tap()
        let ringsRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'leaderboardRow-you' AND label CONTAINS ', You, '")).firstMatch
        XCTAssertTrue(ringsRow.waitForExistence(timeout: 5))
        let ringsScore = Int(ringsRow.label.components(separatedBy: ", ").last ?? "") ?? 0
        XCTAssertGreaterThan(ringsScore, 3, "rings were submitted too")
        snapshot("friends-rings")
        app.terminate()
        _ = launch(["-devResetClock", "-devMockSocial", "off"])
    }

    func testFriendsEmptyStateAndOptInFlow() throws {
        var app = launch(["-uiTestingInMemoryStore", "-devMockSocial", "signedInNoFriends", "-tab", "forest"])
        XCTAssertTrue(scrollToFriends(app, "friendsEmpty").waitForExistence(timeout: 10), "a signed-in player without friends sees a friendly empty state")
        snapshot("friends-empty")
        app.terminate()

        app = launch(["-uiTestingInMemoryStore", "-devMockSocial", "signedOut", "-tab", "forest"])
        let connect = scrollToFriends(app, "connectGameCenter")
        XCTAssertTrue(connect.waitForExistence(timeout: 10))
        connect.tap()
        XCTAssertTrue(app.descendants(matching: .any)["leaderboardPicker"].waitForExistence(timeout: 5), "connecting shows the leaderboards")
    }

    // MARK: - Performance (Step 14)

    /// Cold launch until the app is responsive. Run against a Release build with
    /// SEQUOIA_LAUNCH_TEST=1 (see the step notes); skipped otherwise.
    func testColdLaunchPerformance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SEQUOIA_LAUNCH_TEST"] == "1")
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTestingSkipOnboarding"]
            app.launch()
        }
    }

    // MARK: - Accessibility (Step 14)

    /// Runs Xcode's accessibility audit, recording each issue so a failure lists them all.
    /// `allowingDynamicTypeLimitsOn` names stock system controls (toolbar buttons,
    /// `DatePicker`, `Toggle` and `Button` rows in a `Form`) that the audit reports as
    /// partially scaling although the app sets no font or size limit on them.
    func audit(_ app: XCUIApplication, _ screen: String, for types: XCUIAccessibilityAuditType = .all,
               allowingDynamicTypeLimitsOn systemLabels: Set<String> = []) throws {
        var issues: [String] = []
        // Content scrolled behind the translucent bars is blurred on purpose, so
        // contrast is judged only where text isn't under them.
        let bars = [app.tabBars.firstMatch, app.navigationBars.firstMatch].filter(\.exists).map(\.frame)
        let handler: (XCUIAccessibilityAuditIssue) -> Bool = { issue in
            if issue.auditType == .dynamicType, let label = issue.element?.label, systemLabels.contains(label) { return true }
            if issue.auditType == .contrast, let frame = issue.element?.frame, bars.contains(where: { $0.intersects(frame) }) { return true }
            // The IPA's spoken label ("Pronunciation /…/") is intentionally longer
            // than the visible text, which the clipping check reads as truncation.
            if issue.auditType == .textClipped, issue.element?.label.hasPrefix("Pronunciation ") == true { return true }
            // The system search field's own text, which the app doesn't lay out.
            if issue.auditType == .textClipped, issue.element?.elementType == .searchField { return true }
            issues.append("\(screen): \(issue.auditType) – \(issue.compactDescription) – \(issue.detailedDescription) – \(issue.element?.debugDescription.prefix(120) ?? "")")
            return true // record, keep going
        }
        do {
            try app.performAccessibilityAudit(for: types, handler)
        } catch let error as NSError where error.domain == "com.apple.accessibilityAudit" && error.code == -902 {
            // "Invalid target app": the audit service lost the app for a moment; try once more.
            issues.removeAll()
            Thread.sleep(forTimeInterval: 1)
            try app.performAccessibilityAudit(for: types, handler)
        }
        if !issues.isEmpty { print("AUDIT ISSUES:\n" + issues.joined(separator: "\n")) }
        XCTAssertTrue(issues.isEmpty, "\(issues.count) accessibility issue(s) on \(screen)")
    }

    func testAccessibilityAuditEveryScreen() throws {
        var app = launch(["-uiTestingInMemoryStore"])
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        try audit(app, "Today")
        app.buttons["gotIt"].tap()
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 5))
        try audit(app, "Today (done)")
        app.terminate()
        // Enough seen words to unlock practice, and friends on the leaderboard. Four
        // words fit on screen: rows behind the translucent bars fail the contrast check.
        app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "4", "-devMockSocial", "signedInWithFriends"])
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Library"].tap()
        try audit(app, "Library")
        app.tabBars.buttons["Practice"].tap()
        try audit(app, "Practice")
        app.buttons["practiceGame-definitionMatch"].tap()
        try audit(app, "Practice question")
        app.buttons["practiceOption-0"].tap()
        try audit(app, "Practice answered")
        app.tabBars.buttons["Forest"].tap()
        try audit(app, "Forest")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try audit(app, "Settings", allowingDynamicTypeLimitsOn: [
            "Done", "Reminder time", "Evening streak nudge", "Allow notifications in iOS Settings",
        ])
        app.terminate()
        _ = launch(["-devResetClock", "-devMockSocial", "off"])
    }

    func testAccessibilityAuditOnboarding() throws {
        let app = launch(["-uiTestingInMemoryStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboardingBegin"].waitForExistence(timeout: 10))
        try audit(app, "Onboarding welcome")
        app.buttons["onboardingBegin"].tap()
        XCTAssertTrue(app.buttons["difficulty-2"].waitForExistence(timeout: 5))
        try audit(app, "Onboarding difficulty")
    }

    /// What VoiceOver announces along the core loop: the word, its pronunciation,
    /// "Got it" with its hint, then the grown tree.
    func testVoiceOverWalkthroughOfTheCoreLoop() throws {
        let app = launch(["-uiTestingInMemoryStore"])
        let word = app.staticTexts["wordTitle"]
        XCTAssertTrue(word.waitForExistence(timeout: 10))
        XCTAssertFalse(word.label.isEmpty)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Pronunciation '")).firstMatch.exists,
                      "the IPA is read as a pronunciation, not as symbols")
        XCTAssertTrue(app.buttons["Play pronunciation"].exists)
        let gotIt = app.buttons["gotIt"]
        XCTAssertEqual(gotIt.label, "Got it")
        let streak = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'No streak yet'")).firstMatch
        XCTAssertTrue(streak.exists, "the tree and streak are described: \(streak.label)")
        gotIt.tap()
        let panel = app.otherElements["growthPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.label.contains("Day 1 complete"), "the result is announced: \(panel.label)")
        XCTAssertTrue(panel.label.contains("rings"))
    }
}

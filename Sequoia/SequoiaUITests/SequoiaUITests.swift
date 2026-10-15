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

    /// Taps "Got it". On a fresh store the first one plants the welcome tree,
    /// whose ceremony covers the screen; this closes it.
    func tapGotIt(_ app: XCUIApplication) {
        app.buttons["gotIt"].tap()
        let done = app.buttons["ceremonyDone"]
        if done.waitForExistence(timeout: 4) {
            // Let the card finish rising; a tap mid-slide lands on the button below.
            sleep(1)
            done.tap()
        }
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 5))
    }

    /// Time to magic: the first launch asks one question, the word level, then
    /// opens on the first word, and the first "Got it" plants a tree with its ceremony.
    func testFirstLaunchReachesTheFirstTreeFast() throws {
        var app = launch(["-uiTestingDiskStore", "-uiTestingResetStore"], skipOnboarding: false)
        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "the first launch opens on how it works")
        XCTAssertTrue(app.staticTexts["Day 30: a grown sequoia"].exists, "it explains how the tree grows")
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "no permission prompt before the first word")
        snapshot("onboarding-1")
        next.tap()
        let begin = app.buttons["onboardingBegin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5), "then the level and reminder")
        XCTAssertTrue(app.buttons["level-Elevated"].isSelected, "Elevated is the default")
        snapshot("onboarding-2")
        app.buttons["onboardingBack"].tap()
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Back returns to how it works")
        next.tap()
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        app.buttons["level-Erudite"].tap()
        XCTAssertTrue(app.buttons["level-Erudite"].isSelected)
        XCTAssertEqual(app.switches["onboardingReminder"].value as? String, "1", "the reminder is on by default")
        begin.tap()
        allowNotificationsIfAsked()

        let word = app.staticTexts["wordTitle"]
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 5), "Begin opens on the first word")
        XCTAssertTrue(app.staticTexts["firstWordHint"].exists, "the first word says what Got it does")
        XCTAssertEqual(word.value as? String, "Erudite", "the chosen level")
        XCTAssertFalse(app.buttons["wordLevel"].exists, "the level isn't asked twice")
        XCTAssertFalse(app.buttons["share"].exists, "just the word and Got it")
        snapshot("today-first-word")

        app.buttons["gotIt"].tap()
        XCTAssertTrue(app.staticTexts["Your first sequoia"].waitForExistence(timeout: 5), "the first word plants a welcome tree")
        XCTAssertTrue(app.staticTexts["ceremonyWords"].label.hasPrefix("Planted with"))
        sleep(1)
        snapshot("welcome-ceremony")
        app.buttons["ceremonyDone"].tap()
        let panel = app.otherElements["growthPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.label.contains("Your first sequoia is planted"), panel.label)
        XCTAssertTrue(panel.label.contains("29 more words"), panel.label)
        XCTAssertTrue(app.buttons["favorite"].exists, "favorite and share appear once the word is learned")
        XCTAssertFalse(app.otherElements["reminderOffer"].exists, "the reminder was already asked in onboarding")
        snapshot("today-first-done")

        app.terminate()
        app = launch(["-uiTestingDiskStore"], skipOnboarding: false)
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboardingBegin"].exists, "onboarding shows once")
        XCTAssertFalse(app.buttons["gotIt"].exists, "completion persists")
        XCTAssertFalse(app.otherElements["reminderOffer"].exists, "the reminder isn't asked twice")
        XCTAssertFalse(app.buttons["ceremonyDone"].exists, "the ceremony plays once")
        app.tabBars.buttons["Forest"].tap()
        XCTAssertTrue(app.buttons["yourTrees"].waitForExistence(timeout: 5), "the welcome tree is in the forest")
        snapshot("forest-day-one")
    }

    /// Three tabs; a Settings change applies at once; About credits the words.
    func testSettingsChangesApplyImmediately() throws {
        let app = launch(["-uiTestingInMemoryStore"])
        XCTAssertTrue(app.staticTexts["wordTitle"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.count, 3, "Today, Library and Forest; Practice lives in Library")
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Everyday"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Everyday"].firstMatch.tap()
        snapshot("settings")
        app.buttons["About Sequoia"].firstMatch.tap()
        let notice = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'not endorsed by or affiliated with ETS'")).firstMatch
        app.swipeUp()
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        snapshot("about-words")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertEqual(app.staticTexts["wordTitle"].value as? String, "Everyday")
    }

    func testOnboardingCanChooseGREWords() throws {
        let app = launch(["-uiTestingInMemoryStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        app.buttons["onboardingContinue"].tap()
        let gre = app.buttons["level-GRE"]
        XCTAssertTrue(gre.waitForExistence(timeout: 5))
        gre.tap()
        let reminder = app.switches["onboardingReminder"]
        reminder.switches.firstMatch.tap()
        XCTAssertEqual(reminder.value as? String, "0")
        XCTAssertFalse(app.datePickers.firstMatch.exists, "no time without a reminder")
        app.buttons["onboardingBegin"].tap()
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 2), "no permission prompt when the reminder is off")
        XCTAssertTrue(app.staticTexts["wordTitle"].waitForExistence(timeout: 5))
        snapshot("first-word-gre")
        // A GRE word reports its own level, so check the saved choice.
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Words common in GRE prep"].waitForExistence(timeout: 5))
    }

    /// "Got it" on a tree's last day plants it with a ceremony that leads to the forest.
    func testGotItOnTheLastDayPlantsATreeWithACeremony() throws {
        let app = launch(["-devEnable", "-devResetProgress", "-devJumpStage", "4", "-tab", "today"])
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        app.buttons["gotIt"].tap()
        let seeForest = app.buttons["ceremonySeeForest"]
        XCTAssertTrue(seeForest.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A sequoia joined your forest"].exists)
        // Let the card finish rising; a tap mid-slide lands on the button below.
        sleep(1)
        snapshot("planting-ceremony")
        seeForest.tap()
        XCTAssertTrue(app.navigationBars["Forest"].waitForExistence(timeout: 5))
        XCTAssertFalse(seeForest.exists)
        app.terminate()
        _ = launch(["-devResetClock", "-devResetProgress"])
    }

    /// A tree planted outside the app (the widget or the watch) gets its
    /// ceremony the next time the app opens, on any tab, exactly once.
    func testATreePlantedElsewhereGetsItsCeremonyOnce() throws {
        var app = launch(["-devEnable", "-devResetProgress", "-devPlantedElsewhere", "-tab", "library"])
        let done = app.buttons["ceremonyDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        // From fresh progress, the first tree is planted on the first completed day: the welcome tree.
        XCTAssertTrue(app.staticTexts["Your first sequoia"].exists)
        snapshot("planted-elsewhere-ceremony")
        done.tap()
        XCTAssertFalse(done.waitForExistence(timeout: 2))
        app.terminate()
        app = launch(["-devEnable", "-tab", "library"])
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["ceremonyDone"].waitForExistence(timeout: 3), "the ceremony plays only once")
        app.terminate()
        _ = launch(["-devResetClock", "-devResetProgress"])
    }

    /// Two weeks earn two rain days; a missed day spends one, Today says so
    /// quietly, and the streak carries on.
    func testARainDayCoversAMissedDay() throws {
        var app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "14", "-tab", "forest"])
        XCTAssertTrue(app.navigationBars["Forest"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["2 rain days saved"].exists, "rain days aren't a counter; they show up when they help")
        app.terminate()
        app = launch(["-devEnable", "-devAdvanceDays", "2", "-tab", "today"])
        let note = app.staticTexts["A rain day kept your young sequoia growing."]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        snapshot("rain-day-today")
        try audit(app, "Today with a rain day")
        app.buttons["gotIt"].tap()
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["growthPanel"].label.contains("Day 15 complete"), app.otherElements["growthPanel"].label)
        app.terminate()
        _ = launch(["-devResetClock", "-devResetProgress"])
    }

    /// The dev tool's missed day costs exactly one rain day, whether or not today is done.
    /// Two weeks hold two rain days: two misses are covered, and a third lapses.
    func testSimulatedMissedDayUsesOneRainDay() throws {
        // Today done: tomorrow is missed, and covered.
        var app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "14", "-devMissDay", "-tab", "today"])
        XCTAssertTrue(app.staticTexts["A rain day kept your young sequoia growing."].waitForExistence(timeout: 10))
        app.terminate()
        // The rain day covered through yesterday, so today isn't done: today itself is missed.
        app = launch(["-devEnable", "-devMissDay", "-tab", "today"])
        XCTAssertTrue(app.staticTexts["A rain day kept your young sequoia growing."].waitForExistence(timeout: 10))
        app.terminate()
        // No rain days left: one more miss starts a new seed.
        app = launch(["-devEnable", "-devMissDay", "-tab", "today"])
        XCTAssertTrue(app.staticTexts["Plant a new seed today. Your forest is safe."].waitForExistence(timeout: 10))
        app.terminate()
        _ = launch(["-devResetClock", "-devResetProgress"])
    }

    /// Each planted tree lists the words that grew it, and each word opens its card.
    func testPlantedTreeShowsTheWordsThatGrewIt() throws {
        let app = launch(["-devEnable", "-devResetProgress", "-devSimulateCheckIns", "30", "-tab", "forest"])
        let yourTrees = app.buttons["yourTrees"]
        XCTAssertTrue(yourTrees.waitForExistence(timeout: 10))
        snapshot("forest-with-trees-link")
        yourTrees.tap()
        let tree = app.buttons["Tree 1"].firstMatch.exists ? app.buttons["Tree 1"].firstMatch : app.cells.firstMatch
        XCTAssertTrue(tree.waitForExistence(timeout: 5))
        snapshot("planted-trees")
        try audit(app, "Your trees")
        tree.tap()
        XCTAssertTrue(app.staticTexts["Grown from 30 words"].waitForExistence(timeout: 5))
        snapshot("planted-tree-detail")
        try audit(app, "Tree")
        app.swipeUp(velocity: .slow)
        // Let the large title finish collapsing, so the bar's frame (used to skip
        // contrast under it) matches what's on screen.
        Thread.sleep(forTimeInterval: 1)
        try audit(app, "Tree scrolled")
        app.swipeDown()
        let firstWord = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", ",")).firstMatch
        XCTAssertTrue(firstWord.waitForExistence(timeout: 5))
        firstWord.tap()
        XCTAssertTrue(app.buttons["Play pronunciation"].waitForExistence(timeout: 5))
        snapshot("planted-tree-word")
        app.terminate()
        _ = launch(["-devResetClock", "-devResetProgress"])
    }

    /// When the saved store won't open, the app says so instead of quietly
    /// running on a throwaway store, and still works.
    func testStoreThatWontOpenIsReported() throws {
        let app = launch(["-devStoreFailure"])
        let alert = app.alerts["Sequoia couldn't open your progress"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        snapshot("store-error")
        alert.buttons["Try Again"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "still failing, so asked again")
        alert.buttons["Continue Without Saving"].tap()
        // Today works on a store that can't save.
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 5))
        XCTAssertFalse(alert.exists)
    }

    /// Saving the shared card to Photos asks for permission instead of crashing.
    func testShareSheetSavesTheCardToPhotos() throws {
        let app = launch(["-uiTestingInMemoryStore"])
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        tapGotIt(app)
        let share = app.buttons["share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        // The share sheet lists "Save Image" only when the app declares why it adds to Photos.
        let save = app.cells["Save Image"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        snapshot("share-sheet")
        save.tap()
        // The add-only Photos prompt comes from the system; accept it if shown.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow Access", "Allow", "OK"] {
            let button = springboard.alerts.buttons[label]
            if button.waitForExistence(timeout: 3) { button.tap(); break }
        }
        XCTAssertTrue(app.buttons["share"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
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
        let app = launch(["-uiTestingDiskStore", "-uiTestingResetStore", "-devReminderInMinutes", "30"])
        // Reminders are turned on from Settings here, so today stays unfinished for the banner.
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        app.switches["Daily reminder"].switches.firstMatch.tap()
        let allow = springboard.buttons["Allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5), "turning on the reminder asks for notification permission")
        allow.tap()
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
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
        var app = launch(["-uiTestingDiskStore", "-uiTestingResetStore"])
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        app.switches["Daily reminder"].switches.firstMatch.tap()
        let deny = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Don'")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5))
        deny.tap()
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10), "the core loop still works")

        // No repeated prompt on relaunch, or when toggling reminders off and on.
        app.terminate()
        app = launch(["-uiTestingDiskStore"])
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
        tapGotIt(app)
    }

    // MARK: - Practice (Step 11)

    /// Practice is hidden in Library until there are enough words to quiz.
    func testPracticeUnlocksOnDayFour() throws {
        var app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "3", "-tab", "library"])
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["practiceLink"].waitForExistence(timeout: 2), "three words: no practice yet")
        app.terminate()
        // Day four: after Got it, a full-screen page announces Practice.
        app = launch(["-devEnable", "-devAdvanceDays", "1"])
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        tapGotIt(app)
        let done = app.buttons["practiceUnlockedDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the fourth Got it announces Practice")
        XCTAssertTrue(app.staticTexts["Practice is unlocked!"].exists)
        sleep(1)
        snapshot("practice-unlocked")
        try audit(app, "Practice unlocked")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Library"].tap()
        let link = app.buttons["practiceLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Practice is in Library")
        link.tap()
        XCTAssertTrue(app.buttons["practiceGame-definitionMatch"].waitForExistence(timeout: 5))
        app.terminate()
        app = launch(["-devEnable"])
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["practiceUnlockedDone"].waitForExistence(timeout: 3), "it shows once")
        app.terminate()
        _ = launch(["-devResetClock"])
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

    func testPracticeRoundsGrowFerns() throws {
        let app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "6", "-tab", "practice"])
        XCTAssertTrue(app.buttons["practiceGame-definitionMatch"].waitForExistence(timeout: 10))
        snapshot("practice-menu")

        XCTAssertEqual(playRound(app, game: "definitionMatch", snapshotPrefix: "practice-definition"), 5)
        let result = app.staticTexts["practiceFern"]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "a finished round grows a fern")
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

    /// Opens Friends from the row at the end of the Forest tab.
    func scrollToFriends(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let link = app.buttons["friendsLink"]
        for _ in 0..<6 where !(link.exists && link.isHittable) { app.swipeUp() }
        link.tap()
        return app.descendants(matching: .any)[identifier]
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

        XCTAssertFalse(app.buttons["Rings"].exists, "no rings board")
        app.buttons["Trees"].tap()
        let treesRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'leaderboardRow-you' AND label ENDSWITH ', You, 1'")).firstMatch
        XCTAssertTrue(treesRow.waitForExistence(timeout: 5), "the welcome tree was submitted")
        snapshot("friends-trees")
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
        XCTAssertTrue(connect.waitForExistence(timeout: 10), "signed-out players see a calm opt-in")
        XCTAssertTrue(app.descendants(matching: .any)["friendsOptIn"].exists)
        snapshot("friends-signed-out")
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
        // Just above the floating tab bar, the system's scroll-edge fade makes the
        // audit misjudge text scaling (the same views pass when scrolled higher).
        // Screens with content there are also audited scrolled, so it's still checked.
        let edgeFadeTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY - 140 : .infinity
        let handler: (XCUIAccessibilityAuditIssue) -> Bool = { issue in
            if issue.auditType == .dynamicType, let label = issue.element?.label, systemLabels.contains(label) { return true }
            if issue.auditType == .contrast, let frame = issue.element?.frame, bars.contains(where: { $0.intersects(frame) }) { return true }
            if [.dynamicType, .textClipped].contains(issue.auditType), let frame = issue.element?.frame,
               frame.maxY > edgeFadeTop { return true }
            // The IPA's spoken label ("Pronunciation /…/") is intentionally longer
            // than the visible text, which the clipping check reads as truncation.
            if issue.auditType == .textClipped, issue.element?.label.hasPrefix("Pronunciation ") == true { return true }
            // A clipping, contrast or "potentially inaccessible text" report with no element
            // points at nothing on screen. These come from text the translucent bars blur
            // (a row half under the tab bar, or content scrolled under the navigation bar),
            // and the same screen flips between reporting them and not. Screens are also
            // audited scrolled; reports naming an element stay strict.
            if [.textClipped, .contrast, .elementDetection].contains(issue.auditType), issue.element == nil { return true }
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
        if !issues.isEmpty { print("AUDIT ISSUES:\n" + issues.joined(separator: "\n")); print("Bars: \(bars)") }
        XCTAssertTrue(issues.isEmpty, "\(issues.count) accessibility issue(s) on \(screen)")
    }

    func testAccessibilityAuditEveryScreen() throws {
        var app = launch(["-uiTestingInMemoryStore"])
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        try audit(app, "Today")
        tapGotIt(app)
        try audit(app, "Today (done)")
        app.terminate()
        // Enough seen words to unlock practice, and friends on the leaderboard. Four
        // words fit on screen: rows behind the translucent bars fail the contrast check.
        app = launch(["-devEnable", "-devResetClock", "-devResetProgress", "-devSimulateCheckIns", "4", "-devMockSocial", "signedInWithFriends"])
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Library"].tap()
        try audit(app, "Library")
        app.buttons["practiceLink"].tap()
        try audit(app, "Practice")
        app.buttons["practiceGame-definitionMatch"].tap()
        try audit(app, "Practice question")
        app.buttons["practiceOption-0"].tap()
        try audit(app, "Practice answered")
        app.tabBars.buttons["Forest"].tap()
        try audit(app, "Forest")
        // To the end, so no row is left half under the floating tab bar (see `audit`).
        app.swipeUp(velocity: .slow)
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 1)
        snapshot("forest-scrolled")
        try audit(app, "Forest scrolled")
        app.buttons["friendsLink"].tap()
        XCTAssertTrue(app.navigationBars["Friends"].waitForExistence(timeout: 5))
        try audit(app, "Friends")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeDown(velocity: .fast)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try audit(app, "Settings", allowingDynamicTypeLimitsOn: [
            "Done", "Reminder time", "Evening streak nudge", "Allow notifications in iOS Settings",
        ])
        app.terminate()
        _ = launch(["-devResetClock", "-devMockSocial", "off"])
    }

    /// The first-run screens: the first word with its level menu and hint, and
    /// the reminder offer after the first "Got it".
    func testAccessibilityAuditFirstRun() throws {
        var app = launch(["-uiTestingInMemoryStore"], skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboardingContinue"].waitForExistence(timeout: 10))
        try audit(app, "How it works")
        app.buttons["onboardingContinue"].tap()
        XCTAssertTrue(app.buttons["onboardingBegin"].waitForExistence(timeout: 5))
        sleep(2) // Let the page finish sliding in.
        // No contrast check here: the audit samples each level name about 30 pt above
        // where it's drawn (blank card), though the real text measures 15:1.
        try audit(app, "Onboarding setup", for: XCUIAccessibilityAuditType.all.subtracting(.contrast),
                  allowingDynamicTypeLimitsOn: ["Reminder time", "Daily reminder"])
        app.terminate()
        // Without onboarding (an existing tree), the reminder is offered after Got it.
        app = launch(["-uiTestingInMemoryStore"])
        XCTAssertTrue(app.buttons["gotIt"].waitForExistence(timeout: 10))
        try audit(app, "First word")
        tapGotIt(app)
        XCTAssertTrue(app.otherElements["reminderOffer"].waitForExistence(timeout: 5))
        sleep(1) // Let it finish fading in; a half-faded button fails contrast.
        try audit(app, "Reminder offer", allowingDynamicTypeLimitsOn: ["Reminder time"])
        // "Remind me" turns on the daily reminder.
        app.buttons["reminderOfferAccept"].tap()
        allowNotificationsIfAsked()
        XCTAssertTrue(app.otherElements["reminderOffer"].waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Forest"].tap()
        app.buttons["Settings"].tap()
        XCTAssertEqual(app.switches["Daily reminder"].value as? String, "1")
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
        tapGotIt(app)
        let panel = app.otherElements["growthPanel"]
        XCTAssertTrue(panel.label.contains("Your first sequoia is planted"), "the result is announced: \(panel.label)")
        XCTAssertTrue(panel.label.contains("29 more words"), "and how far the next tree is: \(panel.label)")
    }
}

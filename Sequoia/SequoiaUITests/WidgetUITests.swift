import XCTest

/// Step 10: the widgets on a real Home Screen. Adds widgets through SpringBoard, so
/// it runs only on a fresh install with SEQUOIA_WIDGET_TESTS=1:
///   xcrun simctl uninstall booted app.sequoia.Sequoia
///   TEST_RUNNER_SEQUOIA_WIDGET_TESTS=1 xcodebuild test ... -only-testing:SequoiaUITests/WidgetUITests
@MainActor
final class WidgetUITests: XCTestCase {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SEQUOIA_WIDGET_TESTS"] == "1",
                          "Widget tests run only on a fresh install with SEQUOIA_WIDGET_TESTS=1")
    }

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

    /// Widgets read the developer store, which the App Group shares with them.
    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-devEnable", "-uiTestingSkipOnboarding"] + extra
        app.launch()
        return app
    }

    /// Adds a Sequoia widget from the gallery; `page` 0 is small, 1 is medium.
    func addWidget(page: Int) {
        enterEditMode()
        springboard.buttons["Edit"].tap()
        springboard.buttons["Add Widget"].firstMatch.tap()
        let search = springboard.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Sequoia")
        let result = springboard.cells.matching(NSPredicate(format: "label CONTAINS 'Sequoia'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), "the widget extension is registered")
        result.tap()
        let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        sleep(1) // let the size picker settle before paging
        for _ in 0..<page {
            let preview = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.58))
            preview.press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.58)))
            sleep(1)
        }
        add.tap()
        let done = springboard.buttons["Done"]
        if done.waitForExistence(timeout: 3) { done.tap() }
    }

    func element(labeled label: String) -> XCUIElement {
        springboard.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Enters Home Screen edit mode, from empty space or, if a widget is
    /// there, from its context menu.
    func enterEditMode() {
        XCUIDevice.shared.press(.home)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.74)).press(forDuration: 1.5)
        let editHome = element(labeled: "Edit Home Screen")
        if editHome.waitForExistence(timeout: 2) { editHome.tap() }
        XCTAssertTrue(springboard.buttons["Edit"].waitForExistence(timeout: 5))
    }

    /// Removes Sequoia widgets left on the Home Screen by earlier runs.
    func removeExistingWidgets() {
        XCUIDevice.shared.press(.home)
        sleep(1)
        for _ in 0..<8 {
            let widgets = springboard.icons.matching(identifier: "Sequoia").allElementsBoundByIndex
                .filter { ($0.value as? String) == "Widget" && $0.frame.width > 100 }
            print("Removing \(widgets.count) leftover widgets")
            guard let widget = widgets.first else { break }
            widget.press(forDuration: 1.2)
            let remove = element(labeled: "Remove Widget")
            guard remove.waitForExistence(timeout: 3) else { break }
            remove.tap()
            let confirm = element(labeled: "Remove")
            if confirm.waitForExistence(timeout: 3) { confirm.tap() }
            sleep(1)
        }
        XCUIDevice.shared.press(.home)
    }

    /// Goes to the Home Screen page that holds the Sequoia widgets.
    func showWidgetsPage() {
        XCUIDevice.shared.press(.home)
        sleep(1)
        XCUIDevice.shared.press(.home) // a second press returns to the first page
        sleep(1)
        let widget = springboard.icons.matching(identifier: "Sequoia").allElementsBoundByIndex
            .first { ($0.value as? String) == "Widget" }
        for _ in 0..<3 where !(widget?.isHittable ?? true) {
            springboard.swipeLeft()
            sleep(1)
        }
    }

    func homeScreenElement(containing text: String) -> XCUIElement {
        springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testWidgetsMatchTheAppUpdateAndDeepLink() throws {
        // The same word and tree as the app.
        var app = launch(["-devResetClock", "-devResetProgress"])
        let title = app.staticTexts["wordTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let word = title.label
        removeExistingWidgets()
        addWidget(page: 0)
        addWidget(page: 1)
        showWidgetsPage()
        // SpringBoard exposes the medium widget's text; the small one shows in the screenshot.
        XCTAssertTrue(springboard.staticTexts[word].waitForExistence(timeout: 10), "widgets show today's word")
        XCTAssertTrue(homeScreenElement(containing: "No streak yet").exists, "and the seed")
        XCTAssertTrue(springboard.buttons["Got it"].exists, "the medium widget offers Got it")
        snapshot("widgets-home")

        // A check-in in the app updates the widgets.
        app.activate()
        let gotIt = app.buttons["gotIt"]
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: gotIt)
        wait(for: [hittable], timeout: 5)
        gotIt.tap()
        XCTAssertTrue(app.otherElements["growthPanel"].waitForExistence(timeout: 5))
        showWidgetsPage()
        XCTAssertTrue(homeScreenElement(containing: "Done for today").waitForExistence(timeout: 15), "medium widget shows the check-in")
        XCTAssertTrue(homeScreenElement(containing: "day 1 of your streak").exists)
        snapshot("widgets-after-check-in")

        // A new day (simulated) brings the next word to the widgets.
        app.terminate()
        app = launch(["-devAdvanceDays", "1", "-tab", "library"])
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Today"].tap()
        let nextWord = app.staticTexts["wordTitle"].label
        XCTAssertNotEqual(nextWord, word)
        app.tabBars.buttons["Library"].tap()
        showWidgetsPage()
        let next = springboard.staticTexts[nextWord].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 15), "widgets show the next day's word")
        snapshot("widgets-next-day")

        // Tapping a widget opens Today, even from another tab.
        next.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.staticTexts["wordTitle"].waitForExistence(timeout: 5), "deep link opens Today")
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
        snapshot("widgets-deep-link")

        app.terminate()
        _ = launch(["-devResetClock"])
    }

    /// Captures the widgets page as it is (run after the test above, in light and dark).
    func testCaptureWidgetsPage() throws {
        let name = try XCTUnwrap(ProcessInfo.processInfo.environment["SEQUOIA_CAPTURE_NAME"])
        showWidgetsPage()
        sleep(2)
        snapshot(name)
    }

    // MARK: - Lock Screen

    /// Backs out of anything an earlier failed run left open in SpringBoard:
    /// locking the device ends any editing session.
    func resetSpringBoard() {
        lockAndWake()
        XCUIDevice.shared.press(.home)
        sleep(1)
    }

    func lockAndWake() {
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
    }

    /// Drags the widget picker sheet down and away.
    func dismissPickerSheet() {
        let close = springboard.buttons["close"].firstMatch
        if close.exists { close.tap(); sleep(1) }
        let grabber = springboard.buttons["Sheet Grabber"].firstMatch
        if grabber.exists {
            grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99)))
        }
        sleep(2)
    }

    /// Scrolls a widget picker sheet to Sequoia and opens it.
    @discardableResult
    func pickSequoia() -> Bool {
        let sequoia = springboard.cells.matching(NSPredicate(format: "label == 'Sequoia'")).firstMatch
        for _ in 0..<5 where !(sequoia.exists && sequoia.isHittable) {
            guard springboard.cells.firstMatch.exists else { break }
            springboard.cells.firstMatch.swipeUp()
            sleep(1)
        }
        guard sequoia.waitForExistence(timeout: 3) else { return false }
        sequoia.tap()
        sleep(2)
        return true
    }

    func testLockScreenWidgets() throws {
        resetSpringBoard()
        let app = launch(["-devResetClock", "-devResetProgress"])
        let title = app.staticTexts["wordTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let word = title.label

        lockAndWake()
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 2)
        let customize = springboard.buttons["posterboard-customize-button"]
        XCTAssertTrue(customize.waitForExistence(timeout: 5))
        customize.tap()
        let slots = springboard.buttons.matching(identifier: "grouped-widgets-reticle-view").firstMatch
        XCTAssertTrue(slots.waitForExistence(timeout: 10))
        sleep(2)

        // Rectangular (the word) and circular (the streak), unless an earlier run
        // already placed them (SpringBoard doesn't expose their remove buttons).
        let placedWord = springboard.buttons.matching(identifier: "app.sequoia.Sequoia.WidgetExtension:WordWidget").firstMatch
        let placedStreak = springboard.buttons.matching(identifier: "app.sequoia.Sequoia.WidgetExtension:StreakWidget").firstMatch
        if !(placedWord.exists && placedStreak.exists) {
            slots.tap()
            sleep(2)
            XCTAssertTrue(pickSequoia(), "Sequoia is listed in the Lock Screen widget picker")
            let rectangular = springboard.buttons["Sequoia, Today's word"]
            XCTAssertTrue(rectangular.waitForExistence(timeout: 5), "the rectangular word widget is offered")
            if !placedWord.exists { rectangular.tap(); sleep(1) }
            let circular = springboard.buttons["Sequoia, Streak"]
            XCTAssertTrue(circular.exists, "the circular streak widget is offered")
            if !placedStreak.exists {
                if !circular.isHittable {
                    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.69))
                        .press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.69)))
                    sleep(1)
                }
                circular.tap()
                sleep(1)
            }
            dismissPickerSheet()
        }
        XCTAssertTrue(placedWord.exists && placedStreak.exists, "both widgets are on the Lock Screen")
        snapshot("lock-editing-widgets")

        // Inline, above the clock. SpringBoard's editor is less predictable here,
        // so this part only records what it shows.
        let inlineSlot = springboard.buttons.matching(identifier: "inline-widget-reticle-view").firstMatch
        if inlineSlot.waitForExistence(timeout: 3) {
            inlineSlot.tap()
            sleep(2)
            let inlineRow = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", word)).firstMatch
            for _ in 0..<4 where !(inlineRow.exists && inlineRow.isHittable) {
                springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                    .press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
                sleep(1)
            }
            snapshot("lock-inline-picker")
            if inlineRow.exists && inlineRow.isHittable { inlineRow.tap(); sleep(1) }
            dismissPickerSheet()
        }

        springboard.buttons["editing-done"].tap()
        sleep(2)
        let done = springboard.descendants(matching: .any).matching(NSPredicate(format: "label == 'Done'")).firstMatch
        if done.waitForExistence(timeout: 2) { done.tap() }
        lockAndWake()
        XCTAssertTrue(springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", word))
            .firstMatch.waitForExistence(timeout: 10), "the Lock Screen shows today's word")
        snapshot("lock-screen-widgets")
    }
}

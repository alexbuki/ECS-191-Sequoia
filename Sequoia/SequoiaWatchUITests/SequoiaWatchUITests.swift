import XCTest

/// Step 13 on the paired watch simulator. The phone app should be running with
/// a fresh store first, so the watch starts on an unfinished day.
@MainActor
final class SequoiaWatchUITests: XCTestCase {
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

    func testGotItOnTheWatch() throws {
        let app = XCUIApplication()
        app.launch()
        let word = app.staticTexts["watchWord"]
        XCTAssertTrue(word.waitForExistence(timeout: 10))
        snapshot("watch-before")
        let gotIt = app.buttons["watchGotIt"]
        for _ in 0..<3 where !gotIt.isHittable { app.swipeUp() }
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5), "today is not done yet")
        gotIt.tap()
        XCTAssertTrue(app.staticTexts["watchDone"].waitForExistence(timeout: 5) || app.descendants(matching: .any)["watchDone"].waitForExistence(timeout: 2))
        snapshot("watch-after")
    }

    /// Adds a Siri Modular face and puts the Sequoia complication on it. Changes
    /// the simulator's faces, so it runs only with SEQUOIA_FACE_TEST=1.
    func testComplicationOnAWatchFace() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SEQUOIA_FACE_TEST"] == "1")
        let carousel = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        func labeled(_ label: String) -> XCUIElement {
            carousel.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }

        // Use a Siri Modular face (it has complication slots), adding one if needed.
        // The crown toggles between the face and the app grid: press until the face shows.
        let face = carousel.otherElements["Watch Face"]
        for _ in 0..<3 {
            XCUIDevice.shared.press(.home)
            sleep(2)
            if face.exists && face.isHittable { break }
        }
        XCTAssertTrue(face.exists, "on the watch face")
        let modular = carousel.scrollViews.matching(NSPredicate(format: "label BEGINSWITH 'siri modular'")).firstMatch
        carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.5)
        sleep(3)
        if modular.exists {
            let edit = carousel.buttons["Edit"]
            XCTAssertTrue(edit.waitForExistence(timeout: 5))
            edit.tap()
        } else {
            let addFace = carousel.scrollViews["Add new face"]
            for _ in 0..<10 where !addFace.exists {
                carousel.swipeLeft()
                sleep(1)
            }
            XCTAssertTrue(addFace.waitForExistence(timeout: 5))
            addFace.tap()
            let category = carousel.buttons["New Watch Faces"].firstMatch
            XCTAssertTrue(category.waitForExistence(timeout: 5))
            category.tap()
            let add = carousel.buttons.matching(NSPredicate(format: "label == 'Add'")).firstMatch
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            add.tap()
        }

        // The editor opens; page to the complications and choose Sequoia for a slot.
        let slot = carousel.buttons["Bottom Middle complication"]
        XCTAssertTrue(slot.waitForExistence(timeout: 10))
        for _ in 0..<5 where !slot.isHittable {
            carousel.swipeLeft()
            sleep(1)
        }
        slot.tap()
        sleep(2)
        // The picker opens on the slot's current app; go back to the list of apps.
        let back = carousel.buttons.matching(NSPredicate(format: "label == 'Back' OR identifier == 'BackButton'")).firstMatch
        if back.exists { back.tap(); sleep(2) }
        let sequoia = labeled("Sequoia")
        let screen = carousel.frame
        func inView() -> Bool {
            sequoia.exists && sequoia.frame.minY > screen.height * 0.3 && sequoia.frame.maxY < screen.height * 0.9
        }
        // Scroll in short drags so the row lands mid-screen, clear of the close button.
        for _ in 0..<30 where !inView() {
            let up = !sequoia.exists || sequoia.frame.minY > screen.height * 0.5
            let from = carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.7 : 0.4))
            from.press(forDuration: 0.05, thenDragTo: carousel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.45 : 0.6)))
            sleep(1)
        }
        XCTAssertTrue(inView(), "Sequoia is offered as a complication")
        snapshot("watch-complication-picker")
        sequoia.tap()
        sleep(2)
        snapshot("watch-complication-options")
        // The app's complications are listed under its name; take the first row
        // (below the title, which carries the same label).
        let row = carousel.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Sequoia'"))
            .allElementsBoundByIndex.first { $0.isHittable && $0.frame.minY > screen.height * 0.25 }
        XCTAssertNotNil(row, "the Sequoia complication is listed")
        row?.tap()
        sleep(2)
        XCUIDevice.shared.press(.home) // leave the editor
        sleep(2)
        XCUIDevice.shared.press(.home) // back to the face
        sleep(3)

        let complication = carousel.descendants(matching: .any).matching(identifier: "bottom-center").firstMatch
        XCTAssertTrue(complication.waitForExistence(timeout: 10))
        print("Bottom-center complication: \(complication.label)")
        XCTAssertNotEqual(complication.label, "Siri", "the face shows the Sequoia complication")
        XCTAssertTrue(complication.label.contains("streak") || complication.label.contains("seed") || complication.label.contains("Sequoia"))
        snapshot("watch-face-complication")
    }
}

# Sequoia: Daily Vocab

Project page: https://second-paperback-0e4.notion.site/ECS-191-Homework-Clone-3ea075d65b0980d88036d080299d30ad

One word a day. Each one grows your tree.

Sequoia is an iPhone app (with widgets and an Apple Watch companion) that shows one vocabulary word each day. Marking it learned grows a sequoia; keep the streak going for 30 days and the tree is planted in your forest.

## Building

**Requirements:** Xcode 26 or later, iOS 17+ (iPhone), watchOS 10+ (optional).

1. Open `Sequoia/Sequoia.xcodeproj` in Xcode.
2. Select the **Sequoia** scheme and an iPhone simulator, then press **Run** (⌘R).

To run on your own iPhone:

1. In Xcode, select the project, then under **Signing & Capabilities** choose your team for each target.
2. Choose your iPhone as the run destination and press **Run**.
3. The first time, trust the developer certificate on the phone: **Settings → General → VPN & Device Management**.

## Testing the app
- **Developer mode** (Debug builds only): **Settings → Developer** lets you simulate days passing, jump tree stages, fill the forest, fire a notification now, reload widgets and use mock Game Center friends. A yellow **DEV** badge turns on while active
- **Tests:** press ⌘U with the Sequoia scheme to run the unit tests, UI tests and package tests. The watch tests use the **SequoiaWatch** scheme.

## Using the app

- **Today:** today's word with its pronunciation (tap the speaker to hear it), definition, examples and origin. Tap **Got it** to complete the day, or **I already knew this**. The heart saves the word to favorites; the share button makes an image card.
- **Your tree:** each day you complete grows the tree: Seed, Sprout, Sapling, Young sequoia, then Grown sequoia at day 30, when it's planted in your forest. Missing a day starts a new seed; your forest and rings are never lost.
- **Library:** every word you've seen, newest first. Search by word or definition, or switch to **Favorites**. Tap a word for its full card.
- **Practice:** once you've seen four words, play short rounds of **Definition Match** or **Fill the Blank** to earn extra rings.
- **Forest:** your planted trees, current and longest streak, words learned, rings and a calendar of completed days. **Friends** (optional) compares streaks, trees and rings with Game Center friends.
- **Settings** (gear icon in Forest): word difficulty, a daily reminder time and an evening streak nudge. Notifications are teasers that keep the word a surprise; tap one to open Today and see the word.
- **Widgets:** add Sequoia to the Home Screen (word and streak widgets) or Lock Screen. The medium widget has a **Got it** button.
- **Apple Watch:** shows today's word with a **Got it** button, plus watch-face complications. It stays in sync with the iPhone.



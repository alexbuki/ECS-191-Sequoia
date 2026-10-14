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
- **Developer mode** (Debug builds only): **Settings → Developer** lets you simulate days passing or a missed day, grant rain days, mark words as missed in practice, jump tree stages, fill the forest, preview the tree-planting moment, fire a notification now, reload widgets and use mock Game Center friends. A yellow **DEV** badge turns on while active
- **Tests:** press ⌘U with the Sequoia scheme to run the unit tests, UI tests and package tests. The watch tests use the **SequoiaWatch** scheme.

## Using the app

- **First launch:** one welcome screen, then **Begin** goes straight to your first word. You can change the word's level right there. Your first **Got it** plants a welcome sequoia in your forest, and afterwards Sequoia offers a daily reminder.
- **Today:** today's word with its pronunciation (tap the speaker to hear it), definition, examples and origin. Tap **Got it** to complete the day. Words never repeat until you've seen every word at your level (over 370 each). Once the day is done, the heart saves the word to favorites and the share button makes an image card.
- **Your tree:** each day you complete grows the tree. Your first word sprouts the seed, then it becomes a Sapling (day 7), a Young sequoia (day 14) and a Grown sequoia (day 30), when it's planted in your forest with a short celebration. Your forest grows behind today's word. Every 7 days in a row quietly earns a **rain day** (you can hold 2). When a rain day covers a missed day, Today tells you, and your streak and tree keep going. Missing more days than your rain days cover starts a new seed; your forest is never lost.
- **Library:** every word you've seen, newest first. Search by word or definition, or switch to **Favorites**. Tap a word for its full card.
- **Practice** (in Library): once you've seen four words, play short rounds of **Definition Match** or **Fill the Blank**. Words you miss come back first in later rounds, each game keeps your best score, and every round grows a fern in your forest.
- **Forest:** your planted trees in a misty grove that follows the time of day, with ferns for practice rounds and wildflowers for favorite words. **Your trees** lists every tree and the 30 words that grew it. Also your current and longest streak, words learned, trees planted and a calendar of completed days. **Friends** (optional) compares streaks and trees with Game Center friends.
- **Settings** (gear icon in Forest): word difficulty, a daily reminder time and an evening streak nudge. Notifications are teasers that keep the word a surprise; tap one to open Today and see the word.
- **Widgets:** add Sequoia to the Home Screen (word and streak widgets) or Lock Screen. The medium widget has a **Got it** button; on the day your tree is fully grown it becomes **Plant your sequoia** and opens the app, so you see the planting there. The watch does the same.
- **Apple Watch:** shows today's word with a **Got it** button, plus watch-face complications. It stays in sync with the iPhone.



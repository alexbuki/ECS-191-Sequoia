import DesignSystem
import SequoiaCore

extension SequoiaStore {
    /// The forest's light right now, by the app clock.
    var forestLight: ForestLight {
        _ = revision
        let clock = currentClock
        let parts = clock.calendar.dateComponents([.hour, .minute], from: clock.now())
        return ForestLight(hour: Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60)
    }

    /// Ferns for practice rounds and wildflowers for favorite words.
    var undergrowth: Undergrowth {
        _ = revision
        return Undergrowth(ferns: practiceRounds, flowers: seenWords().filter(\.isFavorite).count)
    }
}

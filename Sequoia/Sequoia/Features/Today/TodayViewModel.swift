import SwiftUI
import Observation
import SequoiaCore
import DesignSystem

/// State and actions for the Today screen: the core loop.
@MainActor
@Observable
final class TodayViewModel {
    let store: SequoiaStore

    /// The most recent check-in this session, for the growth animation.
    private(set) var lastOutcome: CheckInOutcome?
    /// Incremented on each check-in, to trigger the light haptic.
    private(set) var checkInCount = 0
    /// Incremented when a tree is planted, to trigger the richer haptic.
    private(set) var plantedCount = 0
    private(set) var shareImage: Image?

    init(store: SequoiaStore) {
        self.store = store
    }

    var word: Word { store.todayWord }
    var isCompleted: Bool { store.todayCompleted }
    var stage: TreeStage { store.stage }
    var streak: Int { store.growth.currentStreak }
    var today: DayStamp { store.today }

    var isFavorite: Bool {
        _ = store.revision
        return store.isFavorite(word.id)
    }

    /// True when a past streak lapsed and today hasn't been completed yet.
    var showsFreshStartMessage: Bool {
        !isCompleted && streak == 0 && store.growth.longestStreak > 0
    }

    /// The stage to draw in the growth panel: a planted tree is shown fully
    /// grown before the new seed appears.
    var displayedStage: TreeStage {
        if let lastOutcome, lastOutcome.plantedTree { return .grownSequoia }
        return stage
    }

    var dateTitle: String {
        today.startDate(in: store.currentClock.calendar)
            .formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    func gotIt() { checkIn(knewIt: false) }

    func alreadyKnewIt() { checkIn(knewIt: true) }

    func toggleFavorite() {
        store.toggleFavorite(word.id)
    }

    func speak() {
        PronunciationPlayer.shared.speak(word.word)
    }

    /// Renders the share card for the current word and streak.
    func prepareShareImage() {
        shareImage = ShareRenderer.wordCard(word: word, stage: stage, streak: streak).map(Image.init(uiImage:))
    }

    private func checkIn(knewIt: Bool) {
        guard case .checkedIn(let outcome) = store.checkIn(knewIt: knewIt) else { return }
        lastOutcome = outcome
        checkInCount += 1
        if outcome.plantedTree { plantedCount += 1 }
        prepareShareImage()
    }
}

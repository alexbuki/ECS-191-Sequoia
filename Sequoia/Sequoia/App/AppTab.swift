import Foundation

/// The three top-level destinations. Practice lives inside Library: it
/// reviews the words you've learned.
enum AppTab: String, Hashable, CaseIterable {
    case today, library, forest
}

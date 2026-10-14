import Foundation
import SwiftData

/// Builds the SwiftData container in the shared App Group, so the widget and
/// watch extensions read the same store as the app.
public enum Persistence {
    public static let schema = Schema([
        WordRecord.self, DayRecord.self, PlantedTreeRecord.self, ProgressRecord.self, SettingsRecord.self,
    ])

    public enum Location: Sendable, Equatable {
        /// The user's real data.
        case standard
        /// Simulated progress for developer mode, kept apart from real data.
        case developer
        /// Throwaway, for tests, previews and UI tests.
        case inMemory
        /// An on-disk store used only by UI tests, so relaunches can be tested
        /// without touching real data.
        case uiTesting
    }

    /// The store the app should use right now.
    public static var currentLocation: Location {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingInMemoryStore") { return .inMemory }
        if arguments.contains("-uiTestingDiskStore") { return .uiTesting }
        #if SEQUOIA_DEV
        if DevMode.isEnabled { return .developer }
        #endif
        return .standard
    }

    public static func storeURL(for location: Location) -> URL? {
        switch location {
        case .standard: AppGroup.containerURL.appending(path: "Sequoia.store")
        case .developer: AppGroup.containerURL.appending(path: "Sequoia-dev.store")
        case .uiTesting: AppGroup.containerURL.appending(path: "Sequoia-uitest.store")
        case .inMemory: nil
        }
    }

    /// Deletes a store's files (used to reset the UI-testing store).
    public static func destroyStore(_ location: Location) {
        guard let url = storeURL(for: location) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let file = url.deletingLastPathComponent().appending(path: url.lastPathComponent + suffix)
            try? FileManager.default.removeItem(at: file)
        }
    }

    public static func makeContainer(_ location: Location = currentLocation) throws -> ModelContainer {
        if location == .uiTesting, ProcessInfo.processInfo.arguments.contains("-uiTestingResetStore") {
            destroyStore(.uiTesting)
        }
        let configuration: ModelConfiguration
        if let url = storeURL(for: location) {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Thrown by `-devStoreFailure`, to test what the app does when its store won't open.
    public struct SimulatedFailure: Error {}

    /// The store for `location`, or a throwaway in-memory one plus the error when
    /// the disk store won't open, so the app can say its changes aren't being saved.
    public static func openContainer(_ location: Location = currentLocation) -> (container: ModelContainer, error: (any Error)?) {
        do {
            #if SEQUOIA_DEV
            if ProcessInfo.processInfo.arguments.contains("-devStoreFailure"), location != .inMemory { throw SimulatedFailure() }
            #endif
            return (try makeContainer(location), nil)
        } catch {
            guard let container = try? makeContainer(.inMemory) else {
                preconditionFailure("SwiftData could not create even an in-memory store: \(error)")
            }
            return (container, error)
        }
    }

    /// A container that always succeeds, falling back to memory if the disk store fails.
    public static func makeContainerOrFallback(_ location: Location = currentLocation) -> ModelContainer {
        openContainer(location).container
    }
}

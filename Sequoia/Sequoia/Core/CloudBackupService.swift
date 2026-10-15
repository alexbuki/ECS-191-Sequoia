import Foundation
import SequoiaCore

/// Keeps a copy of the user's progress in iCloud key-value storage, and restores
/// it on a fresh install (a new iPhone, or after the app was deleted).
///
/// The backup with more check-ins wins: a fresh install restores a richer backup,
/// and a device never overwrites a richer backup with less progress. Resetting
/// progress clears the backup, so the reset isn't undone.
@MainActor
final class CloudBackupService {
    weak var app: AppModel?
    private let cloud = NSUbiquitousKeyValueStore.default
    private static let key = "backup.v1"
    private var lastSaved: Data?

    /// Only the real store is backed up, never developer or UI-testing data.
    private var isEnabled: Bool { Persistence.currentLocation == .standard && app?.hasStoreError == false }

    func activate() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restoreIfRicher() }
        }
        cloud.synchronize()
        restoreIfRicher()
    }

    /// Restores the iCloud backup when it has more check-ins than this device.
    func restoreIfRicher() {
        guard isEnabled, let app, let backup = cloudBackup,
              backup.totalCheckIns > app.store.growth.totalCheckIns else { return }
        app.store.restore(backup)
        app.storeDidChange()
    }

    /// Saves the current progress, unless iCloud already holds more.
    func save() {
        guard isEnabled, let store = app?.store else { return }
        let backup = store.makeBackup()
        guard backup.totalCheckIns > 0, backup.totalCheckIns >= (cloudBackup?.totalCheckIns ?? 0),
              let data = try? backup.encoded(), data != lastSaved else { return }
        cloud.set(data, forKey: Self.key)
        lastSaved = data
    }

    /// Forgets the backup, after the user resets their progress.
    func clear() {
        cloud.removeObject(forKey: Self.key)
        lastSaved = nil
    }

    private var cloudBackup: Backup? {
        cloud.data(forKey: Self.key).flatMap { try? Backup(decoding: $0) }
    }
}

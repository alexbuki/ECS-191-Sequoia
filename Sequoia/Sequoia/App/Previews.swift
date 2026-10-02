import Foundation
import SequoiaCore

extension AppModel {
    /// An app model backed by an in-memory store, for previews.
    static var preview: AppModel { AppModel(store: .preview) }
}

extension SequoiaStore {
    /// An in-memory store for previews.
    static var preview: SequoiaStore {
        SequoiaStore(container: Persistence.makeContainerOrFallback(.inMemory))
    }
}

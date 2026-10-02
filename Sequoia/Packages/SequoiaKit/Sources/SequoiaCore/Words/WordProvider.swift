import Foundation

/// A source of words. The bundled, curated JSON is the first implementation;
/// a remote or curated feed can be swapped in later without UI changes.
public protocol WordProvider: Sendable {
    /// Every available word, in a stable order.
    var words: [Word] { get }
    /// Looks up a word by its identifier.
    func word(id: String) -> Word?
}

/// Words bundled with the app as curated JSON. Works fully offline.
public struct BundledWordProvider: WordProvider {
    public let words: [Word]
    private let index: [String: Word]

    public init(words: [Word]) {
        self.words = words
        self.index = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Decodes the curated `Words.json` bundled with `SequoiaCore`.
    public init() throws {
        try self.init(bundle: .module, resource: "Words")
    }

    /// Decodes a words JSON file from the given bundle.
    public init(bundle: Bundle, resource: String) throws {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        self.init(words: try JSONDecoder().decode([Word].self, from: data))
    }

    /// The shared bundled library, decoded once.
    public static let shared: BundledWordProvider = {
        (try? BundledWordProvider()) ?? BundledWordProvider(words: [.sample])
    }()

    public func word(id: String) -> Word? { index[id] }
}

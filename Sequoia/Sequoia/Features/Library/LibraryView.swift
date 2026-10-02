import SwiftUI
import DesignSystem
import SequoiaCore

struct LibraryView: View {
    @State private var model: LibraryViewModel

    init(store: SequoiaStore) {
        _model = State(initialValue: LibraryViewModel(store: store))
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Group {
                if model.allWords.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .sequoiaScreen()
            .navigationTitle("Library")
            .navigationDestination(for: SeenWord.self) { entry in
                WordDetailView(store: model.store, word: entry.word)
            }
        }
    }

    private var list: some View {
        @Bindable var model = model
        return List {
            Section {
                Picker("Show", selection: $model.filter) {
                    ForEach(LibraryViewModel.Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                // A plain row rather than a section footer, which doesn't scale with Dynamic Type.
                Text("\(model.allWords.count) words learned so far")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.xxs, bottom: 0, trailing: 0))
            }

            if model.visibleWords.isEmpty {
                Section {
                    CalmEmptyState(
                        model.filter == .favorites && model.searchText.isEmpty ? "No favorites yet" : "No matches",
                        message: model.filter == .favorites && model.searchText.isEmpty
                            ? "Tap the heart on any word to keep it here."
                            : "Try a different word or part of a definition.",
                        systemImage: model.filter == .favorites ? "heart" : "magnifyingglass"
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(model.visibleWords) { entry in
                        NavigationLink(value: entry) {
                            LibraryRow(entry: entry, dateLabel: model.dateLabel(for: entry))
                        }
                        .listRowBackground(Theme.Palette.surface)
                        .accessibilityIdentifier("libraryRow")
                        .swipeActions(edge: .trailing) {
                            Button {
                                model.toggleFavorite(entry)
                            } label: {
                                Label(entry.isFavorite ? "Unfavorite" : "Favorite", systemImage: entry.isFavorite ? "heart.slash" : "heart")
                            }
                            .tint(Theme.Palette.bark)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $model.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search your words"))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            TreeView(stage: .sprout).frame(height: 110)
            CalmEmptyState("Your library starts today",
                           message: "Every word you learn gathers here, so you can revisit it anytime.",
                           systemImage: "books.vertical")
        }
        .frame(maxHeight: .infinity)
    }
}

struct LibraryRow: View {
    let entry: SeenWord
    let dateLabel: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text(entry.word.word)
                        .font(Typography.wordTitle)
                        .foregroundStyle(Theme.Palette.soil)
                    Text(entry.word.partOfSpeech.title)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.bark)
                }
                Text(entry.word.definition)
                    .font(Typography.callout)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(dateLabel)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.soilSecondary)
                if entry.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.Palette.bark)
                        .accessibilityLabel("Favorite")
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

/// A past word's full card.
struct WordDetailView: View {
    let store: SequoiaStore
    let word: Word
    @State private var shareImage: Image?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                WordCard(word: word) {
                    Button {
                        PronunciationPlayer.shared.speak(word.word)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Play pronunciation")
                }
                HStack(spacing: Theme.Spacing.s) {
                    let favorite = isFavorite
                    Button {
                        store.toggleFavorite(word.id)
                    } label: {
                        Image(systemName: favorite ? "heart.fill" : "heart")
                    }
                    .buttonStyle(IconButtonStyle(isActive: favorite))
                    .accessibilityLabel(favorite ? "Remove from favorites" : "Add to favorites")
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview(word.word, image: shareImage)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(IconButtonStyle())
                        .accessibilityLabel("Share word card")
                    }
                }
            }
            .padding(Theme.Spacing.m)
        }
        .sequoiaScreen()
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            shareImage = ShareRenderer.wordCard(word: word, stage: store.stage, streak: store.growth.currentStreak)
                .map(Image.init(uiImage:))
        }
    }

    private var isFavorite: Bool {
        _ = store.revision
        return store.isFavorite(word.id)
    }
}

#Preview("Library") { LibraryView(store: .preview) }
#Preview("Library – dark") { LibraryView(store: .preview).preferredColorScheme(.dark) }
#Preview("Detail") { NavigationStack { WordDetailView(store: .preview, word: .sample) } }

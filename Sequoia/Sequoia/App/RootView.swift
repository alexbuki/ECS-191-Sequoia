import SwiftUI
import DesignSystem
import SequoiaCore

/// The tab shell. Today is always the first thing a user sees.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            #if SEQUOIA_DEV
            // Above the screens rather than over them, so it never covers a title.
            DevModeBadge()
            #endif
            tabs
        }
        .background(Theme.Palette.fog.ignoresSafeArea())
        .presentsCeremony(Binding(get: { app.ceremony }, set: { app.ceremony = $0 })) { app.selectedTab = .forest }
        .alert("Sequoia couldn't open your progress", isPresented: Binding(get: { app.showsStoreError },
                                                                             set: { if !$0 { app.storeErrorAcknowledged = true } })) {
            // After the dismissal, so a retry that fails again shows the alert anew.
            Button("Try Again") { Task { app.rebuildStore() } }
            Button("Continue Without Saving", role: .cancel) {}
        } message: {
            Text("Your words, streak and trees are still on this iPhone, but anything you do now won't be saved. Sequoia tries again each time you open it.")
        }
        #if SEQUOIA_DEV
        .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-showGallery"))) {
            DesignGalleryView()
        }
        #endif
    }

    private var tabs: some View {
        @Bindable var app = app
        return TabView(selection: $app.selectedTab) {
            TodayView(store: app.store)
                .tabItem { Label("Today", systemImage: "sun.horizon") }
                .tag(AppTab.today)
            LibraryView(store: app.store)
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppTab.library)
            ForestView(store: app.store)
                .tabItem { Label("Forest", systemImage: "tree") }
                .tag(AppTab.forest)
        }
        // Rebuild every screen when the store is swapped (developer mode).
        .id(ObjectIdentifier(app.store))
        .tint(Theme.Palette.bark)
        .font(Typography.body)
    }
}

#Preview("Root") {
    RootView().environment(AppModel.preview)
}

#Preview("Root – dark") {
    RootView().environment(AppModel.preview).preferredColorScheme(.dark)
}

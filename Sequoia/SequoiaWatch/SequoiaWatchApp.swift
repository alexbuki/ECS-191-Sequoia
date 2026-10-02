import SwiftUI

@main
struct SequoiaWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchTodayView()
                .environment(model)
                // Watch apps sit on true black; the palette's dark variants suit it.
                .preferredColorScheme(.dark)
                .task { model.activate() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}

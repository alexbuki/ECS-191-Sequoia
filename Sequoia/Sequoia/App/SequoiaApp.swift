import SwiftUI
import DesignSystem

@main
struct SequoiaApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if SEQUOIA_DEV
        LaunchTiming.mark("app-init")
        #endif
        Theme.applyNavigationAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .onOpenURL { app.handle(url: $0) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { app.sceneDidBecomeActive() }
        }
    }
}

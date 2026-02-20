import SwiftUI

@main
struct Swift_CleanerApp: App {

    @StateObject private var app = AppController.shared

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(app)
        }
        .windowStyle(.hiddenTitleBar)
    }
}


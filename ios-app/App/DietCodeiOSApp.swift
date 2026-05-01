import SwiftUI

@main
struct DietCodeiOSApp: App {
    @StateObject private var container = AppContainer()
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(appViewModel)
        }
    }
}

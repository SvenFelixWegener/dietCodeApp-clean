import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var appVM = AppViewModel()

    var body: some View {
        Group {
            if let token = appVM.token {
                DiaryView(token: token)
            } else {
                LoginView()
            }
        }
        .environmentObject(appVM)
    }
}

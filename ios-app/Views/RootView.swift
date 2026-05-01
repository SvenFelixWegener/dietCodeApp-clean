import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            if appViewModel.token == nil {
                LoginView()
            } else {
                DiaryView(token: appViewModel.token!)
            }
        }
    }
}

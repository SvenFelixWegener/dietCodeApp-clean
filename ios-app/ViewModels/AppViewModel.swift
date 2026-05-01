import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var token: String?
    @Published var loginError: String?
    @Published var isBusy = false

    func login(container: AppContainer, username: String, password: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let session = try await container.authService.login(username: username, password: password)
            token = session.token
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
    }
}

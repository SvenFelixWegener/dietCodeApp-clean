import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appVM: AppViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Anmeldung") {
                    TextField("Benutzername", text: $username)
                    SecureField("Passwort", text: $password)
                }

                if let err = appVM.loginError {
                    Section { Text(err).foregroundStyle(.red) }
                }

                Section {
                    Button("Einloggen") {
                        Task { await appVM.login(container: container, username: username, password: password) }
                    }
                    .disabled(appVM.isBusy || username.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("DietCode")
            .overlay { if appVM.isBusy { ProgressView("Anmeldung…") } }
        }
    }
}

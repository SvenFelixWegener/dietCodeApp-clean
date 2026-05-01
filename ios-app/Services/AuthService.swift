import Foundation

final class AuthService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        let payload = ["username": username, "password": password]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await apiClient.request(path: "api/auth/login", method: "POST", body: body)
    }
}

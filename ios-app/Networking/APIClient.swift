import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Ungültige Server-Antwort."
        case let .httpError(_, message): return message
        }
    }
}

final class APIClient {
    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func request<T: Decodable>(path: String, method: String, token: String? = nil, body: Data? = nil) async throws -> T {
        let (data, _) = try await rawRequest(path: path, method: method, token: token, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func rawRequest(path: String, method: String, token: String? = nil, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: config.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Serverfehler"
            throw APIError.httpError(http.statusCode, message)
        }
        return (data, http)
    }
}

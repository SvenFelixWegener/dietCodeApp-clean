import Foundation

struct AppConfig {
    let baseURL: URL

    static let current: AppConfig = {
        let defaultURL = URL(string: "http://localhost:3000")!
        let value = ProcessInfo.processInfo.environment["DIETCODE_API_BASE_URL"]
        let url = value.flatMap(URL.init(string:)) ?? defaultURL
        return AppConfig(baseURL: url)
    }()
}

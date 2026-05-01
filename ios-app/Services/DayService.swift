import Foundation

final class DayService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadDay(token: String, date: String) async throws -> DayData {
        var day: DayData = try await apiClient.request(path: "api/day?date=\(date)", method: "GET", token: token)
        for meal in mealTypes where day.meals[meal] == nil { day.meals[meal] = [] }
        return day
    }

    func saveDay(token: String, day: DayData) async throws {
        let body = try JSONEncoder().encode(day)
        _ = try await apiClient.rawRequest(path: "api/day?date=\(day.date)", method: "PUT", token: token, body: body)
    }
}

import Foundation

final class DayService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadDay(token: String, date: String) async throws -> DayData {
        let loadedDay: DayData

        do {
            loadedDay = try await apiClient.request(
                path: "api/day",
                queryItems: [
                    URLQueryItem(name: "date", value: date)
                ],
                method: "GET",
                token: token
            )
        } catch APIError.httpError(let statusCode, _) where statusCode == 404 {
            loadedDay = DayData(date: date, meals: [:])
        }

        var day = loadedDay
        for meal in mealTypes where day.meals[meal] == nil {
            day.meals[meal] = []
        }

        return day
    }

    func saveDay(token: String, day: DayData) async throws {
        let body = try JSONEncoder().encode(day)

        _ = try await apiClient.rawRequest(
            path: "api/day",
            queryItems: [
                URLQueryItem(name: "date", value: day.date)
            ],
            method: "PUT",
            token: token,
            body: body
        )
    }
}

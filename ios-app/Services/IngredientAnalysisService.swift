import Foundation

struct AnalyzeIngredientsRequest: Codable {
    let type: String
    let imageBase64: String
    let mimeType: String
}

struct AnalyzeIngredientsResponse: Codable {
    let ingredients: [AnalyzedIngredient]
    let totals: AnalyzedTotals
    let confidence: String
    let notes: [String]
}

struct AnalyzedIngredient: Codable, Identifiable {
    let id = UUID()
    var name: String
    var amount: Double?
    var unit: String?
    var estimatedKcal: Double?
    var estimatedProtein: Double?
}

struct AnalyzedTotals: Codable {
    var kcal: Double?
    var protein: Double?
}

final class IngredientAnalysisService {
    private let apiClient: APIClient

    init(apiClient: APIClient) { self.apiClient = apiClient }

    func analyze(token: String, jpegBase64: String) async throws -> AnalyzeIngredientsResponse {
        let body = try JSONEncoder().encode(AnalyzeIngredientsRequest(type: "image", imageBase64: jpegBase64, mimeType: "image/jpeg"))
        return try await apiClient.request(path: "api/ai/analyze-ingredients", method: "POST", token: token, body: body)
    }
}

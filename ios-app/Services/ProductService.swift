import Foundation

final class ProductService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func search(token: String, food: String, brand: String = "") async throws -> [Product] {
        let payload: [String: Any] = ["food": food, "brand": brand]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: ProductSearchResponse = try await apiClient.request(path: "api/products/search", method: "POST", token: token, body: body)
        return response.products
    }
}

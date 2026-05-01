import Foundation
import Combine

final class AppContainer: ObservableObject {
    let config = AppConfig.current
    lazy var apiClient = APIClient(config: config)
    lazy var authService = AuthService(apiClient: apiClient)
    lazy var dayService = DayService(apiClient: apiClient)
    lazy var productService = ProductService(apiClient: apiClient)
}

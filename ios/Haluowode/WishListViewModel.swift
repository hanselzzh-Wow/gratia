import SwiftUI
import HaluowodeCore

@MainActor
public final class WishListViewModel: ObservableObject {
    @Published public private(set) var wishes: [PublicWishDTO] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var selectedCity = "全国"
    
    private let apiClient: WishAPIProtocol
    private var currentTask: Task<Void, Never>?
    
    public init(apiClient: WishAPIProtocol = WishAPIClient()) {
        self.apiClient = apiClient
    }
    
    public func fetchWishes() async {
        currentTask?.cancel()
        
        let filterCity = selectedCity
        let fetchTask = Task {
            self.isLoading = true
            self.errorMessage = nil
            
            do {
                let cityParam = (filterCity == "全国") ? nil : filterCity
                let fetched = try await apiClient.listWishes(city: cityParam)
                
                if !Task.isCancelled {
                    self.wishes = fetched
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    if let apiErr = error as? HaluowodeAPIError {
                        self.errorMessage = apiErr.errorDescription
                    } else {
                        self.errorMessage = "加载失败，请重试。"
                    }
                    self.isLoading = false
                }
            }
        }
        
        currentTask = fetchTask
        await fetchTask.value
    }
}

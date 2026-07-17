import SwiftUI
import HaluowodeCore

public enum LoadState: Sendable {
    case idle
    case loading
    case loaded([PublicWishDTO])
    case empty
    case failed(String)
}

@MainActor
public final class WishListViewModel: ObservableObject {
    @Published public private(set) var state: LoadState = .idle
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
            self.state = .loading
            
            do {
                let cityParam = (filterCity == "全国") ? nil : filterCity
                let fetched = try await apiClient.listWishes(city: cityParam)
                
                if !Task.isCancelled {
                    if fetched.isEmpty {
                        self.state = .empty
                    } else {
                        self.state = .loaded(fetched)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    let errMsg: String
                    if let apiErr = error as? HaluowodeAPIError {
                        errMsg = apiErr.errorDescription ?? "加载失败，请重试。"
                    } else {
                        errMsg = "加载失败，请重试。"
                    }
                    self.state = .failed(errMsg)
                }
            }
        }
        
        currentTask = fetchTask
        await fetchTask.value
    }
}

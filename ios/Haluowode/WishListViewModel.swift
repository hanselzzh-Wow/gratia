import SwiftUI
import HaluowodeCore

public enum LoadState: Sendable, Equatable {
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
    private var activeRequestGeneration = 0

    public init(apiClient: WishAPIProtocol = WishAPIClient()) {
        self.apiClient = apiClient
    }

    public func fetchWishes() async {
        activeRequestGeneration += 1
        let generation = activeRequestGeneration

        self.state = .loading

        do {
            let cityParam = (selectedCity == "全国" || selectedCity == "全部") ? nil : selectedCity
            let fetched = try await apiClient.listWishes(city: cityParam)

            guard generation == activeRequestGeneration && !Task.isCancelled else { return }

            if fetched.isEmpty {
                self.state = .empty
            } else {
                self.state = .loaded(fetched)
            }
        } catch {
            guard generation == activeRequestGeneration && !Task.isCancelled else { return }

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

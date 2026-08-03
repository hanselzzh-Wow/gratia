import Foundation
import Photos
import UIKit

/// 把已交付的照片保存到用户相册。
/// 只申请「仅添加」权限（`addOnly`）：App 从不读取或浏览用户既有的相册内容。
@MainActor
final class DeliverySaver: ObservableObject {
    enum State: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func save(from url: URL) async {
        state = .saving

        guard await requestAddOnlyAuthorization() else {
            state = .failed("需要在系统设置中允许「添加照片」，才能保存到相册。")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                // 交付链接是有时效的能力链接，失败原因一律归一，不回显 URL 或 token。
                state = .failed("交付内容不可用或已失效。")
                return
            }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            state = .saved
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed("保存失败，请稍后再试。")
        }
    }

    func reset() {
        state = .idle
    }

    private func requestAddOnlyAuthorization() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return granted == .authorized || granted == .limited
        default:
            return false
        }
    }
}

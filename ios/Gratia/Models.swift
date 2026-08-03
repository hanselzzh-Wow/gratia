import Foundation

struct Wish: Identifiable, Codable {
    var id: String
    var city: String
    var landmark: String
    var content: String
    var deliveryType: String // 口播视频, 景色配音, 手写卡片
    var date: String
    var reward: Int
    var status: String // 审核中, 待匹配, 已接单, 已交付, 已完成
    var creatorName: String?
    var responderName: String?
    var deliveryUrl: String?

    // P0 requirement: Remove the actual mockup data records from the App target.
    // We keep mockWishes as an empty array to allow other business views (Publish/Progress) to compile.
    static var mockWishes: [Wish] = []
}

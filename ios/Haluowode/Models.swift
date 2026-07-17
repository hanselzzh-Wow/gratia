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

    static var mockWishes: [Wish] = [
        Wish(id: "HW260717-A102B", city: "杭州", landmark: "西湖断桥", content: "希望在下雨天帮我录制一段西湖断桥的视频，背景音播放《等一分钟》。", deliveryType: "口播视频", date: "2026-07-20", reward: 18, status: "待匹配"),
        Wish(id: "HW260717-C349D", city: "上海", landmark: "外滩万国建筑群", content: "今天是我的10周年纪念日，希望能有一张手写卡片在和平饭店门口合影，卡片写着“阿白，十周年快乐”。", deliveryType: "手写卡片", date: "2026-07-18", reward: 28, status: "已接单", responderName: "阿强"),
        Wish(id: "HW260717-E511F", city: "北京", landmark: "景山公园万春亭", content: "想看一次紫禁城的日落，晴天下午6点半帮我拍几张万春亭视角的俯瞰图，谢谢！", deliveryType: "景色配音", date: "2026-07-22", reward: 12, status: "待匹配")
    ]
}

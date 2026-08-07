#if DEBUG
import Foundation
import GratiaCore

/// 仅供**截图与版式验证**的虚构演示内容。整个文件包在 `#if DEBUG` 里，
/// Release 构建根本不会编译它——所以商店截图展示的功能都是真实存在的，
/// 只是内容是编的，不是正式版里看不到的功能。
///
/// 用 `--demo` 启动参数开启：
///   xcrun simctl launch booted com.hanselzzh.gratia --demo
///
/// 人物、地点、事件均为编造，不对应任何真实用户或订单。故事卡片上另有
/// 「虚构示例内容」标签，交付位是矢量插画而非照片素材。
enum DemoContent {
    static var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--demo") || args.contains("--demo-stories")
    }

    /// 「帮助」页：等待有人接下的心愿。
    static let wishes: [PublicWishDTO] = [
        make(id: "d1", code: "GR-2317", city: "上海", landmark: "外滩 · 南京东路口",
             occasion: "生日祝福", delivery: "spoken_video", deadline: "本周六前",
             message: "她在国外过生日。想请一位路过外滩的朋友，对着江面替我说一句「生日快乐」，录一段就好。"),
        make(id: "d2", code: "GR-2314", city: "杭州", landmark: "西湖 · 断桥",
             occasion: "替我看看", delivery: "scenery_voiceover", deadline: "这个月内",
             message: "十年前在断桥上和她说过一句话。今年她不在了。想请人替我在原地站一会儿，拍一段那里的风声。"),
        make(id: "d3", code: "GR-2309", city: "成都", landmark: "四川大学 · 望江校区",
             occasion: "毕业祝福", delivery: "handwritten_card", deadline: "毕业典礼当天",
             message: "妹妹毕业我赶不回去。想请一位字好看的朋友，把我要说的话写成卡片，那天交到她手上。"),
        make(id: "d4", code: "GR-2301", city: "广州", landmark: "永庆坊 · 巷口那棵榕树",
             occasion: "其他小心愿", delivery: "spoken_video", deadline: "不着急",
             message: "爷爷念叨了一辈子的老巷子。想请人替我去看看它现在什么样，随便拍拍就行。"),
    ]

    /// 「私聊」页：发布者与帮助者确认细节的会话。
    /// 用 JSON 解码构造——`ConversationSummaryDTO` 没有对外的 init。
    static let conversations: [ConversationSummaryDTO] = decode(
        """
        [
          {"responseId":"c1","wishId":"d1","publicCode":"GR-2317","title":"外滩 · 南京东路口",
           "occasion":"生日祝福","wishStatus":"in_progress","responseStatus":"selected",
           "viewerRole":"requester","counterpartName":"沿江慢跑的阿哲",
           "lastMessage":"我八点半到外滩，风有点大，我找个背风的角度再录一遍给你看看。",
           "lastMessageAt":1,"unreadCount":2},
          {"responseId":"c2","wishId":"d3","publicCode":"GR-2309","title":"四川大学 · 望江校区",
           "occasion":"毕业祝福","wishStatus":"in_progress","responseStatus":"selected",
           "viewerRole":"requester","counterpartName":"写字的桂圆",
           "lastMessage":"卡片写好啦，我拍给你看下排版，你要是想改还来得及。",
           "lastMessageAt":2,"unreadCount":0},
          {"responseId":"c3","wishId":"d2","publicCode":"GR-2314","title":"西湖 · 断桥",
           "occasion":"替我看看","wishStatus":"matching","responseStatus":"pending",
           "viewerRole":"responder","counterpartName":"南屏晚钟",
           "lastMessage":"谢谢你愿意接这个。不用赶时间，天气好的时候去就行。",
           "lastMessageAt":3,"unreadCount":0}
        ]
        """
    )

    // MARK: - 构造

    private static func make(
        id: String, code: String, city: String, landmark: String,
        occasion: String, delivery: String, deadline: String, message: String
    ) -> PublicWishDTO {
        PublicWishDTO(
            id: id, publicCode: code, city: city, landmark: landmark,
            occasion: occasion, message: message,
            deliveryType: DeliveryType(rawValue: delivery),
            deadlineText: deadline, rewardFen: 0,
            status: WishStatus(rawValue: "open"),
            createdAt: 0
        )
    }

    private static func decode<T: Decodable>(_ json: String) -> [T] {
        (try? JSONDecoder().decode([T].self, from: Data(json.utf8))) ?? []
    }
}
#endif

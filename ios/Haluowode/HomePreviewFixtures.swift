import SwiftUI

/// A completed, publicly-consented story shown in the home / search media feed.
/// Runtime builds pass an empty list until a real public-story API exists;
/// only SwiftUI Previews and tests may use `HomePreviewFixtures`.
struct StoryFixture: Identifiable, Equatable {
    let id: String
    /// City-level location only; never precise personal positions.
    let city: String
    /// Public landmark only.
    let landmark: String
    /// Theme / scene tag, e.g. 生日祝福.
    let scene: String
    /// Delivery-type label, e.g. 口播视频.
    let delivery: String
    let title: String
    let excerpt: String
    /// SF Symbol used on the placeholder media block.
    let mediaSymbol: String
    /// Always true for fixtures; the card renders a visible “虚构示例” badge from it.
    let isFictionalSample: Bool
}

/// Preview-only fictional content. Names are invented, places are public
/// landmarks, and no contact, order, or delivery-link data appears anywhere.
enum HomePreviewFixtures {
    /// Exactly two stories for the home feed preview, per the CL-006 card.
    static let homeStories: [StoryFixture] = [
        StoryFixture(
            id: "fixture-story-001",
            city: "杭州",
            landmark: "西湖断桥",
            scene: "生日祝福",
            delivery: "口播视频",
            title: "断桥边的一声生日快乐",
            excerpt: "虚构示例：为异地的老朋友“阿蓝”录一段断桥晚风里的祝福，念出她十八岁时最爱的那句话。",
            mediaSymbol: "video",
            isFictionalSample: true
        ),
        StoryFixture(
            id: "fixture-story-002",
            city: "上海",
            landmark: "和平饭店门口",
            scene: "加油鼓励",
            delivery: "手写卡片",
            title: "一张手写卡片，替他说加油",
            excerpt: "虚构示例：把“小茉”写给备考同学的鼓励抄在卡片上，与外滩的暮色同框拍下一张照片。",
            mediaSymbol: "envelope",
            isFictionalSample: true
        ),
    ]

    /// A slightly larger fictional set so the search preview can demonstrate
    /// every filter dimension (city, landmark, scene, delivery).
    static let searchStories: [StoryFixture] = homeStories + [
        StoryFixture(
            id: "fixture-story-003",
            city: "北京",
            landmark: "什刹海",
            scene: "节日问候",
            delivery: "景色配音",
            title: "什刹海的冰面替你问好",
            excerpt: "虚构示例：在冬日什刹海拍一段空镜，配上“老周”写给家人的节日问候。",
            mediaSymbol: "mic",
            isFictionalSample: true
        ),
        StoryFixture(
            id: "fixture-story-004",
            city: "杭州",
            landmark: "良渚文化村",
            scene: "毕业祝福",
            delivery: "口播视频",
            title: "把毕业祝福送到良渚的稻田",
            excerpt: "虚构示例：替“小禾”的导师在稻田边念出一段毕业赠言，风声也一起录了进去。",
            mediaSymbol: "graduationcap",
            isFictionalSample: true
        ),
    ]
}

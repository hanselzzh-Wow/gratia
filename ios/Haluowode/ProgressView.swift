import SwiftUI

struct ProgressView: View {
    @State private var wishId = ""
    @State private var contact = ""
    @State private var isSearching = false
    @State private var foundWish: Wish? = nil
    @State private var showErrorAlert = false
    @State private var showDeliveryPreview = false

    var isFormValid: Bool {
        !wishId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contact.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack {
                if let wish = foundWish {
                    // Detailed Wish Status Tracking Page
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {

                            // Status Header Card
                            VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                                HStack {
                                    Text("当前状态：\(wish.status)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(DesignSystem.primaryBlue)
                                    Spacer()
                                    Button("切换单号") {
                                        withAnimation {
                                            foundWish = nil
                                        }
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.primaryBlue)
                                }

                                Text("\(wish.city) · \(wish.landmark)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(DesignSystem.textNavy)

                                Text("查询编号: \(wish.id)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                            .padding(DesignSystem.spacing16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusMedium)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                            // Delivery File (if available)
                            if wish.status == "已交付" || wish.status == "已完成" {
                                VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                                    Text("已收到交付文件")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(DesignSystem.textNavy)

                                    Button(action: {
                                        showDeliveryPreview = true
                                    }) {
                                        HStack(spacing: DesignSystem.spacing12) {
                                            Image(systemName: wish.deliveryType == "口播视频" ? "video.circle.fill" : "photo.circle.fill")
                                                .font(.largeTitle)
                                                .foregroundColor(DesignSystem.primaryBlue)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("点击预览交付的现场媒体文件")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(DesignSystem.textNavy)
                                                Text("响应者：\(wish.responderName ?? "在场好心人")")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(DesignSystem.textSecondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(DesignSystem.textSecondary)
                                        }
                                        .padding()
                                        .background(DesignSystem.primaryBlue.opacity(0.05))
                                        .cornerRadius(DesignSystem.radiusSmall)
                                    }
                                }
                                .padding(DesignSystem.spacing16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DesignSystem.cardBg)
                                .cornerRadius(DesignSystem.radiusMedium)
                                .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                            }

                            // Wish Details Card
                            VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                                Text("心愿概要")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                Divider()
                                Text("心愿描述: \(wish.content)")
                                Text("交付形式: \(wish.deliveryType)")
                                Text("感谢金: ¥\(wish.reward)")
                            }
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.textSecondary)
                            .padding(DesignSystem.spacing16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusMedium)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                            // Vertical Timeline
                            VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                                Text("流转时间线")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                    .padding(.bottom, 4)

                                timelineRow(title: "心愿提交", desc: "发布人提交，进入审核阶段", isCompleted: true, isLast: false)
                                timelineRow(title: "审核通过", desc: "内容安全审核已通过，进入待匹配", isCompleted: wish.status != "审核中", isLast: false)
                                timelineRow(title: "匹配成功", desc: wish.responderName != nil ? "已匹配给当地响应者 [\(wish.responderName!)]" : "寻找附近的响应者中", isCompleted: wish.status == "已接单" || wish.status == "已交付" || wish.status == "已完成", isLast: false)
                                timelineRow(title: "已完成交付", desc: "响应者已上传现场视频/照片，等待发布者确认", isCompleted: wish.status == "已交付" || wish.status == "已完成", isLast: false)
                                timelineRow(title: "交易完结", desc: "发布者确认完成，感谢金已汇出", isCompleted: wish.status == "已完成", isLast: true)
                            }
                            .padding(DesignSystem.spacing20)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusLarge)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                        }
                        .padding(DesignSystem.spacing20)
                    }
                } else {
                    // Query Form Page (Default state)
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {

                            VStack(alignment: .leading, spacing: 4) {
                                Text("查询心愿进度")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                Text("输入发布心愿时获取的公开编号与联系方式。")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                            .padding(.vertical, 8)

                            // Input fields card
                            VStack(spacing: DesignSystem.spacing16) {
                                VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                                    Text("公开查询编号")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.textNavy)
                                    TextField("HWyyMMdd-XXXXX", text: $wishId)
                                        .padding()
                                        .background(DesignSystem.bgWarmWhite)
                                        .cornerRadius(DesignSystem.radiusSmall)
                                }

                                VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                                    Text("联系方式 (手机或微信)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.textNavy)
                                    TextField("发布时填写的微信号/手机号", text: $contact)
                                        .padding()
                                        .background(DesignSystem.bgWarmWhite)
                                        .cornerRadius(DesignSystem.radiusSmall)
                                }
                            }
                            .padding(DesignSystem.spacing20)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusLarge)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                            Button(action: queryWishProgress) {
                                if isSearching {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("立即查询")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(isDisabled: !isFormValid))
                            .disabled(!isFormValid || isSearching)

                            // Guide / Help
                            HStack {
                                Spacer()
                                Button("编号或联系方式找不到了？") {
                                    // Handle help
                                }
                                .font(.system(size: 13))
                                .foregroundColor(DesignSystem.primaryBlue)
                                Spacer()
                            }
                            .padding(.top, 10)
                        }
                        .padding(DesignSystem.spacing20)
                    }
                }
            }
            .navigationTitle("进度追踪")
            .navigationBarTitleDisplayMode(.inline)
            .warmBackground()
            .alert("未找到该心愿", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请核对查询单号和联系方式是否正确。测试数据单号如: HW260717-A102B")
            }
            .fullScreenCover(isPresented: $showDeliveryPreview) {
                if let wish = foundWish {
                    DeliveryPreviewView(wish: wish, isPresented: $showDeliveryPreview)
                }
            }
        }
    }

    // MARK: - Timeline Helper row
    func timelineRow(title: String, desc: String, isCompleted: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing16) {
            VStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? DesignSystem.primaryBlue : Color.gray.opacity(0.3))
                    .font(.system(size: 16))
                    .background(Color.white)

                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? DesignSystem.primaryBlue : Color.gray.opacity(0.2))
                        .frame(width: 2, height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isCompleted ? DesignSystem.textNavy : DesignSystem.textSecondary)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    // MARK: - Actions
    func queryWishProgress() {
        isSearching = true

        // Simulate Network Request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isSearching = false

            // Search in mock list (just matching by ID for test convenience)
            let trimmedId = self.wishId.trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = Wish.mockWishes.firstIndex(where: { $0.id.localizedCaseInsensitiveCompare(trimmedId) == .orderedSame }) {
                self.foundWish = Wish.mockWishes[index]
            } else {
                self.showErrorAlert = true
            }
        }
    }
}

// Delivery Preview View (Full Screen)
struct DeliveryPreviewView: View {
    let wish: Wish
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image Placeholder representing Delivery Video/Photo
            VStack(spacing: DesignSystem.spacing20) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(9/16, contentMode: .fit)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: DesignSystem.spacing16) {
                        Image(systemName: wish.deliveryType == "口播视频" ? "play.circle.fill" : "photo.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)

                        Text("交付媒体文件预览 (\(wish.deliveryType))")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                // Translucent Bottom Overlay
                VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                    Text("\(wish.city) · \(wish.landmark)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("响应者：\(wish.responderName ?? "在场好心人")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Text("交付留言：心愿已送达！现场天气很好，我把写的明信片放在西湖大石碑前拍了这个视频，祝小白生日快乐！")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(3)
                        .lineSpacing(2)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)
                .padding(.horizontal, DesignSystem.spacing20)
                .padding(.bottom, 40)
            }

            // Top Bar controls
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text("交付凭证 \(wish.id)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        // Share action
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

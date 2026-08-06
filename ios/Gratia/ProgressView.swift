import SwiftUI
import GratiaCore

struct ProgressView: View {
    @StateObject private var viewModel: TrackWishViewModel
    @State private var showDeliveryPreview = false

    init(apiClient: WishAPIProtocol) {
        self._viewModel = StateObject(wrappedValue: TrackWishViewModel(apiClient: apiClient))
    }

    var isFormValid: Bool {
        let isNotLoading = viewModel.state != .loading
        return !viewModel.publicCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !viewModel.contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               isNotLoading
    }

    var isSearching: Bool {
        viewModel.state == .loading
    }

    static func statusText(for status: WishStatus) -> String {
        status == .delivered ? "待确认" : status.label
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.state {
                case .loaded(let wish):
                    // Detailed Wish Status Tracking Page
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {

                            // Status Header Card
                            VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                                HStack {
                                    Text("当前状态：\(Self.statusText(for: wish.status))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(DesignSystem.primaryBlue)
                                    Spacer()
                                    Button("切换单号") {
                                        withAnimation(DesignSystem.Motion.navigation) {
                                            viewModel.resetQuery()
                                        }
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.primaryBlue)
                                }

                                Text("\(wish.city) · \(wish.landmark)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(DesignSystem.textNavy)

                                Text("查询编号: \(wish.publicCode)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                            .padding(DesignSystem.spacing16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusMedium)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                            // Delivery File (if available)
                            if let deliverable = wish.deliverable {
                                VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                                    Text("已收到交付文件")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(DesignSystem.textNavy)

                                    Button(action: {
                                        showDeliveryPreview = true
                                    }) {
                                        HStack(spacing: DesignSystem.spacing12) {
                                            Image(systemName: deliverable.kind == .spokenVideo ? "video.circle.fill" : "photo.circle.fill")
                                                .font(.largeTitle)
                                                .foregroundColor(DesignSystem.primaryBlue)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("点击预览交付的现场媒体文件")
                                                    .font(.system(size: 14, weight: .semibold))

                                                let providerName = wish.assignment?.providerName ?? "在场好心人"
                                                Text("响应者：\(providerName)")
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
                                .fullScreenCover(isPresented: $showDeliveryPreview) {
                                    DeliveryPreviewView(deliverable: deliverable, isPresented: $showDeliveryPreview)
                                }
                            }

                            // Wish Details Card
                            VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                                Text("心愿概要")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                Divider()
                                Text("心愿描述: \(wish.message)")
                                Text("交付形式: \(wish.deliveryType.label)")
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

                                ForEach(Array(wish.events.enumerated()), id: \.offset) { index, event in
                                    let isLast = index == wish.events.count - 1
                                    let timeString = formatTimestamp(event.createdAt)
                                    let statusLabel = event.toStatus?.label ?? "未知"
                                    timelineRow(
                                        title: event.eventType,
                                        desc: "变更至 [\(statusLabel)] · \(timeString)",
                                        isCompleted: true,
                                        isLast: isLast
                                    )
                                }

                                if wish.events.isEmpty {
                                    Text("暂无流转记录")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignSystem.textSecondary)
                                }
                            }
                            .padding(DesignSystem.spacing20)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusLarge)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                        }
                        .padding(DesignSystem.spacing20)
                    }

                default:
                    // Query Form Page (Default, Loading or Failed states)
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

                            if case .failed(let errorMsg) = viewModel.state {
                                HStack(spacing: DesignSystem.spacing8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(errorMsg)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.red)
                                    Spacer()
                                    Button("重试") {
                                        queryWishProgress()
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(DesignSystem.primaryBlue)
                                    .cornerRadius(DesignSystem.radiusSmall)
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(DesignSystem.radiusSmall)
                            }

                            // Input fields card
                            VStack(spacing: DesignSystem.spacing16) {
                                VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                                    Text("公开查询编号")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.textNavy)
                                    TextField("HWyyMMdd-XXXXX", text: $viewModel.publicCode)
                                        .padding()
                                        .background(DesignSystem.bgWarmWhite)
                                        .cornerRadius(DesignSystem.radiusSmall)
                                        .disabled(isSearching)

                                    if let error = viewModel.validationErrors["publicCode"] {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }

                                VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                                    Text("联系方式 (手机或微信)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.textNavy)
                                    TextField("发布时填写的微信号/手机号", text: $viewModel.contact)
                                        .padding()
                                        .background(DesignSystem.bgWarmWhite)
                                        .cornerRadius(DesignSystem.radiusSmall)
                                        .disabled(isSearching)

                                    if let error = viewModel.validationErrors["contact"] {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(DesignSystem.spacing20)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusLarge)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                            Button(action: queryWishProgress) {
                                if isSearching {
                                    SwiftUI.ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("立即查询")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(isDisabled: !isFormValid))
                            .disabled(!isFormValid || isSearching)
                        }
                        .padding(DesignSystem.spacing20)
                    }
                }
            }
            .motion(DesignSystem.Motion.content, value: viewModel.state)
            .navigationTitle("进度追踪")
            .navigationBarTitleDisplayMode(.inline)
            .warmBackground()
            .onDisappear {
                viewModel.cancel()
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
        Task {
            await viewModel.trackWish()
        }
    }

    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

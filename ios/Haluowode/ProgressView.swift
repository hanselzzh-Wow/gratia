import SwiftUI
import HaluowodeCore

struct ProgressView: View {
    private enum Field: Hashable { case publicCode, contact }

    @StateObject private var viewModel: TrackWishViewModel
    @State private var showDeliveryPreview = false
    @FocusState private var focusedField: Field?

    init(apiClient: WishAPIProtocol) {
        self._viewModel = StateObject(wrappedValue: TrackWishViewModel(apiClient: apiClient))
    }

    init(viewModel: TrackWishViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var isFormValid: Bool {
        viewModel.state != .loading &&
        !viewModel.publicCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isSearching: Bool { viewModel.state == .loading }

    static func statusText(for status: WishStatus) -> String {
        status == .delivered ? "待确认" : status.label
    }

    var body: some View {
        NavigationStack {
            Group {
                if case .loaded(let wish) = viewModel.state {
                    loadedContent(wish)
                } else {
                    queryContent
                }
            }
            .navigationTitle("进度")
            .navigationBarTitleDisplayMode(.large)
            .warmBackground()
            .onDisappear { viewModel.cancel() }
        }
    }

    private var queryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spacing24) {
                VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                    Text("查询心愿进度")
                        .font(DesignSystem.titleFont)
                        .foregroundStyle(DesignSystem.ink900)
                    Text("使用发布时获得的公开编号和联系方式。联系方式只用于本次查询。")
                        .font(DesignSystem.bodyFont)
                        .foregroundStyle(DesignSystem.ink700)
                        .lineSpacing(3)
                }

                if case .failed(let message) = viewModel.state {
                    errorBanner(message)
                }

                VStack(spacing: DesignSystem.spacing20) {
                    inputField(
                        title: "公开查询编号",
                        prompt: "例如 HW260718-A001B",
                        text: $viewModel.publicCode,
                        field: .publicCode,
                        error: viewModel.validationErrors["publicCode"],
                        contentType: nil
                    )
                    inputField(
                        title: "发布时的联系方式",
                        prompt: "手机号或微信号",
                        text: $viewModel.contact,
                        field: .contact,
                        error: viewModel.validationErrors["contact"],
                        contentType: .telephoneNumber
                    )
                }
                .padding(DesignSystem.spacing20)
                .v3Card(radius: DesignSystem.radiusLarge)

                Button(action: queryWishProgress) {
                    HStack(spacing: DesignSystem.spacing8) {
                        if isSearching {
                            SwiftUI.ProgressView().tint(.white)
                            Text("正在查询")
                        } else {
                            Text("立即查询")
                            Image(systemName: "arrow.right")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: !isFormValid))
                .disabled(!isFormValid)

                Label("查询成功后，联系方式会立即从当前页面清除。", systemImage: "lock")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink500)
            }
            .padding(.horizontal, DesignSystem.spacing20)
            .padding(.vertical, DesignSystem.spacing24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func inputField(
        title: String,
        prompt: String,
        text: Binding<String>,
        field: Field,
        error: String?,
        contentType: UITextContentType?
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(title)
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink900)

            TextField(prompt, text: text)
                .font(DesignSystem.bodyFont)
                .textContentType(contentType)
                .textInputAutocapitalization(field == .publicCode ? .characters : .never)
                .autocorrectionDisabled()
                .padding(.horizontal, DesignSystem.spacing16)
                .frame(minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.canvasSunk)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .stroke(
                                    error == nil ? (focusedField == field ? DesignSystem.accent : DesignSystem.hairlineStrong) : DesignSystem.danger,
                                    lineWidth: focusedField == field || error != nil ? 2 : 1
                                )
                        )
                )
                .focused($focusedField, equals: field)
                .disabled(isSearching)

            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.danger)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.danger)
            Button("重试") { queryWishProgress() }
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.accent)
                .frame(minHeight: 44)
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                .fill(DesignSystem.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .stroke(DesignSystem.danger, lineWidth: 1)
                )
        )
    }

    private func loadedContent(_ wish: TrackedWishDTO) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                statusCard(wish)
                if let deliverable = wish.deliverable { deliveryCard(deliverable, wish: wish) }
                summaryCard(wish)
                timelineCard(wish)
            }
            .padding(.horizontal, DesignSystem.spacing20)
            .padding(.vertical, DesignSystem.spacing24)
        }
    }

    private func statusCard(_ wish: TrackedWishDTO) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    Text("当前状态")
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.ink500)
                    Text(Self.statusText(for: wish.status))
                        .font(DesignSystem.displayFont)
                        .foregroundStyle(DesignSystem.ink900)
                }
                Spacer()
                Button("切换单号") { withAnimation { viewModel.resetQuery() } }
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
                    .frame(minHeight: 44)
            }
            Divider().overlay(DesignSystem.hairline)
            Label("\(wish.city) · \(wish.landmark)", systemImage: "mappin.and.ellipse")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink700)
            Text(wish.publicCode)
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                .foregroundStyle(DesignSystem.ink500)
                .accessibilityLabel("公开查询编号 \(wish.publicCode)")
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
    }

    private func deliveryCard(_ deliverable: WishDeliverableDTO, wish: TrackedWishDTO) -> some View {
        Button { showDeliveryPreview = true } label: {
            HStack(spacing: DesignSystem.spacing16) {
                Image(systemName: deliverySymbol(deliverable.kind))
                    .font(.title2.weight(.regular))
                    .foregroundStyle(DesignSystem.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(DesignSystem.canvasSunk))
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    Text("查看交付")
                        .font(DesignSystem.headlineFont)
                        .foregroundStyle(DesignSystem.ink900)
                    Text("由 \(wish.assignment?.providerName ?? "在场响应者") 完成")
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.ink700)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignSystem.ink500)
            }
            .padding(DesignSystem.spacing16)
            .v3Card(radius: DesignSystem.radiusLarge)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showDeliveryPreview) {
            DeliveryPreviewView(deliverable: deliverable, isPresented: $showDeliveryPreview)
        }
    }

    private func summaryCard(_ wish: TrackedWishDTO) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("心愿概要").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.ink900)
            Text(wish.message).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.ink700)
            Divider().overlay(DesignSystem.hairline)
            HStack {
                Label(wish.deliveryType.label, systemImage: "shippingbox")
                Spacer()
                Text("¥\(Int(wish.rewardYuan))")
            }
            .font(DesignSystem.metadataFont.weight(.semibold))
            .foregroundStyle(DesignSystem.ink700)
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
    }

    private func timelineCard(_ wish: TrackedWishDTO) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            Text("流转时间线").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.ink900)
            if wish.events.isEmpty {
                Label("暂无流转记录", systemImage: "clock")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.ink500)
                    .frame(minHeight: 44)
            } else {
                ForEach(Array(wish.events.enumerated()), id: \.offset) { index, event in
                    timelineRow(
                        title: event.eventType,
                        detail: "变更至 \(event.toStatus?.label ?? "未知") · \(formatTimestamp(event.createdAt))",
                        isLast: index == wish.events.count - 1
                    )
                }
            }
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
    }

    private func timelineRow(title: String, detail: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing12) {
            VStack(spacing: 0) {
                Image(systemName: "checkmark.circle")
                    .font(.body.weight(.regular))
                    .foregroundStyle(DesignSystem.success)
                if !isLast { Rectangle().fill(DesignSystem.hairlineStrong).frame(width: 1, height: 40) }
            }
            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text(title).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
                Text(detail).font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink700)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func deliverySymbol(_ kind: DeliveryKind) -> String {
        switch kind {
        case .spokenVideo, .sceneryVoiceover: return "play.rectangle"
        case .handwrittenCard: return "photo"
        case .link: return "link"
        default: return "doc"
        }
    }

    private func queryWishProgress() {
        focusedField = nil
        Task { await viewModel.trackWish() }
    }

    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

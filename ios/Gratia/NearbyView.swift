import SwiftUI
import GratiaCore

struct NearbyView: View {
    @EnvironmentObject private var viewModel: WishListViewModel
    @State private var searchKeywords = ""
    @State private var selectedDeliveryFilter = "全部"
    @State private var showFilterSheet = false
    @State private var localCity = "全国"

    private let deliveryTypes = ["全部", "口播视频", "景色配音", "手写卡片"]

    private var filteredWishes: [PublicWishDTO] {
        guard case .loaded(let wishes) = viewModel.state else { return [] }
        return wishes.filter { wish in
            let matchSearch = searchKeywords.isEmpty ||
                wish.landmark.localizedCaseInsensitiveContains(searchKeywords) ||
                wish.message.localizedCaseInsensitiveContains(searchKeywords)
            let matchDelivery = selectedDeliveryFilter == "全部" || wish.deliveryType.label == selectedDeliveryFilter
            return matchSearch && matchDelivery
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchAndFilter
                filterChips
                content
            }
            .navigationTitle("等待帮助的心愿")
            .navigationBarTitleDisplayMode(.inline)
            .warmBackground()
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(selectedCity: $localCity, isPresented: $showFilterSheet) { newCity in
                    viewModel.selectedCity = newCity
                    Task { await viewModel.fetchWishes() }
                }
            }
            .task { await viewModel.fetchWishes() }
        }
    }

    private var searchAndFilter: some View {
        HStack(spacing: DesignSystem.spacing12) {
            HStack(spacing: DesignSystem.spacing8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.ink500)
                    .accessibilityHidden(true)
                TextField("搜索地标、心愿内容", text: $searchKeywords)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.ink900)
            }
            .padding(.horizontal, DesignSystem.spacing12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                    .fill(DesignSystem.canvasSunk)
            )

            Button {
                localCity = viewModel.selectedCity
                showFilterSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.regular))
                    .foregroundStyle(DesignSystem.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                            .fill(DesignSystem.canvas)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .stroke(DesignSystem.hairlineStrong, lineWidth: 1)
                            )
                    )
            }
            .accessibilityLabel("筛选城市")
        }
        .padding(.horizontal, DesignSystem.spacing20)
        .padding(.vertical, DesignSystem.spacing12)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.spacing8) {
                ForEach(deliveryTypes, id: \.self) { type in
                    Button {
                        selectedDeliveryFilter = type
                    } label: {
                        Text(type)
                            .font(DesignSystem.metadataFont.weight(.semibold))
                            .foregroundStyle(selectedDeliveryFilter == type ? .white : DesignSystem.ink700)
                            .padding(.horizontal, DesignSystem.spacing16)
                            .frame(minHeight: 36)
                            .background(
                                Capsule()
                                    .fill(selectedDeliveryFilter == type ? DesignSystem.accent : DesignSystem.canvas)
                                    .overlay(
                                        Capsule().stroke(
                                            selectedDeliveryFilter == type ? DesignSystem.accent : DesignSystem.hairline,
                                            lineWidth: 1
                                        )
                                    )
                            )
                    }
                    .accessibilityAddTraits(selectedDeliveryFilter == type ? .isSelected : [])
                }
            }
            .padding(.horizontal, DesignSystem.spacing20)
        }
        .padding(.bottom, DesignSystem.spacing12)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            Spacer()
            SwiftUI.ProgressView("正在加载心愿")
                .tint(DesignSystem.accent)
                .font(DesignSystem.metadataFont)
            Spacer()
        case .failed(let error):
            Spacer()
            VStack(spacing: DesignSystem.spacing16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle.weight(.regular))
                    .foregroundStyle(DesignSystem.danger)
                Text(error)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.ink700)
                    .multilineTextAlignment(.center)
                Button("重试") { Task { await viewModel.fetchWishes() } }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 120)
            }
            .padding(.horizontal, DesignSystem.spacing32)
            Spacer()
        case .empty:
            emptyState
        case .loaded:
            VStack(spacing: 0) {
                HStack {
                    Text("共找到 \(filteredWishes.count) 个心愿")
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.ink700)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.spacing20)
                .padding(.vertical, DesignSystem.spacing8)

                if filteredWishes.isEmpty {
                    emptyState
                } else {
                    List(filteredWishes) { wish in
                        NavigationLink(destination: WishDetailView(wish: wish)) {
                            WishRowView(wish: wish)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.horizontal, DesignSystem.spacing20)
                        .padding(.vertical, DesignSystem.spacing4)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await viewModel.fetchWishes() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Spacer()
            Image(systemName: "tray")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(DesignSystem.ink500)
            Text("没有找到符合条件的心愿")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink700)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct WishRowView: View {
    let wish: PublicWishDTO

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            HStack(alignment: .top) {
                Text("\(wish.city) · \(wish.landmark)")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
                    .lineLimit(1)
                Spacer(minLength: DesignSystem.spacing8)
                Text("¥\(Int(wish.rewardYuan))")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
            }

            Text(wish.message)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink700)
                .lineLimit(3)
                .lineSpacing(2)

            HStack {
                Text(wish.deliveryType.label)
                    .font(DesignSystem.captionFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
                    .padding(.horizontal, DesignSystem.spacing8)
                    .frame(minHeight: 28)
                    .background(
                        Capsule()
                            .fill(DesignSystem.canvasSunk)
                            .overlay(Capsule().stroke(DesignSystem.hairline, lineWidth: 1))
                    )
                Spacer()
                Text("期望时间：\(wish.deadlineText)")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.ink500)
                    .lineLimit(1)
            }
        }
        .padding(DesignSystem.spacing16)
        .v3Card()
    }
}

struct FilterSheetView: View {
    @Binding var selectedCity: String
    @Binding var isPresented: Bool
    var onConfirm: (String) -> Void

    private let cities = ["全国", "杭州", "上海", "北京", "深圳", "广州"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                Text("选择城市")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.spacing8) {
                        ForEach(cities, id: \.self) { city in
                            Button { selectedCity = city } label: {
                                Text(city)
                                    .font(DesignSystem.metadataFont.weight(.semibold))
                                    .foregroundStyle(selectedCity == city ? .white : DesignSystem.ink700)
                                    .padding(.horizontal, DesignSystem.spacing16)
                                    .frame(minHeight: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                            .fill(selectedCity == city ? DesignSystem.accent : DesignSystem.canvasSunk)
                                    )
                            }
                        }
                    }
                }

                Spacer()

                Button("确定") {
                    onConfirm(selectedCity)
                    isPresented = false
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(DesignSystem.spacing20)
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") { selectedCity = "全国" }
                        .foregroundStyle(DesignSystem.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { isPresented = false }
                        .foregroundStyle(DesignSystem.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WishDetailView: View {
    let wish: PublicWishDTO
    @State private var showApplySheet = false
    @State private var showSuccess = false
    @Environment(\.accountAPIClient) private var accountAPI
    @EnvironmentObject private var accountViewModel: AccountViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    headerCard
                    contentCard
                    processCard
                    safetyNotice
                }
                .padding(DesignSystem.spacing20)
            }

            Button("我刚好在这里，可以帮忙") { showApplySheet = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(DesignSystem.spacing20)
                .background(
                    DesignSystem.canvas.overlay(alignment: .top) {
                        Rectangle().fill(DesignSystem.hairline).frame(height: 1)
                    }
                )
        }
        .navigationTitle("心愿详情")
        .navigationBarTitleDisplayMode(.inline)
        .warmBackground()
        .sheet(isPresented: $showApplySheet) {
            ApplyResponseSheet(
                wish: wish,
                isPresented: $showApplySheet,
                showSuccess: $showSuccess,
                accountAPI: accountAPI,
                accessToken: { [weak accountViewModel] in accountViewModel?.accessToken }
            )
            .environmentObject(accountViewModel)
            .presentationDetents([.large])
        }
        .navigationDestination(isPresented: $showSuccess) {
            ApplySuccessView(wish: wish)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            HStack {
                detailChip(wish.deliveryType.label)
                Spacer()
                Text(wish.status.label)
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
            }
            Text("\(wish.city) · \(wish.landmark)")
                .font(DesignSystem.titleFont)
                .foregroundStyle(DesignSystem.ink900)
            HStack(spacing: DesignSystem.spacing4) {
                Text("感谢金")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.ink700)
                Text("¥\(Int(wish.rewardYuan))")
                    .font(DesignSystem.titleFont)
                    .foregroundStyle(DesignSystem.ink900)
            }
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("心愿内容")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink900)
            Text(wish.message)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink700)
                .lineSpacing(3)
            Divider().overlay(DesignSystem.hairline)
            HStack {
                Text("期望完成时间")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
                Spacer()
                Text(wish.deadlineText)
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink900)
            }
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
    }

    private var processCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("接单履约说明")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink900)
            Text("提交响应后，运营人员会确认匹配。确认后请在约定时间前往现场履约；完成后上传照片或视频，等待发布者确认。")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink700)
                .lineSpacing(3)
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
    }

    private var safetyNotice: some View {
        Label("响应者与发布者的联系方式均不对外公开，由平台居中保护。", systemImage: "shield")
            .font(DesignSystem.metadataFont)
            .foregroundStyle(DesignSystem.ink700)
            .padding(DesignSystem.spacing12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(DesignSystem.canvasSunk)
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusMedium).stroke(DesignSystem.hairline, lineWidth: 1))
            )
    }

    private func detailChip(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.captionFont.weight(.semibold))
            .foregroundStyle(DesignSystem.accent)
            .padding(.horizontal, DesignSystem.spacing8)
            .frame(minHeight: 28)
            .background(Capsule().fill(DesignSystem.canvasSunk))
    }
}

struct ApplyResponseSheet: View {
    private enum ResponseField: Hashable { case name, contact, note }

    let wish: PublicWishDTO
    @Binding var isPresented: Bool
    @Binding var showSuccess: Bool
    @StateObject private var viewModel: WishResponseViewModel
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @FocusState private var focusedField: ResponseField?

    init(
        wish: PublicWishDTO,
        isPresented: Binding<Bool>,
        showSuccess: Binding<Bool>,
        accountAPI: AccountAPIProtocol,
        accessToken: @escaping @MainActor () -> String?
    ) {
        self.wish = wish
        _isPresented = isPresented
        _showSuccess = showSuccess
        _viewModel = StateObject(wrappedValue: WishResponseViewModel(
            wishId: wish.id,
            accountAPI: accountAPI,
            accessToken: accessToken
        ))
    }

    private var isFormValid: Bool {
        !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            viewModel.agreeContact && viewModel.state != .submitting
    }

    private var isSubmitting: Bool { viewModel.state == .submitting }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    summary
                    if viewModel.state == .requiresSignIn {
                        SignInPromptView(
                            viewModel: accountViewModel,
                            reason: "登录后才能提交帮助响应。你填写的内容已经保留，登录后再点一次「确认提交」即可。"
                        )
                    }
                    if case .failed(let message) = viewModel.state { failure(message) }
                    textField(label: "您的称呼", placeholder: "如：小张", text: $viewModel.name, field: .name, error: viewModel.validationErrors["responderName"])
                    textField(label: "联系方式（仅运营可见）", placeholder: "微信号或手机号", text: $viewModel.contact, field: .contact, error: viewModel.validationErrors["responderContact"])
                    noteField
                    consent
                    if let error = viewModel.validationErrors["contactConsent"] {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(DesignSystem.captionFont)
                            .foregroundStyle(DesignSystem.danger)
                    }
                    Button(action: submitResponse) {
                        if isSubmitting {
                            SwiftUI.ProgressView().tint(.white)
                        } else {
                            Text("提交响应")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isDisabled: !isFormValid))
                    .disabled(!isFormValid || isSubmitting)
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("我要帮忙")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        viewModel.cancel()
                        isPresented = false
                    }
                    .foregroundStyle(DesignSystem.accent)
                }
            }
            .onDisappear { viewModel.cancel() }
        }
    }

    private var summary: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text("\(wish.city) · \(wish.landmark)")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
                Text("感谢金 ¥\(Int(wish.rewardYuan))")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
            }
            Spacer()
        }
        .padding(DesignSystem.spacing16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                .fill(DesignSystem.canvasSunk)
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusMedium).stroke(DesignSystem.hairline, lineWidth: 1))
        )
    }

    private func failure(_ message: String) -> some View {
        HStack(spacing: DesignSystem.spacing8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(DesignSystem.danger)
            Text(message)
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(DesignSystem.danger)
            Spacer()
            Button("重试") { submitResponse() }
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(DesignSystem.accent)
        }
        .padding(DesignSystem.spacing12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                .fill(DesignSystem.canvas)
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).stroke(DesignSystem.danger, lineWidth: 1))
        )
    }

    private func textField(label: String, placeholder: String, text: Binding<String>, field: ResponseField, error: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(label)
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink900)
            TextField(placeholder, text: text)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink900)
                .padding(.horizontal, DesignSystem.spacing12)
                .frame(minHeight: 48)
                .background(fieldBackground(isFocused: focusedField == field, hasError: error != nil))
                .focused($focusedField, equals: field)
                .disabled(isSubmitting)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.danger)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("补充说明（选填）")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink900)
            TextEditor(text: $viewModel.note)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink900)
                .scrollContentBackground(.hidden)
                .padding(DesignSystem.spacing8)
                .frame(height: 112)
                .background(fieldBackground(isFocused: focusedField == .note, hasError: viewModel.validationErrors["note"] != nil))
                .focused($focusedField, equals: .note)
                .disabled(isSubmitting)
            if let error = viewModel.validationErrors["note"] {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.danger)
            }
        }
    }

    private var consent: some View {
        Toggle(isOn: $viewModel.agreeContact) {
            Text("同意平台运营人员与我联系确认匹配事宜。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.ink700)
        }
        .toggleStyle(CheckboxToggleStyle())
        .disabled(isSubmitting)
    }

    private func fieldBackground(isFocused: Bool, hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
            .fill(DesignSystem.canvasSunk)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                    .stroke(
                        hasError ? DesignSystem.danger : (isFocused ? DesignSystem.accent : DesignSystem.hairlineStrong),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
    }

    private func submitResponse() {
        Task {
            await viewModel.submitResponse()
            if viewModel.state == .success {
                isPresented = false
                showSuccess = true
            }
        }
    }
}

struct ApplySuccessView: View {
    let wish: PublicWishDTO
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignSystem.spacing24) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(DesignSystem.success)
                .accessibilityHidden(true)
            VStack(spacing: DesignSystem.spacing8) {
                Text("响应已提交")
                    .font(DesignSystem.titleFont)
                    .foregroundStyle(DesignSystem.ink900)
                Text("已收到响应，等待运营确认，不代表已经接单。")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.ink700)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("\(wish.city) · \(wish.landmark)")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
                Text(wish.message)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
                    .lineLimit(2)
            }
            .padding(DesignSystem.spacing16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
            .padding(.horizontal, DesignSystem.spacing24)
            Spacer()
            Button("我知道了") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, DesignSystem.spacing24)
                .padding(.bottom, DesignSystem.spacing24)
        }
        .navigationBarBackButtonHidden(true)
        .warmBackground()
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: DesignSystem.spacing8) {
                Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                    .font(.body.weight(.regular))
                    .foregroundStyle(configuration.isOn ? DesignSystem.accent : DesignSystem.ink500)
                    .accessibilityHidden(true)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "已同意" : "未同意")
    }
}

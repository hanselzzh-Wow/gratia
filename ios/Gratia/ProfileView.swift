import SwiftUI
import GratiaCore

/// 我的：个人资料、我发布的、我帮助的及对应进度。
/// "进度"不再是独立栏目——个人事务收进这里。
struct ProfileView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI
    @Environment(\.openURL) private var openURL
    @State private var showHelpView = false
    @State private var showPrivacyView = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    AccountSectionView(viewModel: accountViewModel)
                    activitySection
                    supportSection
                    aboutCard
                    // 退出与删除是低频且危险的动作，放在页面末尾，
                    // 不与个人资料争夺顶部的视觉权重。
                    if accountViewModel.isSignedIn { accountActionsSection }
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .sheet(isPresented: $showHelpView) { HelpAndSafetyView() }
            .sheet(isPresented: $showPrivacyView) { PrivacyPolicyView() }
            .confirmationDialog("确定要删除账户吗？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除账户", role: .destructive) { Task { _ = await accountViewModel.deleteAccount() } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法撤销。你将立即退出登录，之后无法再通过此账户查看自己的心愿与帮助记录。")
            }
        }
    }

    private var accountActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("账户").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)

            Button { accountViewModel.signOut() } label: {
                HStack {
                    Text("退出登录").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink)
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(DesignSystem.captionFont)
                        .foregroundStyle(DesignSystem.Rose.ink3)
                }
                .padding(DesignSystem.spacing16)
                .frame(maxWidth: .infinity)
                .roseCard()
            }
            .buttonStyle(.plain)

            Button { showDeleteConfirmation = true } label: {
                HStack {
                    Text("删除我的账户").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.danger)
                    Spacer()
                    if accountViewModel.state == .deleting {
                        SwiftUI.ProgressView().controlSize(.small)
                    }
                }
                .padding(DesignSystem.spacing16)
                .frame(maxWidth: .infinity)
                .roseCard()
            }
            .buttonStyle(.plain)
            .disabled(accountViewModel.isBusy)

            Text("删除后无法撤销。登录身份会被清除，所有会话立即失效，记录中的称呼会被匿名化。")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.Rose.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignSystem.spacing4)
        }
    }

    private func makeActivityViewModel() -> AccountActivityViewModel {
        AccountActivityViewModel(
            accountAPI: accountAPI,
            accessToken: { [weak accountViewModel] in accountViewModel?.accessToken }
        )
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("我的心愿").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
            NavigationLink {
                MyActivityView(
                    kind: .published,
                    selectedTab: $selectedTab,
                    activityViewModel: makeActivityViewModel()
                )
            } label: {
                activityRow(
                    title: "我发布的",
                    detail: "查看进度、时间线与交付",
                    icon: "paperplane"
                )
            }
            NavigationLink {
                MyActivityView(
                    kind: .helped,
                    selectedTab: $selectedTab,
                    activityViewModel: makeActivityViewModel()
                )
            } label: {
                activityRow(
                    title: "我帮助的",
                    detail: "我响应过的心愿与完成记录",
                    icon: "TabHandshake",
                    isAsset: true
                )
            }
        }
    }

    private func activityRow(title: String, detail: String, icon: String, isAsset: Bool = false) -> some View {
        HStack(spacing: DesignSystem.spacing12) {
            Group {
                if isAsset {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 21, height: 21)
                } else {
                    Image(systemName: icon)
                        .font(.body.weight(.regular))
                }
            }
            .foregroundStyle(DesignSystem.Rose.primary)
            .frame(width: 26)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text(title).font(DesignSystem.bodyFont.weight(.semibold)).foregroundStyle(DesignSystem.Rose.ink)
                Text(detail).font(DesignSystem.captionFont).foregroundStyle(DesignSystem.Rose.ink2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.Rose.ink3)
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity)
        .roseCard()
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("服务与支持").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
            Button { showHelpView = true } label: { supportRow(title: "帮助与安全中心", icon: "shield") }
            Button { showPrivacyView = true } label: { supportRow(title: "隐私政策与条款", icon: "document") }
            Button { openNotificationSettings() } label: {
                supportRow(title: "消息通知设置", icon: "bell", trailing: "去系统设置")
            }
        }
    }

    /// 通知开关由系统持有，App 只能把用户送到本应用的系统设置页。
    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func supportRow(title: String, icon: String, trailing: String? = nil) -> some View {
        HStack(spacing: DesignSystem.spacing12) {
            Image(systemName: icon).font(.body.weight(.regular)).foregroundStyle(DesignSystem.Rose.primary).frame(width: 24)
            Text(title).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink)
            Spacer()
            if let trailing { Text(trailing).font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.Rose.ink3) }
            Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.Rose.ink3)
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity)
        .roseCard()
    }

    private var aboutCard: some View {
        HStack {
            Text("关于哈喽卧得").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink)
            Spacer()
            Text("V1.0.0 (Build 1)").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.Rose.ink3)
        }
        .padding(DesignSystem.spacing16)
        .roseCard()
    }
}

// MARK: - 我发布的 / 我帮助的

/// 已登录时展示服务端返回的真实本人记录；
/// 未登录时不伪造任何本地数据，直接引导登录，并保留公开编号查询作为兼容找回。
struct MyActivityView: View {
    enum Kind {
        case published
        case helped

        var title: String { self == .published ? "我发布的" : "我帮助的" }
    }

    let kind: Kind
    @Binding var selectedTab: Int
    @Environment(\.wishAPIClient) private var apiClient
    @Environment(\.accountAPIClient) private var accountAPI
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @StateObject private var activityViewModel: AccountActivityViewModel
    @State private var statusFilter: ActivityStatusFilter = .waiting
    @State private var showTrackSheet = false
    /// 待公开到首页的心愿；非 nil 时弹出公开确认。
    @State private var storyWish: AccountWishDTO?
    /// 待选择帮助者的心愿；非 nil 时弹出选人列表。
    @State private var selectingWish: AccountWishDTO?
    /// 待提交交付的响应；非 nil 时弹出上传界面。
    @State private var deliveringResponse: DeliveryTarget?

    init(kind: Kind, selectedTab: Binding<Int>, activityViewModel: AccountActivityViewModel) {
        self.kind = kind
        _selectedTab = selectedTab
        _activityViewModel = StateObject(wrappedValue: activityViewModel)
    }

    private var filteredRequests: [AccountWishDTO] {
        activityViewModel.requests.filter { statusFilter.matches($0.status) }
    }

    private var filteredResponses: [AccountResponseDTO] {
        activityViewModel.responses.filter { statusFilter.matches($0.wish.status) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                statusChips
                content
                if kind == .published {
                    trackEntry
                } else {
                    helpEntry
                }
            }
            .padding(DesignSystem.spacing20)
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(DesignSystem.Rose.canvas.ignoresSafeArea())
        .refreshable { activityViewModel.load() }
        .task(id: accountViewModel.isSignedIn) { activityViewModel.load() }
        .onDisappear { activityViewModel.cancelLoad() }
        .sheet(isPresented: $showTrackSheet) {
            // 保留公开编号 + 联系方式的兼容查询流程。
            ProgressView(apiClient: apiClient)
        }
        .sheet(item: $storyWish) { wish in
            PublishStorySheet(wish: wish) { activityViewModel.load() }
        }
        .sheet(item: $selectingWish) { wish in
            SelectResponderSheet(wishId: wish.id)
        }
        .sheet(item: $deliveringResponse) { target in
            DeliverySubmitSheet(wishId: target.wishId)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch activityViewModel.state {
        case .idle, .loading:
            loadingContent
        case .requiresSignIn:
            SignInPromptView(
                viewModel: accountViewModel,
                reason: kind == .published
                    ? "登录后可以看到你发布过的全部心愿、进度与交付。"
                    : "登录后可以看到你响应过的全部心愿与结果。"
            )
        case .failed(let message):
            failureContent(message)
        case .loaded:
            loadedContent
        }
    }

    private var loadingContent: some View {
        HStack(spacing: DesignSystem.spacing8) {
            SwiftUI.ProgressView().controlSize(.small)
            Text("正在加载…").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.spacing32)
    }

    private func failureContent(_ message: String) -> some View {
        VStack(spacing: DesignSystem.spacing12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(DesignSystem.danger)
            Text(message)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .multilineTextAlignment(.center)
            Button("重试") { activityViewModel.load() }
                .font(DesignSystem.bodyFont.weight(.semibold))
                .foregroundStyle(DesignSystem.Rose.deep)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.spacing32)
    }

    @ViewBuilder
    private var loadedContent: some View {
        if kind == .published {
            if filteredRequests.isEmpty {
                emptyContent
            } else {
                VStack(spacing: DesignSystem.spacing12) {
                    ForEach(filteredRequests) { wish in requestRow(wish) }
                }
            }
        } else {
            if filteredResponses.isEmpty {
                emptyContent
            } else {
                VStack(spacing: DesignSystem.spacing12) {
                    ForEach(filteredResponses) { response in responseRow(response) }
                }
            }
        }
    }

    private func requestRow(_ wish: AccountWishDTO) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            HStack {
                Text(wish.publicCode)
                    .font(DesignSystem.bodyFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.Rose.ink)
                Spacer()
                Text(wish.status.label)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.Rose.deep)
                    .padding(.horizontal, DesignSystem.spacing8)
                    .frame(minHeight: 24)
                    .background(Capsule().fill(DesignSystem.Rose.tint))
            }
            Text("\(wish.city) · \(wish.landmark)")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
            Text(wish.message)
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .lineLimit(2)

            // 有人响应时直接给出提示与入口，不让发布者只能靠翻私聊才发现。
            if let count = wish.responseCount, count > 0 {
                HStack(spacing: DesignSystem.spacing4) {
                    Image(systemName: "person.2").font(DesignSystem.captionFont)
                    Text("\(count) 人已响应")
                        .font(DesignSystem.metadataFont.weight(.semibold))
                }
                .foregroundStyle(DesignSystem.Rose.primary)
            }

            if wish.canSelectResponder == true {
                Button { selectingWish = wish } label: {
                    Text("选择帮助者")
                        .font(DesignSystem.bodyFont.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .fill(DesignSystem.Rose.primary)
                        )
                }
                .accessibilityLabel("为心愿 \(wish.publicCode) 选择帮助者")
            }

            if wish.canConfirmCompletion {
                Button {
                    Task { await activityViewModel.confirmCompletion(wishId: wish.id) }
                } label: {
                    HStack {
                        Spacer()
                        if activityViewModel.confirmingWishId == wish.id {
                            SwiftUI.ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Text("确认已完成").font(DesignSystem.bodyFont.weight(.semibold)).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .fill(DesignSystem.Rose.primary)
                    )
                }
                .disabled(activityViewModel.confirmingWishId != nil)
                .accessibilityLabel("确认心愿 \(wish.publicCode) 已完成")
            }

            // 完成之后由发布者单独决定是否公开到首页，默认不公开。
            // 这是首页故事流唯一的内容来源。
            if wish.status == .completed {
                Button { storyWish = wish } label: {
                    HStack(spacing: DesignSystem.spacing8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("公开到首页")
                    }
                    .font(DesignSystem.bodyFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.Rose.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .stroke(DesignSystem.Rose.primary, lineWidth: 1)
                    )
                }
                .accessibilityLabel("把心愿 \(wish.publicCode) 公开到首页")
            }
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roseCard()
    }

    private func responseRow(_ response: AccountResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            HStack {
                Text(response.wish.publicCode)
                    .font(DesignSystem.bodyFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.Rose.ink)
                Spacer()
                Text(response.statusLabel)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.Rose.deep)
                    .padding(.horizontal, DesignSystem.spacing8)
                    .frame(minHeight: 24)
                    .background(Capsule().fill(DesignSystem.Rose.tint))
            }
            Text("\(response.wish.city) · \(response.wish.landmark)")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
            Text(response.wish.message)
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .lineLimit(2)
            Text("心愿当前状态：\(response.wish.status.label)")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.Rose.ink3)

            // 被选中后直接给出提交交付的入口，不必让帮助者去私聊里翻菜单。
            if response.canDeliver == true, let responseId = response.responseId {
                Button { deliveringResponse = DeliveryTarget(wishId: response.wish.id, responseId: responseId) } label: {
                    Text("完成帮助并提交交付")
                        .font(DesignSystem.bodyFont.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .fill(DesignSystem.Rose.primary)
                        )
                }
                .accessibilityLabel("为心愿 \(response.wish.publicCode) 提交交付")
            }
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roseCard()
    }


    private var statusChips: some View {
        HStack(spacing: DesignSystem.spacing8) {
            ForEach(ActivityStatusFilter.allCases, id: \.self) { filter in
                Button {
                    statusFilter = filter
                } label: {
                    Text(filter.rawValue)
                        .font(DesignSystem.metadataFont.weight(statusFilter == filter ? .semibold : .regular))
                        .foregroundStyle(statusFilter == filter ? DesignSystem.Rose.deep : DesignSystem.Rose.ink2)
                        .padding(.horizontal, DesignSystem.spacing12)
                        .frame(minHeight: 32)
                        .background(
                            Capsule()
                                .fill(statusFilter == filter ? DesignSystem.Rose.tint : DesignSystem.Rose.canvas)
                                .overlay(
                                    Capsule().stroke(
                                        statusFilter == filter ? DesignSystem.Rose.soft : DesignSystem.Rose.line,
                                        lineWidth: 1
                                    )
                                )
                        )
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityAddTraits(statusFilter == filter ? [.isSelected] : [])
            }
        }
    }

    private var emptyContent: some View {
        VStack(spacing: DesignSystem.spacing8) {
            Image(systemName: "tray")
                .font(.title3)
                .foregroundStyle(DesignSystem.Rose.ink3)
            Text("没有\(statusFilter.rawValue)的记录")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
            Text(kind == .published ? "发布心愿后会出现在这里。" : "响应他人的心愿后会出现在这里。")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.Rose.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.spacing32)
    }

    private var trackEntry: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("查询心愿进度")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.Rose.ink)
            Text("使用发布成功时的公开编号和联系方式，可以查看真实状态、时间线与交付内容。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .lineSpacing(2)
            Button {
                showTrackSheet = true
            } label: {
                Text("用公开编号查询")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .fill(DesignSystem.Rose.primary)
                    )
            }
        }
        .padding(DesignSystem.spacing20)
        .roseCard(radius: DesignSystem.radiusLarge)
    }

    private var helpEntry: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("去帮一个心愿")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.Rose.ink)
            Text("附近有人正在等待帮助；响应经运营确认后，完成记录会出现在这里。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .lineSpacing(2)
            Button {
                dismiss()
                selectedTab = 1  // 帮助页
            } label: {
                Text("去看看谁需要帮助")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .fill(DesignSystem.Rose.primary)
                    )
            }
        }
        .padding(DesignSystem.spacing20)
        .roseCard(radius: DesignSystem.radiusLarge)
    }
}

// MARK: - Rose 卡片样式

extension View {
    func roseCard(radius: CGFloat = DesignSystem.radiusMedium) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius)
                .fill(DesignSystem.Rose.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(DesignSystem.Rose.line, lineWidth: 1)
                )
        )
    }
}

struct HelpAndSafetyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                    informationCard(title: "安全原则", body: "只接受合法、善意、安全的请求。平台禁止发布危险活动、侵犯他人隐私、商业推销或违反法律法规的内容。所有公开内容都要经过人工审核后才会展示。")
                    // 举报与屏蔽必须在安全中心里写清楚：App 内含陌生人即时通讯时，
                    // App Store 审核指南 1.2 要求提供举报机制并对举报作出响应。
                    informationCard(
                        title: "举报与屏蔽",
                        body: "在任何一段私聊里点右上角「⋯」，可以举报对方或直接屏蔽。举报后我们会人工查看该会话并处理，通常在 24 小时内响应；屏蔽后双方立即无法再联系，会话也会从两人的列表中消失。你也可以发邮件到 hansel.zzh@gmail.com 举报。"
                    )
                    informationCard(
                        title: "隐私声明",
                        body: "我们不向你索取微信或手机号。沟通与交付都在应用内完成，你和对方都看不到彼此的联系方式。公开的心愿与故事只显示城市和地标，不含精确位置。"
                    )
                    faqCard
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("帮助与安全中心")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() }.foregroundStyle(DesignSystem.Rose.deep) } }
        }
    }

    private func informationCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(title).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
            Text(body).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink2).lineSpacing(3)
        }
        .padding(DesignSystem.spacing20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roseCard()
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("常见问题").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
            DisclosureGroup("提交心愿后多久能完成？") { Text("心愿提交后会先进行安全审核，再依据城市与地标匹配附近愿意帮忙的人。") }
            DisclosureGroup("响应者没有按时完成怎么办？") { Text("可以先在私聊里直接沟通。若对方长时间没有回应，你可以重新选择其他帮助者；遇到骚扰或不当行为，请在私聊里举报。") }
            DisclosureGroup("交付的文件格式是什么？") { Text("帮助者可以提交一段文字和最多 9 个照片或视频。内容只对你可见；是否公开到首页由你单独决定，且需要经过人工审核。") }
        }
        .font(DesignSystem.bodyFont)
        .foregroundStyle(DesignSystem.Rose.ink2)
        .padding(DesignSystem.spacing20)
        .roseCard()
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                    Text("哈喽卧得（Gratia）隐私政策与服务条款").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.Rose.ink)
                    Text("最后更新：2026-08-03").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.Rose.ink3)
                    policySection("信息收集", "我们仅在发布或响应心愿时收集称呼、联系方式，以及城市、地标和文字、图片、视频等内容，用于人工审核、匹配、派单与交付。联系方式从不出现在任何公开页面。")
                    policySection("登录信息", "使用 Sign in with Apple 登录时，我们只接收 Apple 提供的匿名用户标识，用于识别你的账户。我们不请求、不接收、不保存你的姓名和邮箱。")
                    policySection("系统权限", "仅在你主动点击「保存到相册」时申请相册的「仅添加」权限，用于保存你收到的交付照片。该权限在技术上无法读取你相册中的既有内容。本版本不申请定位、通讯录、相机或麦克风。")
                    policySection("信息共享", "未经明示同意，我们不会向无关第三方披露你的真实身份或联系方式。我们不含广告或分析 SDK，不做跨应用追踪，也不会出售你的数据。")
                    policySection("数据存储", "订单和交付文件由受控服务保存，交付访问链接不在公开页面展示或长期保存。登录凭据只保存在本机钥匙串，不同步到 iCloud。")
                    policySection("费用说明", "本应用完全免费，不涉及任何金额。App 内没有支付、没有应用内购买、没有任何形式的收费或金额申报，也不收集任何支付信息。响应者是自愿提供帮助的个人。")
                    policySection("你的权利", "你可以随时在「我的 → 账户」中退出登录或删除账户。删除后登录身份会被清除、所有会话立即失效，已有记录中的称呼与联系方式会被匿名化；为完成中的履约与审计，去标识后的订单记录会保留。删除不可撤销。")
                    policySection("服务性质", "本平台是信息撮合平台，不是劳务派遣或代购服务商。响应者是自愿提供帮助的个人，不是平台员工。心愿的实际完成结果由响应者本人负责，平台负责审核、撮合、跟进与争议协调。")
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("条款与协议")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() }.foregroundStyle(DesignSystem.Rose.deep) } }
        }
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(title).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
            Text(body).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink2).lineSpacing(3)
        }
        .padding(DesignSystem.spacing20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roseCard()
    }
}


/// 「我帮助的」里触发交付上传所需的定位信息。
struct DeliveryTarget: Identifiable {
    let wishId: String
    let responseId: String
    var id: String { responseId }
}

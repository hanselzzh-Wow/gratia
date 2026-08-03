import SwiftUI
import GratiaCore

/// 我的：个人资料、我发布的、我帮助的及对应进度。
/// "进度"不再是独立栏目——个人事务收进这里。
struct ProfileView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.openURL) private var openURL
    @State private var showHelpView = false
    @State private var showPrivacyView = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    AccountSectionView(viewModel: accountViewModel)
                    activitySection
                    supportSection
                    aboutCard
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .sheet(isPresented: $showHelpView) { HelpAndSafetyView() }
            .sheet(isPresented: $showPrivacyView) { PrivacyPolicyView() }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("我的心愿").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
            NavigationLink {
                MyActivityView(kind: .published, selectedTab: $selectedTab)
            } label: {
                activityRow(
                    title: "我发布的",
                    detail: "查看进度、时间线与交付",
                    icon: "paperplane"
                )
            }
            NavigationLink {
                MyActivityView(kind: .helped, selectedTab: $selectedTab)
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

/// 无账户阶段的诚实呈现：不伪造本地记录，
/// 发布的心愿通过公开编号 + 联系方式查询真实进度。
struct MyActivityView: View {
    enum Kind {
        case published
        case helped

        var title: String { self == .published ? "我发布的" : "我帮助的" }
    }

    enum StatusFilter: String, CaseIterable {
        case waiting = "等待回应"
        case active = "进行中"
        case done = "已完成"
    }

    let kind: Kind
    @Binding var selectedTab: Int
    @Environment(\.wishAPIClient) private var apiClient
    @Environment(\.dismiss) private var dismiss
    @State private var statusFilter: StatusFilter = .waiting
    @State private var showTrackSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                statusChips
                emptyContent
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
        .sheet(isPresented: $showTrackSheet) {
            // 复用现有真实查询流程（TrackWishViewModel + 交付预览）。
            ProgressView(apiClient: apiClient)
        }
    }

    private var statusChips: some View {
        HStack(spacing: DesignSystem.spacing8) {
            ForEach(StatusFilter.allCases, id: \.self) { filter in
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
            Text("此设备上没有\(statusFilter.rawValue)的记录")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
            Text("为保护隐私，记录不在设备上聚合；账户体系上线后可在此同步。")
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
                selectedTab = 3
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
                    informationCard(title: "安全原则", body: "只接受合法、善意、安全的请求。平台禁止发布危险活动、侵犯他人隐私、商业推销或违反法律法规的内容。")
                    informationCard(title: "隐私声明", body: "发布者和响应者的微信或电话等敏感联系方式不会公开；仅在人工匹配成功后由平台人员用于协调及派单。")
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
            DisclosureGroup("提交心愿后多久能完成？") { Text("心愿提交后会先进行安全审核，再依据地标与感谢金匹配附近响应者。") }
            DisclosureGroup("响应者没有按时完成怎么办？") { Text("如发生异常，平台会协调更新状态或重新进入匹配队列。") }
            DisclosureGroup("交付的文件格式是什么？") { Text("交付形式依心愿约定而定，链接仅在对应查询结果中安全预览。") }
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
                    Text("最后更新：2026-07-17").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.Rose.ink3)
                    policySection("信息收集", "我们仅在发布或响应心愿时收集必要联系方式以及文字、图片、视频等内容，用于审核、匹配、派单与交付。")
                    policySection("信息共享", "未经明示同意，我们不会向无关第三方披露你的真实身份或联系方式。")
                    policySection("数据存储", "订单和交付文件由受控服务保存，交付访问能力不在公开页面展示或长期保存。")
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

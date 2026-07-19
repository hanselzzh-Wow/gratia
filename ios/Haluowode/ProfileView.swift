import SwiftUI
import HaluowodeCore

struct ProfileView: View {
    @State private var showHelpView = false
    @State private var showPrivacyView = false
    @Environment(\.wishAPIClient) private var apiClient

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    accountCard
                    myWishesSection
                    supportSection
                    aboutCard
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .whiteCanvas()
            .sheet(isPresented: $showHelpView) { HelpAndSafetyView() }
            .sheet(isPresented: $showPrivacyView) { PrivacyPolicyView() }
        }
    }

    /// “我发布的 / 我帮助的” both lead to the real progress query
    /// (public code + contact); no local history is aggregated or faked.
    private var myWishesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("我的心愿").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
            NavigationLink {
                ProgressView(apiClient: apiClient)
            } label: {
                wishEntryRow(
                    title: "我发布的",
                    detail: "用公开编号和联系方式查询进度与交付",
                    icon: "paperplane"
                )
            }
            .buttonStyle(.plain)
            NavigationLink {
                ProgressView(apiClient: apiClient)
            } label: {
                wishEntryRow(
                    title: "我帮助的",
                    detail: "查询我响应过的心愿的当前状态",
                    icon: "hand.raised"
                )
            }
            .buttonStyle(.plain)
            Text("为保护隐私，记录不在此设备聚合；查询需要发布或响应时留下的公开编号与联系方式。")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.inkMuted)
                .lineSpacing(2)
        }
    }

    private func wishEntryRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.spacing12) {
            Image(systemName: icon)
                .font(.body.weight(.regular))
                .foregroundStyle(DesignSystem.rose)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text(title).font(DesignSystem.bodyFont.weight(.semibold)).foregroundStyle(DesignSystem.inkPrimary)
                Text(detail).font(DesignSystem.captionFont).foregroundStyle(DesignSystem.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.inkMuted)
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity, minHeight: 44)
        .roseCard(radius: DesignSystem.radiusMedium)
        .contentShape(Rectangle())
    }

    private var accountCard: some View {
        HStack(spacing: DesignSystem.spacing16) {
            Image(systemName: "person.crop.circle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(DesignSystem.rose)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text("访客模式").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.inkPrimary)
                Text("账户体系将在后续版本开放。当前可直接发布、响应和查询心愿。")
                    .font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.inkMuted).lineSpacing(2)
            }
        }
        .padding(DesignSystem.spacing20)
        .roseCard(radius: DesignSystem.radiusLarge)
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("服务与支持").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
            Button { showHelpView = true } label: { supportRow(title: "帮助与安全中心", icon: "shield") }
            Button { showPrivacyView = true } label: { supportRow(title: "隐私政策与条款", icon: "document") }
            supportRow(title: "消息通知设置", icon: "bell", trailing: "去系统设置")
        }
    }

    private func supportRow(title: String, icon: String, trailing: String? = nil) -> some View {
        HStack(spacing: DesignSystem.spacing12) {
            Image(systemName: icon).font(.body.weight(.regular)).foregroundStyle(DesignSystem.rose).frame(width: 24)
            Text(title).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.inkPrimary)
            Spacer()
            if let trailing { Text(trailing).font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.inkMuted) }
            Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.inkMuted)
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity)
        .roseCard(radius: DesignSystem.radiusMedium)
    }

    private var aboutCard: some View {
        HStack {
            Text("关于哈喽卧得").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.inkPrimary)
            Spacer()
            Text("V1.0.0 (Build 1)").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.inkMuted)
        }
        .padding(DesignSystem.spacing16)
        .roseCard(radius: DesignSystem.radiusMedium)
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
            .whiteCanvas()
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() }.foregroundStyle(DesignSystem.rose) } }
        }
    }

    private func informationCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(title).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
            Text(body).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.inkMuted).lineSpacing(3)
        }
        .padding(DesignSystem.spacing20)
        .roseCard(radius: DesignSystem.radiusMedium)
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("常见问题").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
            DisclosureGroup("提交心愿后多久能完成？") { Text("心愿提交后会先进行安全审核，再依据地标与感谢金匹配附近响应者。") }
            DisclosureGroup("响应者没有按时完成怎么办？") { Text("如发生异常，平台会协调更新状态或重新进入匹配队列。") }
            DisclosureGroup("交付的文件格式是什么？") { Text("交付形式依心愿约定而定，链接仅在对应查询结果中安全预览。") }
        }
        .font(DesignSystem.bodyFont)
        .foregroundStyle(DesignSystem.inkMuted)
        .padding(DesignSystem.spacing20)
        .roseCard(radius: DesignSystem.radiusMedium)
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                    Text("哈喽卧得 隐私政策与服务条款").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.inkPrimary)
                    Text("最后更新：2026-07-17").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.inkMuted)
                    policySection("信息收集", "我们仅在发布或响应心愿时收集必要联系方式以及文字、图片、视频等内容，用于审核、匹配、派单与交付。")
                    policySection("信息共享", "未经明示同意，我们不会向无关第三方披露你的真实身份或联系方式。")
                    policySection("数据存储", "订单和交付文件由受控服务保存，交付访问能力不在公开页面展示或长期保存。")
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("条款与协议")
            .navigationBarTitleDisplayMode(.inline)
            .whiteCanvas()
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() }.foregroundStyle(DesignSystem.rose) } }
        }
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(title).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
            Text(body).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.inkMuted).lineSpacing(3)
        }
        .padding(DesignSystem.spacing20)
        .roseCard(radius: DesignSystem.radiusMedium)
    }
}

import SwiftUI

struct ProfileView: View {
    @State private var showHelpView = false
    @State private var showPrivacyView = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    accountCard
                    activityCard
                    supportSection
                    aboutCard
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .warmBackground()
            .sheet(isPresented: $showHelpView) { HelpAndSafetyView() }
            .sheet(isPresented: $showPrivacyView) { PrivacyPolicyView() }
        }
    }

    private var accountCard: some View {
        HStack(spacing: DesignSystem.spacing16) {
            Image(systemName: "person.crop.circle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(DesignSystem.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text("访客模式").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.ink900)
                Text("账户体系将在后续版本开放。当前可直接发布、响应和查询心愿。")
                    .font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink700).lineSpacing(2)
            }
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            Text("心愿记录").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
            HStack(spacing: 0) {
                activityMetric(value: "—", label: "我的发布")
                Divider().overlay(DesignSystem.hairline)
                activityMetric(value: "—", label: "我的响应")
            }
            Text("为保护隐私，记录暂不在此设备聚合；请使用公开编号和联系方式在“进度”中查询。")
                .font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink700).lineSpacing(2)
        }
        .padding(DesignSystem.spacing20)
        .v3Card()
    }

    private func activityMetric(value: String, label: String) -> some View {
        VStack(spacing: DesignSystem.spacing4) {
            Text(value).font(DesignSystem.titleFont).foregroundStyle(DesignSystem.ink900)
            Text(label).font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink700)
        }
        .frame(maxWidth: .infinity)
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("服务与支持").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
            Button { showHelpView = true } label: { supportRow(title: "帮助与安全中心", icon: "shield") }
            Button { showPrivacyView = true } label: { supportRow(title: "隐私政策与条款", icon: "document") }
            supportRow(title: "消息通知设置", icon: "bell", trailing: "去系统设置")
        }
    }

    private func supportRow(title: String, icon: String, trailing: String? = nil) -> some View {
        HStack(spacing: DesignSystem.spacing12) {
            Image(systemName: icon).font(.body.weight(.regular)).foregroundStyle(DesignSystem.accent).frame(width: 24)
            Text(title).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.ink900)
            Spacer()
            if let trailing { Text(trailing).font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink500) }
            Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.ink500)
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity)
        .v3Card()
    }

    private var aboutCard: some View {
        HStack {
            Text("关于哈喽卧得").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.ink900)
            Spacer()
            Text("V1.0.0 (Build 1)").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink500)
        }
        .padding(DesignSystem.spacing16)
        .v3Card()
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
            .warmBackground()
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() }.foregroundStyle(DesignSystem.accent) } }
        }
    }

    private func informationCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(title).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
            Text(body).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.ink700).lineSpacing(3)
        }
        .padding(DesignSystem.spacing20)
        .v3Card()
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("常见问题").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
            DisclosureGroup("提交心愿后多久能完成？") { Text("心愿提交后会先进行安全审核，再依据地标与感谢金匹配附近响应者。") }
            DisclosureGroup("响应者没有按时完成怎么办？") { Text("如发生异常，平台会协调更新状态或重新进入匹配队列。") }
            DisclosureGroup("交付的文件格式是什么？") { Text("交付形式依心愿约定而定，链接仅在对应查询结果中安全预览。") }
        }
        .font(DesignSystem.bodyFont)
        .foregroundStyle(DesignSystem.ink700)
        .padding(DesignSystem.spacing20)
        .v3Card()
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                    Text("哈喽卧得 隐私政策与服务条款").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.ink900)
                    Text("最后更新：2026-07-17").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink500)
                    policySection("信息收集", "我们仅在发布或响应心愿时收集必要联系方式以及文字、图片、视频等内容，用于审核、匹配、派单与交付。")
                    policySection("信息共享", "未经明示同意，我们不会向无关第三方披露你的真实身份或联系方式。")
                    policySection("数据存储", "订单和交付文件由受控服务保存，交付访问能力不在公开页面展示或长期保存。")
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("条款与协议")
            .navigationBarTitleDisplayMode(.inline)
            .warmBackground()
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() }.foregroundStyle(DesignSystem.accent) } }
        }
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text(title).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
            Text(body).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.ink700).lineSpacing(3)
        }
        .padding(DesignSystem.spacing20)
        .v3Card()
    }
}

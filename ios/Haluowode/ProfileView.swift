import SwiftUI

struct ProfileView: View {
    @State private var isLoggedIn = false
    @State private var showHelpView = false
    @State private var showPrivacyView = false

    var body: some View {
        NavigationStack {
            List {
                // 1. User Header Section
                Section {
                    HStack(spacing: DesignSystem.spacing16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(DesignSystem.primaryBlue)

                        VStack(alignment: .leading, spacing: 4) {
                            if isLoggedIn {
                                Text("小白")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                Text("微信已绑定")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.textSecondary)
                            } else {
                                Text("未登录用户")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                Button(action: {
                                    withAnimation {
                                        isLoggedIn = true
                                    }
                                }) {
                                    Text("点击登录 / 注册")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(DesignSystem.primaryBlue)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 2. Data Entires (我的发布 / 我的响应)
                Section {
                    HStack {
                        VStack(spacing: 6) {
                            Text("0")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(DesignSystem.textNavy)
                            Text("我的发布")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        Divider()

                        VStack(spacing: 6) {
                            Text("0")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(DesignSystem.textNavy)
                            Text("我的响应")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }

                // 3. Settings & Help Section
                Section(header: Text("服务与支持")) {
                    Button(action: {
                        showHelpView = true
                    }) {
                        Label {
                            Text("帮助与安全中心")
                                .foregroundColor(DesignSystem.textNavy)
                        } icon: {
                            Image(systemName: "shield.fill")
                                .foregroundColor(DesignSystem.primaryBlue)
                        }
                    }

                    Button(action: {
                        showPrivacyView = true
                    }) {
                        Label {
                            Text("隐私政策与条款")
                                .foregroundColor(DesignSystem.textNavy)
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(DesignSystem.primaryBlue)
                        }
                    }

                    HStack {
                        Label {
                            Text("消息通知设置")
                                .foregroundColor(DesignSystem.textNavy)
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundColor(DesignSystem.primaryBlue)
                        }
                        Spacer()
                        Text("去系统设置")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                }

                // 4. App Version info
                Section {
                    HStack {
                        Text("关于哈喽卧得")
                            .foregroundColor(DesignSystem.textNavy)
                        Spacer()
                        Text("V1.0.0 (Build 1)")
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.textSecondary)
                    }

                    if isLoggedIn {
                        Button("退出当前登录", role: .destructive) {
                            withAnimation {
                                isLoggedIn = false
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("我的")
            .warmBackground()
            .sheet(isPresented: $showHelpView) {
                HelpAndSafetyView()
            }
            .sheet(isPresented: $showPrivacyView) {
                PrivacyPolicyView()
            }
        }
    }
}

// Help & Safety View
struct HelpAndSafetyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("安全原则")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("只接受合法、善意、安全的请求")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.textNavy)
                        Text("平台禁止发布任何涉及危险地带（如攀爬险峰）、侵犯他人隐私（如跟踪偷拍）、商业推销或违反法律法规的请求。")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("隐私声明")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("隐私绝对隔离，仅限履约使用")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.textNavy)
                        Text("发布者和响应者的微信或电话等敏感联系方式，完全对外界保密。仅在人工匹配成功后由平台官方人员用于协调及派单。")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("常见问题")) {
                    DisclosureGroup("Q: 提交心愿后多久能完成？") {
                        Text("心愿提交后将在4小时内进行安全审核。审核通过后，根据您设定的感谢金和地标热度匹配附近的响应者，中位匹配时长为6-12小时。")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                            .padding(.vertical, 4)
                    }
                    .foregroundColor(DesignSystem.textNavy)

                    DisclosureGroup("Q: 响应者没有按时完成怎么办？") {
                        Text("如果响应者由于异常情况无法前往或爽约，系统会退回匹配队列或退还款项。您随时可以通过微信人工客服协调最新进度。")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                            .padding(.vertical, 4)
                    }
                    .foregroundColor(DesignSystem.textNavy)

                    DisclosureGroup("Q: 交付的文件格式是什么？") {
                        Text("我们将按照您选定的交付形式提供，支持MP4高清视频、AAC音频或JPG高清图片，下载链接由专属能力令牌加固，保证他人无法查看。")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                            .padding(.vertical, 4)
                    }
                    .foregroundColor(DesignSystem.textNavy)
                }

                Section {
                    Button(action: {
                        // Contact CS action
                    }) {
                        Label("联系人工客服", systemImage: "message.fill")
                            .foregroundColor(DesignSystem.primaryBlue)
                    }

                    Button(action: {
                        // Report action
                    }) {
                        Label("违规内容举报 / 申诉", systemImage: "exclamationmark.bubble.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("帮助与安全中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.primaryBlue)
                }
            }
        }
    }
}

// Privacy Policy Placeholder View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                    Text("哈喽卧得 隐私政策与服务条款")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignSystem.textNavy)

                    Text("最后更新：2026-07-17")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.textSecondary)

                    Divider()

                    Text("哈喽卧得（下称“我们”）非常重视用户的隐私保护。在此我们承诺：")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.textNavy)

                    Text("1. 信息搜集：我们仅在您发布心愿或响应心愿时，收集您的必要联系方式（微信号/手机号）以及文字、图片、视频等内容。这些信息仅用于核心业务流转，包括审核、匹配、派单与交付。")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.textSecondary)
                        .lineSpacing(4)

                    Text("2. 信息共享：未经您的明示同意，我们不会向任何第三方公司、广告商或无关机构共享或披露您的个人真实身份和联系方式。")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.textSecondary)
                        .lineSpacing(4)

                    Text("3. 数据存储：心愿订单和交付文件均存储于 Cloudflare 生产级数据库 D1 和对象存储 R2 中。所有交付文件访问路径均附带防盗链的临时校验能力令牌，以防被无关人员爬取或访问。")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.textSecondary)
                        .lineSpacing(4)
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("条款与协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.primaryBlue)
                }
            }
            .background(DesignSystem.bgWarmWhite)
        }
    }
}

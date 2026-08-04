import AuthenticationServices
import SwiftUI
import GratiaCore

/// "我的"顶部的账户区：未登录显示 Sign in with Apple，已登录显示账户管理入口。
/// 浏览始终不需要登录；只有发布、帮助响应和本人记录需要账户。
struct AccountSectionView: View {
    @ObservedObject var viewModel: AccountViewModel
    @Environment(\.colorScheme) private var colorScheme
    /// 同一个 View 上挂多个 `.sheet` 在 SwiftUI 里会互相干扰，
    /// 统一收敛成一个由 item 驱动的弹层。
    private enum ActiveSheet: String, Identifiable {
        case signIn
        case accountSettings
        var id: String { rawValue }
    }

    @State private var activeSheet: ActiveSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            if viewModel.isSignedIn {
                signedInCard
                    .motionTransition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                signedOutCard
                    .motionTransition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.danger)
                    .accessibilityLabel("登录提示：\(errorMessage)")
                    .motionTransition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .motion(DesignSystem.Motion.content, value: viewModel.isSignedIn)
        .motion(DesignSystem.Motion.content, value: viewModel.errorMessage)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .signIn:
                SignInSheet(viewModel: viewModel)
            case .accountSettings:
                AccountSettingsView(viewModel: viewModel)
            }
        }
    }

    private var signedOutCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            HStack(spacing: DesignSystem.spacing16) {
                Circle()
                    .fill(DesignSystem.Rose.soft)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "person")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(DesignSystem.Rose.deep)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    Text("未登录").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.Rose.ink)
                    Text("浏览无需登录。登录后才能发布心愿、响应帮助，并在换设备后找回自己的记录。")
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.Rose.ink2)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("登录") { activeSheet = .signIn }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isBusy)

            Text("登录方式为「通过 Apple 登录」，我们只接收 Apple 提供的匿名用户标识，不获取你的姓名和邮箱。")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.Rose.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.spacing20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roseCard(radius: DesignSystem.radiusLarge)
    }

    private var signedInCard: some View {
        Button {
            activeSheet = .accountSettings
        } label: {
            HStack(spacing: DesignSystem.spacing16) {
                Circle()
                    .fill(DesignSystem.Rose.soft)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(DesignSystem.Rose.deep)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    Text("已通过 Apple 登录")
                        .font(DesignSystem.titleFont)
                        .foregroundStyle(DesignSystem.Rose.ink)
                    Text("管理账户与注销")
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.Rose.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.Rose.ink3)
            }
            .padding(DesignSystem.spacing20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .roseCard(radius: DesignSystem.radiusLarge)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("账户设置，已通过 Apple 登录")
    }
}

/// 账户设置：退出登录与删除账户。
/// 删除入口必须在应用内可直达，这是 App Store 审核指南 5.1.1(v) 的硬性要求。
struct AccountSettingsView: View {
    @ObservedObject var viewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    statusCard
                    signOutButton
                    deleteSection
                }
                .padding(DesignSystem.spacing20)
            }
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .navigationTitle("账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .confirmationDialog(
                "确定要删除账户吗？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("删除账户", role: .destructive) {
                    Task {
                        if await viewModel.deleteAccount() { dismiss() }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法撤销。你将立即退出登录，之后无法再通过此账户查看自己的心愿与帮助记录。")
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("登录方式").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
            Text("Sign in with Apple")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
            Text("我们不保存你的姓名、邮箱或 Apple ID，只保存一个用于识别本账户的匿名标识。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.spacing20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .roseCard(radius: DesignSystem.radiusLarge)
    }

    private var signOutButton: some View {
        Button {
            viewModel.signOut()
            dismiss()
        } label: {
            HStack {
                Text("退出登录").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink)
                Spacer()
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(DesignSystem.Rose.ink3)
            }
            .padding(DesignSystem.spacing16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .roseCard()
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy)
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("删除账户").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)

            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                deleteDetail("你的登录身份会被删除，所有登录状态立即失效。")
                deleteDetail("已发布的心愿和帮助记录中的称呼、联系方式会被匿名化。")
                deleteDetail("为了完成中的履约、投诉处理和财务审计，去标识后的订单记录会保留。")
                deleteDetail("删除后无法用原账户找回任何记录。")
            }
            .padding(DesignSystem.spacing16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .roseCard()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if viewModel.state == .deleting {
                        SwiftUI.ProgressView().controlSize(.small)
                    } else {
                        Text("删除我的账户").font(DesignSystem.bodyFont.weight(.semibold))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(DesignSystem.danger)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .stroke(DesignSystem.danger, lineWidth: 1)
                )
            }
            .disabled(viewModel.isBusy)
            .accessibilityLabel("删除我的账户")

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.danger)
            }
        }
    }

    private func deleteDetail(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundStyle(DesignSystem.Rose.ink3)
                .padding(.top, 7)
                .accessibilityHidden(true)
            Text(text)
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 需要登录才能继续时使用的轻量登录提示。
/// 这里只呈现品牌入口，Apple 官方按钮留到 `SignInSheet` 里——
/// 一进页面就甩一个黑色系统按钮既突兀，也浪费了品牌表达的位置。
struct SignInPromptView: View {
    @ObservedObject var viewModel: AccountViewModel
    let reason: String
    @State private var showSignIn = false

    var body: some View {
        VStack(spacing: DesignSystem.spacing16) {
            Text(reason)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("登录后继续") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isBusy)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.danger)
                    .multilineTextAlignment(.center)
                    .motionTransition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .motion(DesignSystem.Motion.content, value: viewModel.errorMessage)
        .padding(DesignSystem.spacing20)
        .frame(maxWidth: .infinity)
        .roseCard(radius: DesignSystem.radiusLarge)
        .sheet(isPresented: $showSignIn) {
            SignInSheet(viewModel: viewModel, reason: reason)
        }
    }
}

/// 全 App 共用的登录弹层。品牌先行，Apple 官方按钮按其设计规范原样呈现——
/// 规范允许先放自有入口再呈现官方按钮，但不允许改造按钮本身。
struct SignInSheet: View {
    @ObservedObject var viewModel: AccountViewModel
    var reason: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let benefits = [
        ("paperplane", "发布你的心愿，交给当地的人完成"),
        ("hands.sparkles", "响应别人的心愿，替他走一趟"),
        ("clock.arrow.circlepath", "换设备后仍能找回自己的记录"),
    ]

    var body: some View {
        VStack(spacing: DesignSystem.spacing24) {
            BrandMark()
                .frame(width: 64, height: 64)
                .padding(.top, DesignSystem.spacing32)
                .accessibilityHidden(true)

            VStack(spacing: DesignSystem.spacing8) {
                Text("登录哈喽卧得")
                    .font(DesignSystem.titleFont)
                    .foregroundStyle(DesignSystem.Rose.ink)
                Text(reason ?? "浏览不需要登录。只有发布心愿和响应帮助时，才需要一个账户。")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.Rose.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DesignSystem.spacing24)

            VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                ForEach(benefits, id: \.0) { icon, text in
                    HStack(spacing: DesignSystem.spacing12) {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(DesignSystem.Rose.primary)
                            .frame(width: 26)
                            .accessibilityHidden(true)
                        Text(text)
                            .font(DesignSystem.bodyFont)
                            .foregroundStyle(DesignSystem.Rose.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.spacing32)

            Spacer(minLength: 0)

            VStack(spacing: DesignSystem.spacing12) {
                SignInWithAppleButton(.signIn) { request in
                    viewModel.prepareAppleRequest(request)
                } onCompletion: { result in
                    Task { await viewModel.completeAppleSignIn(with: result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .disabled(viewModel.isBusy)
                .opacity(viewModel.isBusy ? 0.5 : 1)
                .accessibilityLabel("通过 Apple 登录")

                if viewModel.state == .signingIn {
                    HStack(spacing: DesignSystem.spacing8) {
                        SwiftUI.ProgressView().controlSize(.small)
                        Text("正在登录…")
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(DesignSystem.Rose.ink2)
                    }
                    .motionTransition(.opacity)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.danger)
                        .multilineTextAlignment(.center)
                        .motionTransition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Text("我们只接收 Apple 提供的匿名用户标识，不获取你的姓名和邮箱。")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.Rose.ink3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .motion(DesignSystem.Motion.content, value: viewModel.state)
            .padding(.horizontal, DesignSystem.spacing24)
            .padding(.bottom, DesignSystem.spacing32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.canvas.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: viewModel.isSignedIn) { _, signedIn in signedIn }
        .onChange(of: viewModel.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
    }
}

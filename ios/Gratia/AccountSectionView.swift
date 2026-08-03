import AuthenticationServices
import SwiftUI
import GratiaCore

/// "我的"顶部的账户区：未登录显示 Sign in with Apple，已登录显示账户管理入口。
/// 浏览始终不需要登录；只有发布、帮助响应和本人记录需要账户。
struct AccountSectionView: View {
    @ObservedObject var viewModel: AccountViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAccountSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            if viewModel.isSignedIn {
                signedInCard
            } else {
                signedOutCard
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.danger)
                    .accessibilityLabel("登录提示：\(errorMessage)")
            }
        }
        .sheet(isPresented: $showAccountSettings) {
            AccountSettingsView(viewModel: viewModel)
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

            SignInWithAppleButton(.signIn) { request in
                viewModel.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await viewModel.completeAppleSignIn(with: result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 48)
            .disabled(viewModel.isBusy)
            .opacity(viewModel.isBusy ? 0.5 : 1)
            .accessibilityLabel("通过 Apple 登录")

            if viewModel.state == .signingIn {
                HStack(spacing: DesignSystem.spacing8) {
                    ProgressView().controlSize(.small)
                    Text("正在登录…").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.Rose.ink2)
                }
            }

            Text("我们只接收 Apple 提供的匿名用户标识，不获取你的姓名和邮箱。")
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
            showAccountSettings = true
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
                        ProgressView().controlSize(.small)
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
struct SignInPromptView: View {
    @ObservedObject var viewModel: AccountViewModel
    let reason: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: DesignSystem.spacing16) {
            Text(reason)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            SignInWithAppleButton(.continue) { request in
                viewModel.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await viewModel.completeAppleSignIn(with: result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 48)
            .disabled(viewModel.isBusy)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.spacing20)
        .frame(maxWidth: .infinity)
        .roseCard(radius: DesignSystem.radiusLarge)
    }
}

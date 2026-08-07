import SwiftUI
import GratiaCore

/// 「私聊」标签页。需求方与帮助者在此直接沟通，不再由运营居中传话——
/// 运营居中意味着他是唯一同时持有双方联系方式的一方，反而是最大的暴露面。
struct ConversationsView: View {
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI
    @State private var conversations: [ConversationSummaryDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignIn = false

    var body: some View {
        NavigationStack {
            Group {
                if !accountViewModel.isSignedIn && !isDemo {
                    signedOutState
                } else if isLoading && conversations.isEmpty {
                    SwiftUI.ProgressView("正在加载会话")
                        .tint(DesignSystem.accent)
                        .font(DesignSystem.metadataFont)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .motionTransition(.opacity)
                } else if conversations.isEmpty {
                    emptyState.motionTransition(.opacity)
                } else {
                    list.motionTransition(.opacity)
                }
            }
            .motion(DesignSystem.Motion.content, value: conversations)
            .navigationTitle("私聊")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showSignIn) { SignInSheet(viewModel: accountViewModel) }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.spacing8) {
                ForEach(conversations) { conversation in
                    NavigationLink {
                        ChatView(summary: conversation)
                    } label: {
                        row(conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.spacing20)
        }
    }

    private func row(_ conversation: ConversationSummaryDTO) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing12) {
            // 有头像就显示头像，没有才回落到首字母
            CachedAvatar(
                url: conversation.counterpartAvatarUrl.flatMap(URL.init(string:)),
                size: 44
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                HStack {
                    Text(conversation.counterpartName)
                        .font(DesignSystem.bodyFont.weight(.semibold))
                        .foregroundStyle(DesignSystem.Rose.ink)
                    // 让人一眼看出自己在这段关系里是谁
                    Text(conversation.isRequester ? "我发布的" : "我帮助的")
                        .font(DesignSystem.captionFont)
                        .foregroundStyle(DesignSystem.Rose.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Rose.soft.opacity(0.6))
                        )
                    Spacer()
                    // 屏蔽过的会话仍然留在列表里，只是标出来——早先是直接
                    // 滤掉，屏蔽一个骚扰者的代价是把整段记录也弄丢。
                    // 只标「我屏蔽的」；对方屏蔽我时不标，进去自然发不出消息。
                    if conversation.blockedByMe ?? false {
                        Text("已屏蔽")
                            .font(DesignSystem.captionFont)
                            .foregroundStyle(DesignSystem.Rose.ink3)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Rose.tint))
                    } else {
                        Text(conversation.wishStatus.label)
                            .font(DesignSystem.captionFont)
                            .foregroundStyle(DesignSystem.Rose.ink3)
                    }
                }
                Text(conversation.title)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.Rose.ink2)
                    .lineLimit(1)
                Text(conversation.lastMessage ?? "还没有消息，打个招呼吧")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(conversation.lastMessage == nil ? DesignSystem.Rose.ink3 : DesignSystem.Rose.ink2)
                    .lineLimit(1)
            }
        }
        .padding(DesignSystem.spacing16)
        .frame(maxWidth: .infinity)
        .roseCard()
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(DesignSystem.Rose.ink3)
            Text("还没有会话")
                .font(DesignSystem.titleFont)
                .foregroundStyle(DesignSystem.Rose.ink)
            Text("你发布的心愿有人响应，或者你响应了别人的心愿之后，就可以在这里直接沟通细节。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignSystem.spacing32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var signedOutState: some View {
        VStack(spacing: DesignSystem.spacing16) {
            Text("登录后可以查看会话")
                .font(DesignSystem.titleFont)
                .foregroundStyle(DesignSystem.Rose.ink)
            Text("私聊只在你和对方之间进行，需要账户来确认身份。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .multilineTextAlignment(.center)
            Button("登录") { showSignIn = true }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.spacing32)
    }

    /// 截图用：演示会话不需要登录也能显示。Release 恒为 false。
    private var isDemo: Bool {
        #if DEBUG
        return DemoContent.isEnabled
        #else
        return false
        #endif
    }

    private func load() async {
        #if DEBUG
        if DemoContent.isEnabled {
            conversations = DemoContent.conversations
            return
        }
        #endif
        guard let token = accountViewModel.accessToken else {
            conversations = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await accountAPI.conversations(token: token)
            errorMessage = nil
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "加载会话失败，请下拉重试。"
        }
    }
}

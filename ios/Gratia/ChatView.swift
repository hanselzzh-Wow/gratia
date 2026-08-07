import SwiftUI
import GratiaCore

/// 一段会话。纯文字——交付走独立的上传通道，聊天里不传文件，
/// 既降低审核面，也避免用户把交付内容散落在聊天记录里。
struct ChatView: View {
    let summary: ConversationSummaryDTO

    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var conversation: ConversationDTO?
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var showResponders = false
    @State private var showDelivery = false

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
        }
        .background(DesignSystem.Rose.canvas.ignoresSafeArea())
        .navigationTitle(summary.counterpartName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if summary.isRequester {
                        Button("选择帮助者") { showResponders = true }
                    } else if conversation?.isSelected == true {
                        Button("完成帮助并提交交付") { showDelivery = true }
                    }
                    Divider()
                    Button("举报", role: .destructive) { showReport = true }
                    // 屏蔽是可撤销的：早先只有单向的「屏蔽」，一旦点下去
                    // 会话就消失且没有回头路。
                    if blockedByMe {
                        Button("取消屏蔽") { Task { await unblock() } }
                    } else {
                        Button("屏蔽对方", role: .destructive) { showBlockConfirm = true }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("更多操作")
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showReport) {
            ReportSheet(responseId: summary.responseId)
        }
        .sheet(isPresented: $showResponders) {
            SelectResponderSheet(wishId: summary.wishId)
        }
        .sheet(isPresented: $showDelivery) {
            DeliverySubmitSheet(wishId: summary.wishId)
        }
        .confirmationDialog("屏蔽后双方都不能再在这段对话里发消息。这段记录会保留，你可以随时取消屏蔽。",
                            isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("屏蔽对方", role: .destructive) { Task { await block() } }
            Button("取消", role: .cancel) {}
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignSystem.spacing8) {
                    if let conversation, conversation.messages.isEmpty {
                        Text(summary.isRequester
                             ? "对方响应了你的心愿。可以先确认时间、地点和你希望的呈现方式。"
                             : "打个招呼，确认一下心愿的细节吧。")
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(DesignSystem.Rose.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, DesignSystem.spacing32)
                            .padding(.horizontal, DesignSystem.spacing24)
                    }
                    ForEach(conversation?.messages ?? []) { message in
                        bubble(message).id(message.id)
                    }
                }
                .padding(DesignSystem.spacing20)
            }
            .motion(DesignSystem.Motion.content, value: conversation?.messages.count ?? 0)
            .onChange(of: conversation?.messages.count ?? 0) { _, _ in
                guard let last = conversation?.messages.last else { return }
                withAnimation(DesignSystem.Motion.adaptive(DesignSystem.Motion.content, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func bubble(_ message: ChatMessageDTO) -> some View {
        HStack {
            if message.mine { Spacer(minLength: 48) }
            Text(message.body)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(message.mine ? .white : DesignSystem.Rose.ink)
                .padding(.horizontal, DesignSystem.spacing16)
                .padding(.vertical, DesignSystem.spacing12)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(message.mine ? DesignSystem.accent : DesignSystem.canvas)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .stroke(message.mine ? Color.clear : DesignSystem.hairline, lineWidth: 1)
                        )
                )
                .fixedSize(horizontal: false, vertical: true)
            if !message.mine { Spacer(minLength: 48) }
        }
        .motionTransition(.opacity.combined(with: .move(edge: message.mine ? .trailing : .leading)))
    }

    /// 我屏蔽了对方。对方屏蔽我时不显示这个——见下方 blockedNotice 的说明。
    private var blockedByMe: Bool { conversation?.blockedByMe ?? false }
    private var canSendMessages: Bool { conversation?.canSendMessages ?? true }

    /// 屏蔽状态下的输入区：不删除会话、不隐藏历史，只是发不出去。
    private var blockedNotice: some View {
        HStack(spacing: DesignSystem.spacing8) {
            Image(systemName: "hand.raised.slash")
            // 只在「我屏蔽了对方」时说明原因并给出出口。
            // 对方屏蔽我时**不明说**，只讲结果：挑明通常只会激化对立。
            // 但必须讲清「到此为止」——站内私聊是双方唯一的接触面，
            // 而帮助者可能正准备去现场，别让他白跑。
            if blockedByMe {
                Text("你已屏蔽对方，双方都无法再发送消息。")
                Spacer(minLength: 0)
                Button("取消屏蔽") { Task { await unblock() } }
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
            } else {
                Text("这段对话已无法发送新消息。")
                Spacer(minLength: 0)
            }
        }
        .font(DesignSystem.metadataFont)
        .foregroundStyle(DesignSystem.Rose.ink2)
        .padding(DesignSystem.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                .fill(DesignSystem.Rose.tint)
        )
    }

    private var composer: some View {
        VStack(spacing: DesignSystem.spacing8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .motionTransition(.opacity)
            }
            if !canSendMessages {
                blockedNotice
            } else {
            HStack(spacing: DesignSystem.spacing8) {
                TextField("说点什么…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    // 显式设色：默认的 .primary 是随系统外观变化的动态色，
                    // 而这里的底色是写死的浅色，暗色下会变成白字浅底。
                    .foregroundStyle(DesignSystem.Rose.ink)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, DesignSystem.spacing12)
                    .padding(.vertical, DesignSystem.spacing8)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .fill(DesignSystem.Rose.tint)
                    )
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? DesignSystem.accent : DesignSystem.Rose.ink3)
                }
                .disabled(!canSend)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("发送")
            }
            }
        }
        .motion(DesignSystem.Motion.content, value: errorMessage)
        .impactHaptic(conversation?.messages.count ?? 0)
        .padding(DesignSystem.spacing16)
        .background(DesignSystem.canvas)
        .overlay(Rectangle().fill(DesignSystem.hairline).frame(height: 1), alignment: .top)
    }

    private var canSend: Bool {
        canSendMessages && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func load() async {
        guard let token = accountViewModel.accessToken else { return }
        do {
            conversation = try await accountAPI.conversationMessages(responseId: summary.responseId, token: token)
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "加载消息失败。"
        }
    }

    private func send() async {
        guard let token = accountViewModel.accessToken else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        defer { isSending = false }
        do {
            _ = try await accountAPI.sendMessage(responseId: summary.responseId, body: text, token: token)
            draft = ""
            errorMessage = nil
            await load()
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "发送失败，请重试。"
        }
    }

    private func block() async {
        guard let token = accountViewModel.accessToken else { return }
        do {
            try await accountAPI.blockCounterpart(responseId: summary.responseId, token: token)
            // 不再 dismiss：屏蔽之后会话仍然留着，只是发不出消息。
            // 重新拉一次以更新屏蔽状态与输入区。
            await load()
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "屏蔽失败，请重试。"
        }
    }

    private func unblock() async {
        guard let token = accountViewModel.accessToken else { return }
        do {
            try await accountAPI.unblockCounterpart(responseId: summary.responseId, token: token)
            await load()
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "取消屏蔽失败，请重试。"
        }
    }
}

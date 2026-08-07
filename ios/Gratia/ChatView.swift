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
    /// 消息单独持有，不直接读 conversation.messages：
    /// 发送时要能立刻把一条「正在发送」插进来，而 ConversationDTO 是不可变的。
    @State private var messages: [ChatMessageDTO] = []
    @State private var showResponders = false
    @State private var showDelivery = false

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
        }
        .background(DesignSystem.Rose.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 标题位放对方的头像与昵称。原来这里只有一行文字，而帮助者看到的
            // 更是写死的「发布者」三个字——对面是个具体的人，不该只是个角色名。
            ToolbarItem(placement: .principal) {
                HStack(spacing: DesignSystem.spacing8) {
                    CachedAvatar(url: counterpartAvatarURL, size: 28)
                    Text(counterpartName)
                        .font(DesignSystem.headlineFont)
                        .foregroundStyle(DesignSystem.Rose.ink)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("与 \(counterpartName) 的对话")
            }
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
                    if conversation != nil, messages.isEmpty {
                        Text(summary.isRequester
                             ? "对方响应了你的心愿。可以先确认时间、地点和你希望的呈现方式。"
                             : "打个招呼，确认一下心愿的细节吧。")
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(DesignSystem.Rose.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, DesignSystem.spacing32)
                            .padding(.horizontal, DesignSystem.spacing24)
                    }
                    ForEach(messages) { message in
                        bubble(message).id(message.id)
                    }
                }
                .padding(DesignSystem.spacing20)
            }
            .motion(DesignSystem.Motion.content, value: messages.count)
            .onChange(of: messages.count) { _, _ in
                guard let last = messages.last else { return }
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

    /// 会话详情里的资料比列表更新，先用它；没加载出来时回落到列表带过来的。
    private var counterpartName: String {
        conversation?.counterpartName ?? summary.counterpartName
    }
    private var counterpartAvatarURL: URL? {
        let text = conversation?.counterpartAvatarUrl ?? summary.counterpartAvatarUrl
        return text.flatMap(URL.init(string:))
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
            let fresh = try await accountAPI.conversationMessages(responseId: summary.responseId, token: token)
            conversation = fresh
            // 保留还没落库的「正在发送」，否则一次后台刷新就会把它抹掉，
            // 用户会看到自己刚发的消息闪一下又不见了。
            let pending = messages.filter { $0.id.hasPrefix("pending-") }
            messages = fresh.messages + pending.filter { p in
                !fresh.messages.contains { $0.body == p.body && $0.mine }
            }
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "加载消息失败。"
        }
    }

    /// 乐观发送：先清空输入框、先把消息放上屏，再发请求。
    ///
    /// 原来是反过来的——等服务端回话才清空输入框，然后再整个重拉一遍会话。
    /// 在国际线路上那就是一两秒里字还杵在框里、按钮转圈；而重拉会把整个
    /// conversation 换掉，列表重建，气泡的滑入动画在数据替换时被打断。
    /// 聊天的发送必须是即时的，网络是它背后的事，不该让用户等。
    private func send() async {
        guard let token = accountViewModel.accessToken else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let pending = ChatMessageDTO(
            id: "pending-\(UUID().uuidString)",
            body: text,
            mine: true,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        draft = ""
        errorMessage = nil
        withAnimation(DesignSystem.Motion.adaptive(DesignSystem.Motion.content, reduceMotion: reduceMotion)) {
            messages.append(pending)
        }

        isSending = true
        defer { isSending = false }
        do {
            let saved = try await accountAPI.sendMessage(responseId: summary.responseId, body: text, token: token)
            // 用服务端那条替换临时的：id 与时间以服务端为准，但不重排版面。
            if let index = messages.firstIndex(where: { $0.id == pending.id }) {
                messages[index] = saved
            }
        } catch {
            // 失败要把内容还给用户，别让他重打一遍。
            messages.removeAll { $0.id == pending.id }
            if draft.isEmpty { draft = text }
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

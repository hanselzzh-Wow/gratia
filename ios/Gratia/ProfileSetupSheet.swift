import PhotosUI
import SwiftUI
import GratiaCore

/// 新用户登录后的首次资料设置。昵称与头像都必须填。
///
/// 为什么不能跳过：昵称与头像是私聊、响应列表、公开故事里唯一的身份线索。
/// 一个没设过的用户，在对方眼里是「哈喽卧得用户 + 灰色人像」——而这个产品
/// 恰恰要求双方在只有站内私聊这一条接触渠道的前提下，谈妥一件要到线下现场
/// 完成的事。分不清对面是谁，这件事就没法开始。
///
/// 但「必须设」不等于「必须上传自己的照片」：预设头像那一排是兜底，
/// 手边没有合适照片、或者不愿意露脸的人也能一步走完。
struct ProfileSetupSheet: View {
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI

    /// 完成后由外部关闭。刻意不提供 dismiss——这一步不能跳过。
    var onFinished: () -> Void

    @State private var displayName = ""
    @State private var presetSelection: Int?
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoPreview: Image?
    @State private var photoData: Data?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasAvatar: Bool { photoData != nil || presetSelection != nil }
    private var canSubmit: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 20 && hasAvatar && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    header
                    nameField
                    avatarSection
                    if let errorMessage {
                        Text(errorMessage)
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(DesignSystem.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .motionTransition(.opacity)
                    }
                    submitButton
                    Text("昵称和头像会出现在私聊、响应列表与公开故事里，因此需要经过人工审核后才对他人可见。选用上面的预设头像则无需审核，立即生效。")
                        .font(DesignSystem.captionFont)
                        .foregroundStyle(DesignSystem.Rose.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignSystem.spacing20)
            }
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .navigationTitle("设置你的身份")
            .navigationBarTitleDisplayMode(.inline)
            // 没有取消按钮，下拉也关不掉：这一步是必需的。
            .interactiveDismissDisabled(true)
            .motion(DesignSystem.Motion.content, value: errorMessage)
            .onChange(of: pickedPhoto) { _, _ in Task { await loadPhoto() } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("先给自己一个名字")
                .font(DesignSystem.titleFont)
                .foregroundStyle(DesignSystem.Rose.ink)
            Text("你要托付一件事给陌生人，或者替陌生人走一趟。对方需要知道自己在跟谁说话。")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            HStack {
                Text("昵称").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)
                Spacer()
                Text("\(trimmedName.count)/20")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(trimmedName.count > 20 ? DesignSystem.danger : DesignSystem.Rose.ink3)
            }
            TextField("1–20 个字", text: $displayName)
                // 默认的 .primary 会随系统外观变白，而底色是写死的浅玫色——
                // 暗色下就是白字浅底，等于看不见自己在打什么。
                .foregroundStyle(DesignSystem.Rose.ink)
                .focused($nameFocused)
                .submitLabel(.done)
                .padding(DesignSystem.spacing12)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.Rose.tint)
                )
        }
    }

    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("头像").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.Rose.ink)

            // 绑定成 preview 而不是同名：同名会把 @State 遮蔽成局部常量，
            // 下面「移除」按钮里的赋值就落到那个常量上，编译不过。
            if let preview = photoPreview {
                HStack(spacing: DesignSystem.spacing12) {
                    preview.resizable().scaledToFill()
                        .frame(width: 72, height: 72).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已选择你的照片").font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.Rose.ink)
                        Text("需经人工审核后其他人才会看到")
                            .font(DesignSystem.captionFont).foregroundStyle(DesignSystem.Rose.ink3)
                    }
                    Spacer()
                    Button("移除") {
                        photoData = nil
                        photoPreview = nil
                        pickedPhoto = nil
                    }
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.Rose.primary)
                }
            }

            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                HStack(spacing: DesignSystem.spacing8) {
                    Image(systemName: "photo").font(DesignSystem.captionFont)
                    Text(photoPreview == nil ? "从相册选一张" : "换一张")
                }
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.primary)
                .padding(DesignSystem.spacing12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.Rose.tint)
                )
            }

            Text(photoPreview == nil ? "或者挑一个" : "或者改用预设头像")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.Rose.ink3)

            PresetAvatarPicker(selection: $presetSelection)
                .onChange(of: presetSelection) { _, newValue in
                    // 两者互斥：选了预设就清掉相册那张，否则提交时不知道该用哪个。
                    if newValue != nil {
                        photoData = nil
                        photoPreview = nil
                        pickedPhoto = nil
                    }
                }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting { SwiftUI.ProgressView().controlSize(.small).tint(.white) }
                Text(isSubmitting ? "提交中…" : "完成")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSubmit)
    }

    private func loadPhoto() async {
        guard let item = pickedPhoto,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photoData = ProfileEditSheet.compressedAvatar(image) ?? data
        photoPreview = Image(uiImage: image)
        presetSelection = nil
    }

    private func submit() async {
        guard let token = accountViewModel.accessToken else {
            errorMessage = "登录状态已失效，请重新登录后再试。"
            return
        }
        // 预设图必须上传原始字节：重新编码会改变 SHA-256，服务端认不出它是
        // 预设图，于是这张头像会被丢进人工审核队列，用户白设一场。
        let avatar: Data? = photoData ?? presetSelection.flatMap(PresetAvatars.data)
        guard let avatar else {
            errorMessage = "请选择一个头像。"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        do {
            let updated = try await accountAPI.updateProfile(
                displayName: trimmedName,
                avatar: avatar,
                token: token
            )
            ProfileCache.save(updated)
            if let url = updated.avatarUrl.flatMap(URL.init(string:)) {
                AvatarCache.store(avatar, for: url)
            }
            onFinished()
        } catch let error as GratiaAPIError {
            // 重名与封禁都由服务端判定并给出可读文案，原样透出即可——
            // 客户端无从知道别人用了什么昵称，自己造话术只会和服务端说的不一致。
            errorMessage = error.errorDescription ?? "提交失败，请重试。"
        } catch {
            errorMessage = "提交失败，请重试。"
        }
    }
}

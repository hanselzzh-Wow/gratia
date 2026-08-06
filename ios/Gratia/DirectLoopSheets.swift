import SwiftUI
import PhotosUI
import GratiaCore

// MARK: - 举报

/// App 内含陌生人即时通讯时，App Store 指南 1.2 要求必须提供举报入口。
struct ReportSheet: View {
    let responseId: String
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI
    @Environment(\.dismiss) private var dismiss

    private let reasons = ["骚扰或辱骂", "涉黄或暴力", "诈骗或索要钱财", "冒充他人", "其他"]
    @State private var reason = "骚扰或辱骂"
    @State private var detail = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if submitted {
                    Section {
                        Text("已收到你的举报，我们会尽快处理。若情况紧急，也可以直接屏蔽对方。")
                            .font(DesignSystem.bodyFont)
                    }
                } else {
                    Section("举报原因") {
                        Picker("原因", selection: $reason) {
                            ForEach(reasons, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    Section("补充说明（选填）") {
                        TextField("发生了什么", text: $detail, axis: .vertical).lineLimit(3...6)
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(DesignSystem.danger) }
                    }
                }
            }
            .navigationTitle("举报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !submitted {
                        Button("提交") { Task { await submit() } }.disabled(isSubmitting)
                    }
                }
            }
        }
    }

    private func submit() async {
        guard let token = accountViewModel.accessToken else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await accountAPI.reportAbuse(responseId: responseId, reason: reason, detail: detail, token: token)
            submitted = true
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "提交失败，请重试。"
        }
    }
}

// MARK: - 选择帮助者

/// 发布者从响应者中选定一位。列表**不含对方联系方式**——
/// 站内既然能沟通和交付，就没有理由把微信或手机号交出去。
struct SelectResponderSheet: View {
    let wishId: String
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI
    @Environment(\.dismiss) private var dismiss

    @State private var responses: [OwnerResponseDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SwiftUI.ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if responses.isEmpty {
                    Text("还没有人响应这个心愿。")
                        .font(DesignSystem.bodyFont)
                        .foregroundStyle(DesignSystem.Rose.ink2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(responses) { response in
                        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                            HStack {
                                Text(response.responderName)
                                    .font(DesignSystem.bodyFont.weight(.semibold))
                                Spacer()
                                if response.status == "selected" {
                                    Text("已选定")
                                        .font(DesignSystem.captionFont)
                                        .foregroundStyle(DesignSystem.Rose.primary)
                                }
                            }
                            if let note = response.note, !note.isEmpty {
                                Text(note).font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.Rose.ink2)
                            }
                            if response.status == "pending" {
                                Button("就 TA 了") { Task { await select(response.id) } }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                        .padding(.vertical, DesignSystem.spacing4)
                    }
                }
            }
            .navigationTitle("选择帮助者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("关闭") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard let token = accountViewModel.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        responses = (try? await accountAPI.wishResponses(wishId: wishId, token: token)) ?? []
    }

    private func select(_ responseId: String) async {
        guard let token = accountViewModel.accessToken else { return }
        do {
            try await accountAPI.selectResponder(wishId: wishId, responseId: responseId, token: token)
            dismiss()
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "选择失败，请重试。"
        }
    }
}

// MARK: - 完成帮助并提交交付

/// 帮助者提交一段文字与最多 9 个图片/视频。文件直接从本机上传到服务端，
/// 运营不经手。
struct DeliverySubmitSheet: View {
    let wishId: String
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI
    @Environment(\.dismiss) private var dismiss

    private let maxItems = 9

    @State private var note = ""
    @State private var picked: [PhotosPickerItem] = []
    @State private var previews: [Image] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        Text("想对 TA 说的话").font(DesignSystem.headlineFont)
                        TextField("比如当时的天气、现场的样子…", text: $note, axis: .vertical)
                            .lineLimit(3...8)
                            .padding(DesignSystem.spacing12)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(DesignSystem.Rose.tint)
                            )
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        HStack {
                            Text("照片或视频").font(DesignSystem.headlineFont)
                            Spacer()
                            Text("\(picked.count)/\(maxItems)")
                                .font(DesignSystem.captionFont)
                                .foregroundStyle(DesignSystem.Rose.ink3)
                        }
                        PhotosPicker(
                            selection: $picked,
                            maxSelectionCount: maxItems,
                            matching: .any(of: [.images, .videos])
                        ) {
                            HStack(spacing: DesignSystem.spacing8) {
                                Image(systemName: "photo.badge.plus")
                                Text(picked.isEmpty ? "选择照片或视频" : "重新选择")
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        if !previews.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.spacing8) {
                                    ForEach(Array(previews.enumerated()), id: \.offset) { _, image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall))
                                    }
                                }
                            }
                        }
                    }

                    Text("提交后这些内容会交付给发布者。发布者可以选择将其公开到首页——你在响应这个心愿时已经同意了这一点。")
                        .font(DesignSystem.captionFont)
                        .foregroundStyle(DesignSystem.Rose.ink3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(DesignSystem.danger)
                            .motionTransition(.opacity)
                    }
                }
                .padding(DesignSystem.spacing20)
            }
            .motion(DesignSystem.Motion.content, value: errorMessage)
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .navigationTitle("完成帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("提交") { Task { await submit() } }
                        .disabled(picked.isEmpty || isSubmitting)
                }
            }
            .onChange(of: picked) { _, _ in Task { await loadPreviews() } }
        }
    }

    private func loadPreviews() async {
        var images: [Image] = []
        for item in picked.prefix(maxItems) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                images.append(Image(uiImage: uiImage))
            }
        }
        previews = images
    }

    private func submit() async {
        guard let token = accountViewModel.accessToken else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            var files: [(Data, String, String)] = []
            for (index, item) in picked.prefix(maxItems).enumerated() {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                // 依据实际内容判断类型，不信任文件名后缀
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                files.append((data, isVideo ? "delivery\(index).mp4" : "delivery\(index).jpg",
                              isVideo ? "video/mp4" : "image/jpeg"))
            }
            guard !files.isEmpty else {
                errorMessage = "没有读取到可上传的文件，请重新选择。"
                return
            }
            try await accountAPI.uploadDelivery(wishId: wishId, note: note, files: files, token: token)
            dismiss()
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "提交失败，请重试。"
        }
    }
}

// MARK: - 公开到首页

/// 完成之后由发布者单独决定是否公开。这是首页故事流唯一的内容来源。
/// 帮助者在响应时已同意其提交的内容由发布者支配（含公开分享）。
struct PublishStorySheet: View {
    let wish: AccountWishDTO
    var onPublished: () -> Void

    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Environment(\.accountAPIClient) private var accountAPI
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    Text("公开之后，这个心愿的正文、城市与交付内容会出现在首页故事流。")
                        .font(DesignSystem.bodyFont)
                        .foregroundStyle(DesignSystem.Rose.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        Text("公开时显示的昵称").font(DesignSystem.headlineFont)
                        TextField("留空则显示「匿名」", text: $nickname)
                            .padding(DesignSystem.spacing12)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(DesignSystem.Rose.tint)
                            )
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        Label("不会公开你的联系方式，也不会公开精确位置。", systemImage: "lock")
                        Label("随时可以撤回公开。", systemImage: "arrow.uturn.backward")
                    }
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.Rose.ink2)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DesignSystem.metadataFont)
                            .foregroundStyle(DesignSystem.danger)
                            .motionTransition(.opacity)
                    }
                }
                .padding(DesignSystem.spacing20)
            }
            .motion(DesignSystem.Motion.content, value: errorMessage)
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .navigationTitle("公开到首页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("公开") { Task { await publish() } }.disabled(isSubmitting)
                }
            }
        }
    }

    private func publish() async {
        guard let token = accountViewModel.accessToken else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await accountAPI.publishStory(
                wishId: wish.id,
                nickname: nickname.trimmingCharacters(in: .whitespaces),
                token: token
            )
            onPublished()
            dismiss()
        } catch {
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "公开失败，请重试。"
        }
    }
}

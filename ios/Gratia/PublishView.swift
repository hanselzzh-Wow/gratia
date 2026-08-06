import SwiftUI
import GratiaCore

struct PublishView: View {
    private enum PublishField: Hashable { case landmark, words, name }

    @ObservedObject var viewModel: PublishWishViewModel
    @EnvironmentObject private var accountViewModel: AccountViewModel
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    /// 步骤推进的方向，决定新旧页面从哪一侧进出。前进为从右侧进入。
    @State private var stepForward = true
    @FocusState private var focusedField: PublishField?

    private let scenes = ["生日祝福", "加油鼓励", "毕业祝福", "浪漫表白", "节日问候", "其他小心愿"]
    private let cities = ["杭州", "上海", "北京", "深圳", "广州"]

    private var isStep1Valid: Bool { !viewModel.landmark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isStep2Valid: Bool { !viewModel.words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.words.count <= 120 }
    private var isStep3Valid: Bool {
        !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.agreeContact
    }
    private var isSubmitting: Bool { viewModel.state == .submitting }
    private var isSuccess: Bool { if case .success = viewModel.state { return true }; return false }
    private var canAdvance: Bool {
        switch currentStep {
        case 1: isStep1Valid
        case 2: isStep2Valid
        default: isStep3Valid
        }
    }

    var body: some View {
        // 以 Sheet 呈现，不用 NavigationStack/系统导航栏：
        // 除底部 Dock 外不出现液态玻璃元素，标题与取消都是普通内容。
        VStack(spacing: 0) {
            sheetHeader
            if case .success(let publicCode) = viewModel.state {
                successView(publicCode: publicCode)
                    .motionTransition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                progressIndicator
                if viewModel.state == .requiresSignIn {
                    SignInPromptView(
                        viewModel: accountViewModel,
                        reason: "登录后才能发布心愿。你填写的内容已经保留，登录后再点一次「确认发布」即可。"
                    )
                    .padding(.horizontal, DesignSystem.spacing20)
                    .padding(.top, DesignSystem.spacing12)
                }
                if case .failed(let message) = viewModel.state { failureBanner(message) }
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                        Group {
                            switch currentStep {
                            case 1: step1View
                            case 2: step2View
                            default: step3View
                            }
                        }
                        .id(currentStep)
                        .motionTransition(
                            .asymmetric(
                                insertion: .move(edge: stepForward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: stepForward ? .leading : .trailing).combined(with: .opacity)
                            )
                        )
                    }
                    .padding(DesignSystem.spacing20)
                }
                navigationControls
            }
        }
        .warmBackground()
        // 成功是全 App 唯一允许"弹"的时刻，配一次成功触感。
        .motion(DesignSystem.Motion.celebrate, value: isSuccess)
        .sensoryFeedback(.success, trigger: isSuccess) { _, success in success }
        .sensoryFeedback(.error, trigger: viewModel.state) { _, state in
            if case .failed = state { return true }
            return false
        }
    }

    private var sheetHeader: some View {
        ZStack {
            Text(isSuccess ? "发布成功" : "发布心愿")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink900)
            if !isSuccess {
                HStack {
                    Spacer()
                    Button("取消") {
                        viewModel.resetForm()
                        currentStep = 1
                        dismiss()
                    }
                    .font(DesignSystem.bodyFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink700)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, DesignSystem.spacing20)
        .padding(.top, DesignSystem.spacing8)
    }

    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            HStack {
                Text("第 \(currentStep) 步，共 3 步")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
                Spacer()
                Text(["地点", "内容", "确认"][currentStep - 1])
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
            }
            HStack(spacing: DesignSystem.spacing4) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? DesignSystem.accent : DesignSystem.hairline)
                        .motion(DesignSystem.Motion.navigation, value: currentStep)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, DesignSystem.spacing20)
        .padding(.top, DesignSystem.spacing12)
    }

    private func failureBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(DesignSystem.danger)
                .accessibilityHidden(true)
            Text(message)
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.danger)
            Spacer()
            Button("重试") { submitWish() }
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(DesignSystem.accent)
        }
        .padding(DesignSystem.spacing12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                .fill(DesignSystem.canvas)
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).stroke(DesignSystem.danger, lineWidth: 1))
        )
        .padding(.horizontal, DesignSystem.spacing20)
        .padding(.top, DesignSystem.spacing12)
    }

    private var navigationControls: some View {
        HStack(spacing: DesignSystem.spacing16) {
            if currentStep > 1 {
                Button("返回") {
                    stepForward = false
                    withAnimation(DesignSystem.Motion.navigation) { currentStep -= 1 }
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 108)
            }
            Button {
                if currentStep < 3 {
                    stepForward = true
                    withAnimation(DesignSystem.Motion.navigation) { currentStep += 1 }
                } else {
                    submitWish()
                }
            } label: {
                if isSubmitting { SwiftUI.ProgressView().tint(.white) }
                else { Text(currentStep == 3 ? "确认并提交" : "继续") }
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: !canAdvance))
            .disabled(!canAdvance || isSubmitting)
        }
        .padding(DesignSystem.spacing20)
        .overlay(alignment: .top) { Rectangle().fill(DesignSystem.hairline).frame(height: 1) }
        .background(DesignSystem.canvas)
    }

    private var step1View: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
            stepHeader(title: "想送到哪里", subtitle: "选择心愿分类、城市和具体地标。")
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                fieldLabel("心愿场景")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.spacing8) {
                    ForEach(scenes, id: \.self) { item in selectionTile(item, selected: viewModel.scene == item) { viewModel.scene = item } }
                }
            }
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                fieldLabel("目标城市")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.spacing8) {
                        ForEach(cities, id: \.self) { city in cityChip(city) }
                    }
                }
            }
            inputField(label: "具体地标／位置", placeholder: "例如：西湖断桥、和平饭店门口", text: $viewModel.landmark, field: .landmark, error: viewModel.validationErrors["landmark"])
        }
    }

    private var step2View: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
            stepHeader(title: "想让对方收到什么", subtitle: "填写想说的话并选择交付形式。")
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                HStack {
                    fieldLabel("想说的话")
                    Spacer()
                    Text("\(viewModel.words.count)/120")
                        .font(DesignSystem.captionFont)
                        .foregroundStyle(viewModel.words.count > 120 ? DesignSystem.danger : DesignSystem.ink500)
                }
                TextEditor(text: $viewModel.words)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.ink900)
                    .scrollContentBackground(.hidden)
                    .padding(DesignSystem.spacing8)
                    .frame(height: 124)
                    .background(fieldBackground(isFocused: focusedField == .words, hasError: viewModel.validationErrors["message"] != nil))
                    .focused($focusedField, equals: .words)
                validationText(viewModel.validationErrors["message"])
            }
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                fieldLabel("交付形式")
                VStack(spacing: DesignSystem.spacing8) {
                    deliveryTypeRow(type: "口播视频", description: "在指定地点拍摄祝福视频，念出你写下的话。", icon: "video")
                    deliveryTypeRow(type: "景色配音", description: "在指定地点拍摄空镜头并念读心愿内容。", icon: "mic")
                    deliveryTypeRow(type: "手写卡片", description: "在现场手写卡片并与背景同框拍照交付。", icon: "document")
                }
            }
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                fieldLabel("期望完成时间")
                DatePicker("选择日期", selection: $viewModel.date, in: Date()..., displayedComponents: .date)
                    .font(DesignSystem.bodyFont)
                    .padding(DesignSystem.spacing12)
                    .background(fieldBackground(isFocused: false, hasError: false))
            }
        }
    }

    private var step3View: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
            stepHeader(title: "确认发布", subtitle: "留下一个称呼，其他人会这样称呼你。")
            inputField(label: "您的称呼", placeholder: "如：小白", text: $viewModel.name, field: .name, error: viewModel.validationErrors["requesterName"])
            Toggle(isOn: $viewModel.agreeContact) {
                Text("我同意在审核通过后，向附近的人公开这条心愿的内容（不含我的身份信息）。有人响应后，我们将在应用内直接沟通。")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
                    .lineSpacing(2)
            }
            .toggleStyle(CheckboxToggleStyle())
            validationText(viewModel.validationErrors["contactConsent"])
            summaryCard
        }
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
            Text(title).font(DesignSystem.titleFont).foregroundStyle(DesignSystem.ink900)
            Text(subtitle).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.ink700)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
    }

    private func selectionTile(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(selected ? DesignSystem.accent : DesignSystem.ink900)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                        .fill(selected ? DesignSystem.canvasSunk : DesignSystem.canvas)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).stroke(selected ? DesignSystem.accent : DesignSystem.hairline, lineWidth: selected ? 2 : 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func cityChip(_ city: String) -> some View {
        Button { viewModel.city = city } label: {
            Text(city)
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(viewModel.city == city ? .white : DesignSystem.ink700)
                .padding(.horizontal, DesignSystem.spacing16)
                .frame(minHeight: 36)
                .background(Capsule().fill(viewModel.city == city ? DesignSystem.accent : DesignSystem.canvas).overlay(Capsule().stroke(viewModel.city == city ? DesignSystem.accent : DesignSystem.hairline, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.city == city ? .isSelected : [])
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>, field: PublishField, error: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            fieldLabel(label)
            TextField(placeholder, text: text)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink900)
                .padding(.horizontal, DesignSystem.spacing12)
                .frame(minHeight: 48)
                .background(fieldBackground(isFocused: focusedField == field, hasError: error != nil))
                .focused($focusedField, equals: field)
                .disabled(isSubmitting)
            validationText(error)
        }
    }

    private func validationText(_ error: String?) -> some View {
        Group {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.danger)
            }
        }
    }

    private func fieldBackground(isFocused: Bool, hasError: Bool) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
            .fill(DesignSystem.canvasSunk)
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).stroke(hasError ? DesignSystem.danger : (isFocused ? DesignSystem.accent : DesignSystem.hairlineStrong), lineWidth: isFocused ? 2 : 1))
    }

    private func deliveryTypeRow(type: String, description: String, icon: String) -> some View {
        let selected = viewModel.deliveryType == type
        return Button {
            viewModel.deliveryType = type
        } label: {
            HStack(spacing: DesignSystem.spacing12) {
                Image(systemName: icon)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(selected ? DesignSystem.accent : DesignSystem.ink500)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    Text(type).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
                    Text(description).font(DesignSystem.captionFont).foregroundStyle(DesignSystem.ink700).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle" : "circle")
                    .font(.body.weight(.regular))
                    .foregroundStyle(selected ? DesignSystem.accent : DesignSystem.ink500)
            }
            .padding(DesignSystem.spacing16)
            .background(RoundedRectangle(cornerRadius: DesignSystem.radiusMedium).fill(DesignSystem.canvas).overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusMedium).stroke(selected ? DesignSystem.accent : DesignSystem.hairline, lineWidth: selected ? 2 : 1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("心愿发布摘要").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
            Divider()
            Text("目标：\(viewModel.city) · \(viewModel.landmark)（\(viewModel.scene)）")
            Text("形式：\(viewModel.deliveryType)")
            Text("内容：\(viewModel.words)").lineLimit(3)
        }
        .font(DesignSystem.metadataFont)
        .foregroundStyle(DesignSystem.ink700)
        .padding(DesignSystem.spacing16)
        .v3Card()
    }

    private func successView(publicCode: String) -> some View {
        VStack(spacing: DesignSystem.spacing24) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(DesignSystem.success)
                .accessibilityHidden(true)
            VStack(spacing: DesignSystem.spacing8) {
                Text("心愿送出，正在审核中").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.ink900)
                Text("请妥善保管公开编号，可用于查询心愿后续进度。")
                    .font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.ink700).multilineTextAlignment(.center)
            }
            VStack(spacing: DesignSystem.spacing12) {
                Text("公开查询编号").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.ink700)
                Text(publicCode).font(.title2.monospaced().weight(.bold)).foregroundStyle(DesignSystem.ink900)
                Button { UIPasteboard.general.string = publicCode } label: {
                    Label("复制编号", systemImage: "doc.on.doc")
                        .font(DesignSystem.metadataFont.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                }
            }
            .padding(DesignSystem.spacing20)
            .frame(maxWidth: .infinity)
            .v3Card(radius: DesignSystem.radiusLarge)
            .padding(.horizontal, DesignSystem.spacing24)
            roadmap
            Spacer()
            VStack(spacing: DesignSystem.spacing12) {
                Button("去「我的」查看进度") { viewModel.resetForm(); currentStep = 1; dismiss(); selectedTab = 4 }
                    .buttonStyle(PrimaryButtonStyle())
                Button("返回首页") { viewModel.resetForm(); currentStep = 1; dismiss(); selectedTab = 0 }
                    .font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.accent)
            }
            .padding(.horizontal, DesignSystem.spacing24)
            .padding(.bottom, DesignSystem.spacing24)
        }
    }

    private var roadmap: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("状态流转路线").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.ink900)
            HStack(spacing: DesignSystem.spacing8) {
                processBadge("已提交", completed: true)
                Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.ink500)
                processBadge("审核中", completed: true)
                Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.ink500)
                processBadge("匹配中", completed: false)
                Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.ink500)
                processBadge("已接单", completed: false)
            }
        }
        .padding(.horizontal, DesignSystem.spacing24)
    }

    private func processBadge(_ name: String, completed: Bool) -> some View {
        Text(name)
            .font(DesignSystem.captionFont.weight(.semibold))
            .foregroundStyle(completed ? DesignSystem.accent : DesignSystem.ink700)
            .padding(.horizontal, DesignSystem.spacing8)
            .frame(minHeight: 28)
            .background(Capsule().fill(completed ? DesignSystem.canvasSunk : DesignSystem.canvas).overlay(Capsule().stroke(DesignSystem.hairline, lineWidth: 1)))
    }

    private func submitWish() { Task { await viewModel.submitWish() } }
}

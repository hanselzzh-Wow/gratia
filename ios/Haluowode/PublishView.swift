import SwiftUI
import HaluowodeCore

struct PublishView: View {
    private enum PublishField: Hashable { case landmark, words, name, contact }

    @ObservedObject var viewModel: PublishWishViewModel
    /// Presented as a full-screen cover from the dock's centre action;
    /// these closures only control dismissal and tab routing, not the business flow.
    var onClose: () -> Void = {}
    var onViewProgress: () -> Void = {}
    var onGoHome: () -> Void = {}
    @State private var currentStep = 1
    @FocusState private var focusedField: PublishField?

    private let scenes = ["生日祝福", "加油鼓励", "毕业祝福", "浪漫表白", "节日问候", "其他小心愿"]
    private let cities = ["杭州", "上海", "北京", "深圳", "广州"]
    private let rewards = [12, 18, 28]

    private var isStep1Valid: Bool { !viewModel.landmark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isStep2Valid: Bool { !viewModel.words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.words.count <= 120 }
    private var isStep3Valid: Bool {
        !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.agreeContact
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
        NavigationStack {
            VStack(spacing: 0) {
                if case .success(let publicCode) = viewModel.state {
                    successView(publicCode: publicCode)
                } else {
                    progressIndicator
                    if case .failed(let message) = viewModel.state { failureBanner(message) }
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                            switch currentStep {
                            case 1: step1View
                            case 2: step2View
                            default: step3View
                            }
                        }
                        .padding(DesignSystem.spacing20)
                    }
                    navigationControls
                }
            }
            .navigationTitle(isSuccess ? "发布成功" : "发布心愿")
            .navigationBarTitleDisplayMode(.inline)
            .whiteCanvas()
            .toolbar {
                if !isSuccess {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("取消") {
                            viewModel.resetForm()
                            currentStep = 1
                            onClose()
                        }
                        .foregroundStyle(DesignSystem.rose)
                    }
                }
            }
        }
    }

    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            HStack {
                Text("第 (currentStep) 步，共 3 步")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.inkMuted)
                Spacer()
                Text(["地点", "内容", "确认"][currentStep - 1])
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.rose)
            }
            HStack(spacing: DesignSystem.spacing4) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? DesignSystem.rose : DesignSystem.roseHairline)
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
                .foregroundStyle(DesignSystem.rose)
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
                Button("返回") { withAnimation { currentStep -= 1 } }
                    .buttonStyle(RoseSecondaryButtonStyle())
                    .frame(width: 108)
            }
            Button {
                if currentStep < 3 { withAnimation { currentStep += 1 } } else { submitWish() }
            } label: {
                if isSubmitting { SwiftUI.ProgressView().tint(.white) }
                else { Text(currentStep == 3 ? "确认并提交" : "继续") }
            }
            .buttonStyle(RosePrimaryButtonStyle(isDisabled: !canAdvance))
            .disabled(!canAdvance || isSubmitting)
        }
        .padding(DesignSystem.spacing20)
        .overlay(alignment: .top) { Rectangle().fill(DesignSystem.roseHairline).frame(height: 1) }
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
                        .foregroundStyle(viewModel.words.count > 120 ? DesignSystem.danger : DesignSystem.inkMuted)
                }
                TextEditor(text: $viewModel.words)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.inkPrimary)
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
            stepHeader(title: "确认与联系", subtitle: "设置感谢金并留下联系方式。")
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                fieldLabel("感谢金金额")
                HStack(spacing: DesignSystem.spacing8) {
                    ForEach(rewards, id: \.self) { reward in rewardTile(reward) }
                }
            }
            inputField(label: "您的称呼", placeholder: "如：小白", text: $viewModel.name, field: .name, error: viewModel.validationErrors["requesterName"])
            inputField(label: "您的联系方式（仅运营可见）", placeholder: "微信或手机号", text: $viewModel.contact, field: .contact, error: viewModel.validationErrors["contact"])
            Toggle(isOn: $viewModel.agreeContact) {
                Text("我已知晓联系方式仅限运营沟通，并同意审核通过后向附近的人公开心愿内容（不含联系方式）。")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.inkMuted)
                    .lineSpacing(2)
            }
            .toggleStyle(CheckboxToggleStyle())
            validationText(viewModel.validationErrors["contactConsent"])
            summaryCard
        }
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
            Text(title).font(DesignSystem.titleFont).foregroundStyle(DesignSystem.inkPrimary)
            Text(subtitle).font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.inkMuted)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
    }

    private func selectionTile(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(selected ? DesignSystem.rose : DesignSystem.inkPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                        .fill(selected ? DesignSystem.roseCanvas : DesignSystem.canvas)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).stroke(selected ? DesignSystem.rose : DesignSystem.roseHairline, lineWidth: selected ? 2 : 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func cityChip(_ city: String) -> some View {
        Button { viewModel.city = city } label: {
            Text(city)
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(viewModel.city == city ? .white : DesignSystem.inkMuted)
                .padding(.horizontal, DesignSystem.spacing16)
                .frame(minHeight: 36)
                .background(Capsule().fill(viewModel.city == city ? DesignSystem.rose : DesignSystem.canvas).overlay(Capsule().stroke(viewModel.city == city ? DesignSystem.rose : DesignSystem.roseHairline, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.city == city ? .isSelected : [])
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>, field: PublishField, error: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            fieldLabel(label)
            TextField(placeholder, text: text)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.inkPrimary)
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
            .fill(DesignSystem.roseCanvas)
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).stroke(hasError ? DesignSystem.danger : (isFocused ? DesignSystem.rose : DesignSystem.roseSoft), lineWidth: isFocused ? 2 : 1))
    }

    private func deliveryTypeRow(type: String, description: String, icon: String) -> some View {
        let selected = viewModel.deliveryType == type
        return Button {
            viewModel.deliveryType = type
        } label: {
            HStack(spacing: DesignSystem.spacing12) {
                Image(systemName: icon)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(selected ? DesignSystem.rose : DesignSystem.inkMuted)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    Text(type).font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
                    Text(description).font(DesignSystem.captionFont).foregroundStyle(DesignSystem.inkMuted).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle" : "circle")
                    .font(.body.weight(.regular))
                    .foregroundStyle(selected ? DesignSystem.rose : DesignSystem.inkMuted)
            }
            .padding(DesignSystem.spacing16)
            .background(RoundedRectangle(cornerRadius: DesignSystem.radiusMedium).fill(DesignSystem.canvas).overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusMedium).stroke(selected ? DesignSystem.rose : DesignSystem.roseHairline, lineWidth: selected ? 2 : 1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func rewardTile(_ reward: Int) -> some View {
        let selected = viewModel.reward == reward
        return Button { viewModel.reward = reward } label: {
            VStack(spacing: DesignSystem.spacing4) {
                Text("¥\(reward)").font(DesignSystem.titleFont)
                Text(reward == 12 ? "基础答谢" : (reward == 18 ? "推荐金额" : "诚意满满"))
                    .font(DesignSystem.captionFont)
            }
            .foregroundStyle(selected ? .white : DesignSystem.inkPrimary)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).fill(selected ? DesignSystem.rose : DesignSystem.canvas).overlay(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall).stroke(selected ? DesignSystem.rose : DesignSystem.roseHairline, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("心愿发布摘要").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
            Divider()
            Text("目标：\(viewModel.city) · \(viewModel.landmark)（\(viewModel.scene)）")
            Text("形式：\(viewModel.deliveryType)")
            Text("内容：\(viewModel.words)").lineLimit(3)
            Text("金额：¥\(viewModel.reward)").foregroundStyle(DesignSystem.inkPrimary)
        }
        .font(DesignSystem.metadataFont)
        .foregroundStyle(DesignSystem.inkMuted)
        .padding(DesignSystem.spacing16)
        .roseCard(radius: DesignSystem.radiusMedium)
    }

    private func successView(publicCode: String) -> some View {
        VStack(spacing: DesignSystem.spacing24) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(DesignSystem.success)
                .accessibilityHidden(true)
            VStack(spacing: DesignSystem.spacing8) {
                Text("心愿送出，正在审核中").font(DesignSystem.titleFont).foregroundStyle(DesignSystem.inkPrimary)
                Text("请妥善保管公开编号，可用于查询心愿后续进度。")
                    .font(DesignSystem.bodyFont).foregroundStyle(DesignSystem.inkMuted).multilineTextAlignment(.center)
            }
            VStack(spacing: DesignSystem.spacing12) {
                Text("公开查询编号").font(DesignSystem.metadataFont).foregroundStyle(DesignSystem.inkMuted)
                Text(publicCode).font(.title2.monospaced().weight(.bold)).foregroundStyle(DesignSystem.inkPrimary)
                Button { UIPasteboard.general.string = publicCode } label: {
                    Label("复制编号", systemImage: "doc.on.doc")
                        .font(DesignSystem.metadataFont.weight(.semibold))
                        .foregroundStyle(DesignSystem.rose)
                }
            }
            .padding(DesignSystem.spacing20)
            .frame(maxWidth: .infinity)
            .roseCard(radius: DesignSystem.radiusLarge)
            .padding(.horizontal, DesignSystem.spacing24)
            roadmap
            Spacer()
            VStack(spacing: DesignSystem.spacing12) {
                Button("去「我的」查询进度") { viewModel.resetForm(); currentStep = 1; onViewProgress() }
                    .buttonStyle(RosePrimaryButtonStyle())
                Button("返回首页") { viewModel.resetForm(); currentStep = 1; onGoHome() }
                    .font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.rose)
            }
            .padding(.horizontal, DesignSystem.spacing24)
            .padding(.bottom, DesignSystem.spacing24)
        }
    }

    private var roadmap: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            Text("状态流转路线").font(DesignSystem.headlineFont).foregroundStyle(DesignSystem.inkPrimary)
            HStack(spacing: DesignSystem.spacing8) {
                processBadge("已提交", completed: true)
                Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.inkMuted)
                processBadge("审核中", completed: true)
                Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.inkMuted)
                processBadge("匹配中", completed: false)
                Image(systemName: "chevron.right").font(DesignSystem.captionFont).foregroundStyle(DesignSystem.inkMuted)
                processBadge("已接单", completed: false)
            }
        }
        .padding(.horizontal, DesignSystem.spacing24)
    }

    private func processBadge(_ name: String, completed: Bool) -> some View {
        Text(name)
            .font(DesignSystem.captionFont.weight(.semibold))
            .foregroundStyle(completed ? DesignSystem.rose : DesignSystem.inkMuted)
            .padding(.horizontal, DesignSystem.spacing8)
            .frame(minHeight: 28)
            .background(Capsule().fill(completed ? DesignSystem.roseCanvas : DesignSystem.canvas).overlay(Capsule().stroke(DesignSystem.roseHairline, lineWidth: 1)))
    }

    private func submitWish() { Task { await viewModel.submitWish() } }
}

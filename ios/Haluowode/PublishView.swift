import SwiftUI

struct PublishView: View {
    @Binding var selectedTab: Int
    @State private var currentStep = 1

    // Step 1 State
    @State private var scene = "生日祝福"
    @State private var city = "杭州"
    @State private var landmark = ""

    // Step 2 State
    @State private var words = ""
    @State private var deliveryType = "口播视频"
    @State private var date = Date()

    // Step 3 State
    @State private var reward = 18
    @State private var name = ""
    @State private var contact = ""
    @State private var agreeContact = false

    // Success State
    @State private var generatedId = ""
    @State private var isSuccess = false
    @State private var isSubmitting = false

    let scenes = ["生日祝福", "加油鼓励", "毕业祝福", "浪漫表白", "节日问候", "其他小心愿"]
    let cities = ["杭州", "上海", "北京", "深圳", "广州"]
    let rewards = [12, 18, 28]

    var isStep1Valid: Bool {
        !landmark.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isStep2Valid: Bool {
        !words.trimmingCharacters(in: .whitespaces).isEmpty && words.count <= 120
    }

    var isStep3Valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contact.trimmingCharacters(in: .whitespaces).isEmpty &&
        agreeContact
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isSuccess {
                    // Step Progress Indicator
                    HStack(spacing: 4) {
                        ForEach(1...3, id: \.self) { index in
                            Rectangle()
                                .fill(index <= currentStep ? DesignSystem.primaryBlue : Color.gray.opacity(0.2))
                                .frame(height: 4)
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacing20)
                    .padding(.top, DesignSystem.spacing8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                            if currentStep == 1 {
                                step1View
                            } else if currentStep == 2 {
                                step2View
                            } else {
                                step3View
                            }
                        }
                        .padding(DesignSystem.spacing20)
                    }

                    // Fixed Bottom Navigation Buttons
                    VStack {
                        HStack(spacing: DesignSystem.spacing16) {
                            if currentStep > 1 {
                                Button(action: {
                                    withAnimation {
                                        currentStep -= 1
                                    }
                                }) {
                                    Text("返回")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .frame(width: 100)
                            }

                            Button(action: {
                                if currentStep < 3 {
                                    withAnimation {
                                        currentStep += 1
                                    }
                                } else {
                                    submitWish()
                                }
                            }) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(currentStep == 3 ? "确认并提交" : "继续")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(isDisabled: currentStep == 1 ? !isStep1Valid : (currentStep == 2 ? !isStep2Valid : !isStep3Valid)))
                            .disabled(currentStep == 1 ? !isStep1Valid : (currentStep == 2 ? !isStep2Valid : !isStep3Valid) || isSubmitting)
                        }
                        .padding(DesignSystem.spacing20)
                    }
                    .background(Color.white.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -4))

                } else {
                    successView
                }
            }
            .navigationTitle(isSuccess ? "发布成功" : "发布心愿 (步骤 \(currentStep)/3)")
            .navigationBarTitleDisplayMode(.inline)
            .warmBackground()
            .toolbar {
                if !isSuccess {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("取消") {
                            resetForm()
                            selectedTab = 0 // Return to home
                        }
                        .foregroundColor(DesignSystem.primaryBlue)
                    }
                }
            }
        }
    }

    // MARK: - Step 1 View: 想送到哪里
    var step1View: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("想送到哪里")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)
                Text("选择心愿分类、城市和具体地标。")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.textSecondary)
            }
            .padding(.bottom, 8)

            // Scene Picker
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("心愿场景")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.spacing8) {
                    ForEach(scenes, id: \.self) { item in
                        Button(action: {
                            scene = item
                        }) {
                            Text(item)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(scene == item ? DesignSystem.primaryBlue.opacity(0.1) : Color.white)
                                .foregroundColor(scene == item ? DesignSystem.primaryBlue : DesignSystem.textNavy)
                                .cornerRadius(DesignSystem.radiusSmall)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .stroke(scene == item ? DesignSystem.primaryBlue : Color.gray.opacity(0.2), lineWidth: scene == item ? 1.5 : 1)
                                )
                        }
                    }
                }
            }

            // City Picker
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("目标城市")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)

                HStack(spacing: DesignSystem.spacing8) {
                    ForEach(cities, id: \.self) { c in
                        Button(action: {
                            city = c
                        }) {
                            Text(c)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(city == c ? DesignSystem.primaryBlue : Color.white)
                                .foregroundColor(city == c ? .white : DesignSystem.textNavy)
                                .cornerRadius(DesignSystem.radiusSmall)
                                .shadow(color: Color.black.opacity(0.01), radius: 3, x: 0, y: 1)
                        }
                    }
                }
            }

            // Landmark Field
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("具体地标/位置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)
                TextField("例如：西湖断桥、和平饭店门口", text: $landmark)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(DesignSystem.radiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Step 2 View: 想让对方收到什么
    var step2View: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("想让对方收到什么")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)
                Text("填写想说的话并选择交付形式。")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.textSecondary)
            }
            .padding(.bottom, 8)

            // Words Field
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                HStack {
                    Text("想说的话")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.textNavy)
                    Spacer()
                    Text("\(words.count)/120")
                        .font(.system(size: 12))
                        .foregroundColor(words.count > 120 ? .red : DesignSystem.textSecondary)
                }

                TextEditor(text: $words)
                    .frame(height: 120)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(DesignSystem.radiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            // Delivery Type Options
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("交付形式")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)

                VStack(spacing: DesignSystem.spacing8) {
                    deliveryTypeRow(type: "口播视频", desc: "在指定地点拍摄30秒祝福视频，说出你写下的话。", icon: "video.fill")
                    deliveryTypeRow(type: "景色配音", desc: "在指定地点拍摄15-30秒高清空镜头并念读心愿内容。", icon: "mic.fill")
                    deliveryTypeRow(type: "手写卡片", desc: "在现场手写明信片/卡片并与背景同框拍照交付。", icon: "doc.text.image")
                }
            }

            // Expected Date Picker
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("期望完成时间")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)

                DatePicker("选择日期", selection: $date, in: Date()..., displayedComponents: .date)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(DesignSystem.radiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }

    func deliveryTypeRow(type: String, desc: String, icon: String) -> some View {
        Button(action: {
            deliveryType = type
        }) {
            HStack(spacing: DesignSystem.spacing12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(deliveryType == type ? DesignSystem.primaryBlue : DesignSystem.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.textNavy)
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if deliveryType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.primaryBlue)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(DesignSystem.radiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                    .stroke(deliveryType == type ? DesignSystem.primaryBlue : Color.gray.opacity(0.2), lineWidth: deliveryType == type ? 1.5 : 1)
            )
        }
    }

    // MARK: - Step 3 View: 确认与联系
    var step3View: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("确认与联系")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)
                Text("设置感谢金并留下联系方式。")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.textSecondary)
            }
            .padding(.bottom, 8)

            // Reward Cards
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("感谢金金额")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)

                HStack(spacing: DesignSystem.spacing12) {
                    ForEach(rewards, id: \.self) { r in
                        Button(action: {
                            reward = r
                        }) {
                            VStack(spacing: 4) {
                                Text("¥\(r)")
                                    .font(.system(size: 20, weight: .bold))
                                Text(r == 12 ? "基础答谢" : (r == 18 ? "推荐金额" : "诚意满满"))
                                    .font(.system(size: 10))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(reward == r ? DesignSystem.primaryBlue : Color.white)
                            .foregroundColor(reward == r ? .white : DesignSystem.textNavy)
                            .cornerRadius(DesignSystem.radiusSmall)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .stroke(reward == r ? DesignSystem.primaryBlue : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            // Name Field
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("您的称呼")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)
                TextField("如：小白", text: $name)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(DesignSystem.radiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            // Contact Field
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("您的联系方式 (仅运营可见)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)
                TextField("微信或手机号", text: $contact)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(DesignSystem.radiusSmall)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            // Consent checkbox
            Toggle(isOn: $agreeContact) {
                Text("我已知晓联系方式仅限运营沟通，并同意心愿通过审核后向附近的人公开（公开版块隐藏联系方式）。")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.textSecondary)
                    .lineSpacing(2)
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.top, 4)

            // Summary Card
            VStack(alignment: .leading, spacing: 8) {
                Text("心愿发布摘要")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.textNavy)
                Divider()
                Text("• 目标：\(city) · \(landmark) (\(scene))")
                Text("• 形式：\(deliveryType)")
                Text("• 内容：\"\(words)\"")
                Text("• 金额：¥\(reward)")
            }
            .font(.system(size: 12))
            .foregroundColor(DesignSystem.textSecondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.primaryBlue.opacity(0.05))
            .cornerRadius(DesignSystem.radiusSmall)
            .padding(.top, 8)
        }
    }

    // MARK: - Success View
    var successView: some View {
        VStack(spacing: DesignSystem.spacing24) {
            Spacer()

            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(DesignSystem.primaryBlue)

            VStack(spacing: DesignSystem.spacing8) {
                Text("心愿送出，正在审核中")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)

                Text("请妥善保管您的公开编号，可用于查询心愿的后续进度。")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Code Card
            VStack(spacing: DesignSystem.spacing8) {
                Text("公开查询编号")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.textSecondary)

                Text(generatedId)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.textNavy)

                HStack(spacing: DesignSystem.spacing16) {
                    Button(action: {
                        UIPasteboard.general.string = generatedId
                    }) {
                        Label("复制编号", systemImage: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.primaryBlue)
                    }

                    Button(action: {
                        // Action to save to photos
                    }) {
                        Label("保存到照片", systemImage: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.primaryBlue)
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(DesignSystem.bgWarmWhite)
            .cornerRadius(DesignSystem.radiusMedium)
            .padding(.horizontal, DesignSystem.spacing24)

            // Process Roadmap
            VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                Text("状态流转路线")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)

                HStack(spacing: 8) {
                    processBadge(name: "已提交", isCompleted: true)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    processBadge(name: "审核中", isCompleted: true)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    processBadge(name: "匹配中", isCompleted: false)
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    processBadge(name: "已接单", isCompleted: false)
                }
            }
            .padding(.horizontal, DesignSystem.spacing24)

            Spacer()

            VStack(spacing: DesignSystem.spacing12) {
                Button(action: {
                    // Navigate to Progress tab
                    selectedTab = 3
                    resetForm()
                }) {
                    Text("查看心愿进度")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: {
                    // Return to Home
                    selectedTab = 0
                    resetForm()
                }) {
                    Text("返回首页")
                }
                .foregroundColor(DesignSystem.primaryBlue)
                .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, DesignSystem.spacing24)
            .padding(.bottom, 30)
        }
    }

    func processBadge(name: String, isCompleted: Bool) -> some View {
        Text(name)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isCompleted ? DesignSystem.primaryBlue.opacity(0.1) : Color.gray.opacity(0.1))
            .foregroundColor(isCompleted ? DesignSystem.primaryBlue : DesignSystem.textSecondary)
            .cornerRadius(4)
    }

    // MARK: - Actions
    func submitWish() {
        isSubmitting = true

        // Simulate API Request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyMMdd"
            let dateStr = formatter.string(from: Date())
            let randomCode = String((0..<5).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            self.generatedId = "HW\(dateStr)-\(randomCode)"

            // Add to mock lists
            let newWish = Wish(
                id: self.generatedId,
                city: self.city,
                landmark: self.landmark,
                content: self.words,
                deliveryType: self.deliveryType,
                date: formatter.string(from: self.date),
                reward: self.reward,
                status: "审核中",
                creatorName: self.name
            )
            Wish.mockWishes.insert(newWish, at: 0)

            self.isSubmitting = false
            self.isSuccess = true
        }
    }

    func resetForm() {
        currentStep = 1
        scene = "生日祝福"
        city = "杭州"
        landmark = ""
        words = ""
        deliveryType = "口播视频"
        date = Date()
        reward = 18
        name = ""
        contact = ""
        agreeContact = false
        isSuccess = false
        generatedId = ""
    }
}

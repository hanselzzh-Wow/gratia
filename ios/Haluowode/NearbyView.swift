import SwiftUI

struct NearbyView: View {
    @State private var searchKeywords = ""
    @State private var selectedDeliveryFilter = "全部"
    @State private var showFilterSheet = false
    @State private var selectedCity = "全部"
    @State private var wishes = Wish.mockWishes

    let deliveryTypes = ["全部", "口播视频", "景色配音", "手写卡片"]

    var filteredWishes: [Wish] {
        wishes.filter { wish in
            let matchSearch = searchKeywords.isEmpty ||
                              wish.landmark.localizedCaseInsensitiveContains(searchKeywords) ||
                              wish.content.localizedCaseInsensitiveContains(searchKeywords)
            let matchDelivery = selectedDeliveryFilter == "全部" || wish.deliveryType == selectedDeliveryFilter
            let matchCity = selectedCity == "全部" || wish.city == selectedCity
            return matchSearch && matchDelivery && matchCity
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Search Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DesignSystem.textSecondary)
                        TextField("搜索地标、心愿内容...", text: $searchKeywords)
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.textNavy)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(DesignSystem.radiusSmall)
                    .shadow(color: Color.black.opacity(0.01), radius: 3, x: 0, y: 1)

                    Button(action: {
                        showFilterSheet = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.primaryBlue)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(DesignSystem.radiusSmall)
                            .shadow(color: Color.black.opacity(0.01), radius: 3, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, DesignSystem.spacing20)
                .padding(.vertical, DesignSystem.spacing12)

                // 2. Horizontal Filter Capsules
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.spacing8) {
                        ForEach(deliveryTypes, id: \.self) { type in
                            Button(action: {
                                selectedDeliveryFilter = type
                            }) {
                                Text(type)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(selectedDeliveryFilter == type ? DesignSystem.primaryBlue : Color.white)
                                    .foregroundColor(selectedDeliveryFilter == type ? .white : DesignSystem.textNavy)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.01), radius: 3, x: 0, y: 1)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacing20)
                }
                .padding(.bottom, DesignSystem.spacing12)

                // 3. Result Count & List
                HStack {
                    Text("共找到 \(filteredWishes.count) 个心愿")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.spacing20)
                .padding(.vertical, DesignSystem.spacing8)

                if filteredWishes.isEmpty {
                    Spacer()
                    VStack(spacing: DesignSystem.spacing12) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.textSecondary.opacity(0.5))
                        Text("没有找到符合条件的心愿")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DesignSystem.textNavy)
                    }
                    Spacer()
                } else {
                    List(filteredWishes) { wish in
                        ZStack {
                            NavigationLink(destination: WishDetailView(wish: wish)) {
                                EmptyView()
                            }
                            .opacity(0)

                            WishRowView(wish: wish)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.horizontal, DesignSystem.spacing20)
                        .padding(.vertical, 6)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("附近的心愿")
            .warmBackground()
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(selectedCity: $selectedCity, isPresented: $showFilterSheet)
            }
        }
    }
}

// Wish Card Row
struct WishRowView: View {
    let wish: Wish

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            HStack {
                Text("\(wish.city) · \(wish.landmark)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)
                Spacer()
                Text("¥\(wish.reward)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.highlightGold)
            }

            Text(wish.content)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.textSecondary)
                .lineLimit(3)
                .lineSpacing(3)

            HStack {
                Text(wish.deliveryType)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.primaryBlue.opacity(0.1))
                    .foregroundColor(DesignSystem.primaryBlue)
                    .cornerRadius(4)

                Spacer()

                Text("期望时间: \(wish.date)")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(DesignSystem.spacing16)
        .background(DesignSystem.cardBg)
        .cornerRadius(DesignSystem.radiusMedium)
        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}

// Filter Sheet View
struct FilterSheetView: View {
    @Binding var selectedCity: String
    @Binding var isPresented: Bool

    let cities = ["全部", "杭州", "上海", "北京", "深圳", "广州"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                Text("选择城市")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.spacing8) {
                        ForEach(cities, id: \.self) { city in
                            Button(action: {
                                selectedCity = city
                            }) {
                                Text(city)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCity == city ? DesignSystem.primaryBlue : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedCity == city ? .white : DesignSystem.textNavy)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                Spacer()

                Button("确定") {
                    isPresented = false
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(DesignSystem.spacing20)
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        selectedCity = "全部"
                    }
                    .foregroundColor(DesignSystem.primaryBlue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        isPresented = false
                    }
                    .foregroundColor(DesignSystem.primaryBlue)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// Wish Detail View
struct WishDetailView: View {
    let wish: Wish
    @State private var showApplySheet = false
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                        HStack {
                            Text(wish.deliveryType)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DesignSystem.primaryBlue.opacity(0.1))
                                .foregroundColor(DesignSystem.primaryBlue)
                                .cornerRadius(4)

                            Spacer()

                            Text("待匹配")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignSystem.primaryBlue)
                        }

                        Text("\(wish.city) · \(wish.landmark)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(DesignSystem.textNavy)

                        HStack {
                            Text("感谢金：")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.textSecondary)
                            Text("¥\(wish.reward)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(DesignSystem.highlightGold)
                        }
                    }
                    .padding(DesignSystem.spacing20)
                    .background(DesignSystem.cardBg)
                    .cornerRadius(DesignSystem.radiusLarge)
                    .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                    // Wish Content Card
                    VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                        Text("心愿内容")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(DesignSystem.textNavy)

                        Text(wish.content)
                            .font(.system(size: 15))
                            .foregroundColor(DesignSystem.textNavy.opacity(0.9))
                            .lineSpacing(5)

                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("期望完成时间")
                                .font(.system(size: 13))
                                .foregroundColor(DesignSystem.textSecondary)
                            Spacer()
                            Text(wish.date)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignSystem.textNavy)
                        }
                    }
                    .padding(DesignSystem.spacing20)
                    .background(DesignSystem.cardBg)
                    .cornerRadius(DesignSystem.radiusLarge)
                    .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                    // Process Guide
                    VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                        Text("接单履约说明")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(DesignSystem.textNavy)

                        Text("1. 提交响应后，平台运营人员会在12小时内与您联系。\n2. 人工匹配确认后，您需要在规定时间内前往现场履约。\n3. 上传拍摄的照片/视频，确认合格后即可获得相应感谢金。")
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(DesignSystem.spacing20)
                    .background(DesignSystem.cardBg)
                    .cornerRadius(DesignSystem.radiusLarge)
                    .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)

                    // Security Warning
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(DesignSystem.primaryBlue)
                        Text("响应者与发布者的私人联系方式均不对外公开，完全由平台居中保障双方利益。")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 8)
                }
                .padding(DesignSystem.spacing20)
            }

            // Bottom Action
            VStack {
                Button(action: {
                    showApplySheet = true
                }) {
                    Text("我刚好在这里，可以帮忙")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(DesignSystem.spacing20)
            }
            .background(Color.white.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -4))
        }
        .navigationTitle("心愿详情")
        .navigationBarTitleDisplayMode(.inline)
        .warmBackground()
        .sheet(isPresented: $showApplySheet) {
            ApplyResponseSheet(wish: wish, isPresented: $showApplySheet, showSuccess: $showSuccess)
        }
        .navigationDestination(isPresented: $showSuccess) {
            ApplySuccessView(wish: wish)
        }
    }
}

// Apply Response Sheet
struct ApplyResponseSheet: View {
    let wish: Wish
    @Binding var isPresented: Bool
    @Binding var showSuccess: Bool

    @State private var name = ""
    @State private var contact = ""
    @State private var note = ""
    @State private var agreeContact = false

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contact.trimmingCharacters(in: .whitespaces).isEmpty &&
        agreeContact
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.spacing20) {
                    // Summary info
                    HStack {
                        Text("\(wish.city) · \(wish.landmark)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DesignSystem.textNavy)
                        Spacer()
                        Text("感谢金: ¥\(wish.reward)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DesignSystem.highlightGold)
                    }
                    .padding(DesignSystem.spacing16)
                    .background(DesignSystem.primaryBlue.opacity(0.05))
                    .cornerRadius(DesignSystem.radiusSmall)

                    // Name Field
                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        Text("您的称呼")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textNavy)
                        TextField("如：小张", text: $name)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(DesignSystem.radiusSmall)
                    }

                    // Contact Field
                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        Text("联系方式 (仅运营可见)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textNavy)
                        TextField("微信号或手机号", text: $contact)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(DesignSystem.radiusSmall)
                    }

                    // Note Field
                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        Text("补充说明 (选填)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textNavy)
                        TextEditor(text: $note)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(DesignSystem.radiusSmall)
                    }

                    // Consent checkbox
                    Toggle(isOn: $agreeContact) {
                        Text("同意平台运营人员与我联系确认匹配事宜。")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.textSecondary)
                    }
                    .toggleStyle(CheckboxToggleStyle())

                    Spacer()

                    Button(action: {
                        isPresented = false
                        // Trigger Success Navigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showSuccess = true
                        }
                    }) {
                        Text("提交响应")
                    }
                    .buttonStyle(PrimaryButtonStyle(isDisabled: !isFormValid))
                    .disabled(!isFormValid)
                }
                .padding(DesignSystem.spacing20)
            }
            .navigationTitle("我要帮忙")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(DesignSystem.primaryBlue)
                }
            }
        }
    }
}

// Apply Success View
struct ApplySuccessView: View {
    let wish: Wish
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignSystem.spacing24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(DesignSystem.primaryBlue)

            VStack(spacing: DesignSystem.spacing8) {
                Text("响应已提交")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)

                Text("运营人员确认后会联系您，这还不代表已经接单。")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.spacing20)
            }

            // Wish details
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("\(wish.city) · \(wish.landmark)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignSystem.textNavy)
                Text(wish.content)
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.textSecondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.bgWarmWhite)
            .cornerRadius(DesignSystem.radiusMedium)
            .padding(.horizontal, DesignSystem.spacing24)

            Spacer()

            Button(action: {
                // Navigate back to the root of Nearby
                dismiss()
            }) {
                Text("我知道了")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, DesignSystem.spacing24)
            .padding(.bottom, 30)
        }
        .navigationBarBackButtonHidden(true)
        .warmBackground()
    }
}

// Custom Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? DesignSystem.primaryBlue : DesignSystem.textSecondary)
                .font(.system(size: 20))
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}

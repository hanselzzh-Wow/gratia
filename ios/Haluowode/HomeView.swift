import SwiftUI
import HaluowodeCore

struct HomeView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var viewModel: WishListViewModel
    @State private var showCityPicker = false

    let cities = ["全国", "杭州", "上海", "北京", "深圳", "广州"]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: DesignSystem.spacing20) {

                    // 1. Hero Card (品牌主视觉)
                    VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                        HStack {
                            Text("让想说的话，抵达远方")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(DesignSystem.textNavy)
                            Spacer()
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(DesignSystem.primaryBlue)
                        }

                        Text("委托远方当地的在场者，为你录制现场祝福、景色配音或制作手写卡片，搭起心意相通的桥梁。")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.textSecondary)
                            .lineSpacing(4)

                        Button(action: {
                            selectedTab = 2 // Switch to Publish Tab
                        }) {
                            Text("发布一个心愿")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(DesignSystem.primaryBlue)
                                .foregroundColor(.white)
                                .font(.system(size: 15, weight: .semibold))
                                .cornerRadius(DesignSystem.radiusSmall)
                        }
                        .padding(.top, 4)
                    }
                    .padding(DesignSystem.spacing20)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, DesignSystem.primaryBlue.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, DesignSystem.spacing20)

                    // 2. 双入口 (我要发布 / 我能帮忙)
                    HStack(spacing: DesignSystem.spacing16) {
                        Button(action: {
                            selectedTab = 2
                        }) {
                            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                                Image(systemName: "plus.bubble.fill")
                                    .font(.title2)
                                    .foregroundColor(DesignSystem.primaryBlue)
                                Text("我要发布")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                Text("把心意送到远方")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignSystem.spacing16)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusMedium)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                        }

                        Button(action: {
                            selectedTab = 1 // Switch to Nearby Tab
                        }) {
                            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.title2)
                                    .foregroundColor(DesignSystem.highlightGold)
                                Text("我能帮忙")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(DesignSystem.textNavy)
                                Text("我刚好在这里")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignSystem.spacing16)
                            .background(DesignSystem.cardBg)
                            .cornerRadius(DesignSystem.radiusMedium)
                            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacing20)

                    // 3. 附近正在等待的心愿
                    VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
                        HStack {
                            Text("正在等待的心愿")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(DesignSystem.textNavy)
                            Spacer()
                            Button(action: {
                                selectedTab = 1
                            }) {
                                HStack(spacing: 2) {
                                    Text("查看全部")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.primaryBlue)
                            }
                        }
                        .padding(.horizontal, DesignSystem.spacing20)

                        switch viewModel.state {
                        case .idle, .loading:
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.spacing12) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        SkeletonCardView()
                                    }
                                }
                                .padding(.horizontal, DesignSystem.spacing20)
                            }
                        case .failed(let error):
                            VStack(spacing: 8) {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                Button(action: {
                                    Task {
                                        await viewModel.fetchWishes()
                                    }
                                }) {
                                    Text("重试")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(DesignSystem.primaryBlue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(DesignSystem.primaryBlue, lineWidth: 1)
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                        case .empty:
                            HStack {
                                Spacer()
                                Text("附近暂时没有心愿发布")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignSystem.textSecondary)
                                Spacer()
                            }
                            .frame(height: 100)
                        case .loaded(let wishes):
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.spacing12) {
                                    ForEach(wishes.prefix(3)) { wish in
                                        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                                            HStack {
                                                Text("\(wish.city) · \(wish.landmark)")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(DesignSystem.textNavy)
                                                Spacer()
                                                Text("¥\(Int(wish.rewardYuan))")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(DesignSystem.highlightGold)
                                            }

                                            Text(wish.message)
                                                .font(.system(size: 13))
                                                .foregroundColor(DesignSystem.textSecondary)
                                                .lineLimit(2)
                                                .frame(height: 36, alignment: .top)
                                                .lineSpacing(2)

                                            HStack {
                                                Text(wish.deliveryType.label)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(DesignSystem.primaryBlue.opacity(0.1))
                                                    .foregroundColor(DesignSystem.primaryBlue)
                                                    .cornerRadius(4)
                                                Spacer()
                                                Text("期望时间: \(wish.deadlineText)")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(DesignSystem.textSecondary)
                                            }
                                            .padding(.top, 4)
                                        }
                                        .padding(DesignSystem.spacing16)
                                        .frame(width: 280)
                                        .background(DesignSystem.cardBg)
                                        .cornerRadius(DesignSystem.radiusMedium)
                                        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.spacing20)
                            }
                        }
                    }

                    // 4. 如何完成说明 (三步说明)
                    VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
                        Text("如何完成心愿")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignSystem.textNavy)
                            .padding(.horizontal, DesignSystem.spacing20)

                        VStack(spacing: DesignSystem.spacing16) {
                            HStack(alignment: .top, spacing: DesignSystem.spacing16) {
                                Image(systemName: "1.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(DesignSystem.primaryBlue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("发布您的愿望")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.textNavy)
                                    Text("填写您想去的城市、地标和希望录制的言语。")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignSystem.textSecondary)
                                }
                            }

                            HStack(alignment: .top, spacing: DesignSystem.spacing16) {
                                Image(systemName: "2.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(DesignSystem.primaryBlue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("运营人工核对匹配")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.textNavy)
                                    Text("平台进行安全性与隐私审核，并匹配附近最合适的小伙伴。")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignSystem.textSecondary)
                                }
                            }

                            HStack(alignment: .top, spacing: DesignSystem.spacing16) {
                                Image(systemName: "3.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(DesignSystem.primaryBlue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("送达并获得现场反馈")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.textNavy)
                                    Text("响应者现场履约，上传高清照片或口播视频，通过专属能力令牌下载。")
                                        .font(.system(size: 12))
                                        .foregroundColor(DesignSystem.textSecondary)
                                }
                            }
                        }
                        .padding(DesignSystem.spacing20)
                        .background(DesignSystem.cardBg)
                        .cornerRadius(DesignSystem.radiusLarge)
                        .padding(.horizontal, DesignSystem.spacing20)
                    }

                    // 5. 隐私与安全说明条
                    HStack(spacing: DesignSystem.spacing12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(DesignSystem.primaryBlue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("人工审核与隐私保护")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignSystem.textNavy)
                            Text("您的联系方式仅运营可见，心愿交付采用加密链接隔离。")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.spacing12)
                    .background(DesignSystem.primaryBlue.opacity(0.06))
                    .cornerRadius(DesignSystem.radiusMedium)
                    .padding(.horizontal, DesignSystem.spacing20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCityPicker = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                            Text(viewModel.selectedCity)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.primaryBlue)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("哈喽卧得")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignSystem.textNavy)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Action for Notification
                    }) {
                        Image(systemName: "bell")
                            .foregroundColor(DesignSystem.textNavy)
                    }
                }
            }
            .sheet(isPresented: $showCityPicker) {
                NavigationStack {
                    List(cities, id: \.self) { city in
                        Button(action: {
                            viewModel.selectedCity = city
                            showCityPicker = false
                            Task {
                                await viewModel.fetchWishes()
                            }
                        }) {
                            HStack {
                                Text(city)
                                    .foregroundColor(DesignSystem.textNavy)
                                Spacer()
                                if viewModel.selectedCity == city {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.primaryBlue)
                                }
                            }
                        }
                    }
                    .navigationTitle("选择城市")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") {
                                showCityPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .warmBackground()
            .refreshable {
                await viewModel.fetchWishes()
            }
            .task {
                await viewModel.fetchWishes()
            }
        }
    }
}

// Real Skeleton Loader Card Component
struct SkeletonCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 40, height: 16)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 36)
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 60, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 120, height: 14)
            }
        }
        .padding(DesignSystem.spacing16)
        .frame(width: 280)
        .background(DesignSystem.cardBg)
        .cornerRadius(DesignSystem.radiusMedium)
    }
}

import SwiftUI
import HaluowodeCore

struct HomeView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var viewModel: WishListViewModel
    @State private var showCityPicker = false

    private let cities = ["全国", "杭州", "上海", "北京", "深圳", "广州"]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: DesignSystem.spacing32) {
                    hero
                    entryPoints
                    waitingWishes
                    howItWorks
                    privacyNotice
                }
                .padding(.vertical, DesignSystem.spacing20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCityPicker = true
                    } label: {
                        HStack(spacing: DesignSystem.spacing4) {
                            Image(systemName: "mappin.circle")
                            Text(viewModel.selectedCity)
                            Image(systemName: "chevron.down")
                                .font(DesignSystem.captionFont.weight(.semibold))
                        }
                        .font(DesignSystem.metadataFont.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("选择城市，当前\(viewModel.selectedCity)")
                }
                ToolbarItem(placement: .principal) {
                    Text("哈喽卧得")
                        .font(DesignSystem.headlineFont)
                        .foregroundStyle(DesignSystem.ink900)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {} label: {
                        Image(systemName: "bell")
                            .font(.body.weight(.regular))
                            .foregroundStyle(DesignSystem.ink900)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("通知")
                }
            }
            .sheet(isPresented: $showCityPicker) {
                cityPicker
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            HStack(alignment: .top, spacing: DesignSystem.spacing12) {
                Text("让想说的话，\n抵达远方")
                    .font(DesignSystem.titleFont)
                    .foregroundStyle(DesignSystem.ink900)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DesignSystem.spacing8)
                Image(systemName: "paperplane")
                    .font(.title2.weight(.regular))
                    .foregroundStyle(DesignSystem.accent)
                    .accessibilityHidden(true)
            }

            Text("委托远方当地的在场者，为你录制现场祝福、景色配音或制作手写卡片，搭起心意相通的桥梁。")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.ink700)
                .lineSpacing(3)

            Button {
                selectedTab = 2
            } label: {
                Text("发布一个心愿")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.spacing20)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                            .fill(DesignSystem.accent)
                    )
            }
            .accessibilityHint("切换到发布页面")
        }
        .padding(DesignSystem.spacing20)
        .v3Card(radius: DesignSystem.radiusLarge)
        .padding(.horizontal, DesignSystem.spacing20)
    }

    private var entryPoints: some View {
        HStack(spacing: DesignSystem.spacing12) {
            entryPoint(
                title: "我要发布",
                detail: "把心意送到远方",
                symbol: "plus.bubble",
                action: { selectedTab = 2 }
            )
            entryPoint(
                title: "我能帮忙",
                detail: "我刚好在这里",
                symbol: "mappin.and.ellipse",
                action: { selectedTab = 1 }
            )
        }
        .padding(.horizontal, DesignSystem.spacing20)
    }

    private func entryPoint(
        title: String,
        detail: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Image(systemName: symbol)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(DesignSystem.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
                Text(detail)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
            .padding(DesignSystem.spacing16)
            .v3Card()
        }
        .accessibilityHint(title == "我要发布" ? "切换到发布页面" : "切换到附近页面")
    }

    private var waitingWishes: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing12) {
            HStack {
                Text("正在等待的心愿")
                    .font(DesignSystem.titleFont)
                    .foregroundStyle(DesignSystem.ink900)
                Spacer()
                Button {
                    selectedTab = 1
                } label: {
                    Label("查看全部", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(DesignSystem.metadataFont.weight(.semibold))
                        .foregroundStyle(DesignSystem.accent)
                        .frame(minHeight: 44)
                }
                .accessibilityHint("切换到附近页面")
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
                .accessibilityLabel("正在加载心愿")
            case .failed(let error):
                VStack(spacing: DesignSystem.spacing8) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.danger)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await viewModel.fetchWishes() }
                    } label: {
                        Text("重试")
                            .font(DesignSystem.metadataFont.weight(.semibold))
                            .foregroundStyle(DesignSystem.accent)
                            .padding(.horizontal, DesignSystem.spacing16)
                            .frame(minHeight: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .stroke(DesignSystem.accent, lineWidth: 1)
                            )
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 132)
                .padding(.horizontal, DesignSystem.spacing20)
            case .empty:
                VStack(spacing: DesignSystem.spacing8) {
                    Image(systemName: "tray")
                        .font(.title3.weight(.regular))
                        .foregroundStyle(DesignSystem.ink500)
                    Text("附近暂时没有心愿发布")
                        .font(DesignSystem.metadataFont)
                        .foregroundStyle(DesignSystem.ink700)
                }
                .frame(maxWidth: .infinity, minHeight: 116)
                .padding(.horizontal, DesignSystem.spacing20)
            case .loaded(let wishes):
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.spacing12) {
                        ForEach(wishes.prefix(3)) { wish in
                            wishCard(wish)
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacing20)
                }
            }
        }
    }

    private func wishCard(_ wish: PublicWishDTO) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            Text("\(wish.city) · \(wish.landmark)")
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(DesignSystem.ink900)
                .lineLimit(1)
            Text(wish.message)
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.ink700)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Text("¥\(Int(wish.rewardYuan))")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.ink900)
            Text(wish.deliveryType.label)
                .font(DesignSystem.captionFont.weight(.semibold))
                .foregroundStyle(DesignSystem.accent)
                .lineLimit(1)
        }
        .frame(width: 140, height: 170, alignment: .leading)
        .padding(DesignSystem.spacing12)
        .v3Card()
        .accessibilityElement(children: .combine)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            Text("如何完成心愿")
                .font(DesignSystem.titleFont)
                .foregroundStyle(DesignSystem.ink900)

            VStack(spacing: DesignSystem.spacing16) {
                HomeStep(number: 1, title: "发布您的愿望", detail: "填写想去的城市、地标和希望录制的言语。")
                HomeStep(number: 2, title: "运营人工核对匹配", detail: "平台进行安全与隐私审核，并匹配附近合适的小伙伴。")
                HomeStep(number: 3, title: "送达并获得现场反馈", detail: "响应者现场履约，通过专属链接查看交付。")
            }
            .padding(DesignSystem.spacing20)
            .v3Card(radius: DesignSystem.radiusLarge)
        }
        .padding(.horizontal, DesignSystem.spacing20)
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing12) {
            Image(systemName: "lock.shield")
                .font(.title3.weight(.regular))
                .foregroundStyle(DesignSystem.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text("人工审核与隐私保护")
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
                Text("联系方式仅运营可见，交付链接单独保护。")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.spacing16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                .fill(DesignSystem.canvasSunk)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .stroke(DesignSystem.hairline, lineWidth: 1)
                )
        )
        .padding(.horizontal, DesignSystem.spacing20)
        .padding(.bottom, DesignSystem.spacing20)
    }

    private var cityPicker: some View {
        NavigationStack {
            List(cities, id: \.self) { city in
                Button {
                    viewModel.selectedCity = city
                    showCityPicker = false
                    Task { await viewModel.fetchWishes() }
                } label: {
                    HStack {
                        Text(city).foregroundStyle(DesignSystem.ink900)
                        Spacer()
                        if viewModel.selectedCity == city {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DesignSystem.accent)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.canvasWarm)
            .navigationTitle("选择城市")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showCityPicker = false }
                        .foregroundStyle(DesignSystem.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct HomeStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing12) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.accent, lineWidth: 1.5)
                Text("\(number)")
                    .font(DesignSystem.metadataFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                Text(title)
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
                Text(detail)
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.ink700)
            }
        }
    }
}

struct SkeletonCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
            RoundedRectangle(cornerRadius: DesignSystem.radiusTiny)
                .fill(DesignSystem.canvasSunk)
                .frame(width: 82, height: 12)
            RoundedRectangle(cornerRadius: DesignSystem.radiusTiny)
                .fill(DesignSystem.canvasSunk)
                .frame(height: 34)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: DesignSystem.radiusTiny)
                .fill(DesignSystem.canvasSunk)
                .frame(width: 48, height: 12)
        }
        .frame(width: 140, height: 170, alignment: .leading)
        .padding(DesignSystem.spacing12)
        .v3Card()
        .accessibilityHidden(true)
    }
}

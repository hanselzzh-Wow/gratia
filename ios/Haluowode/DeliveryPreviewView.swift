import SwiftUI
import AVKit
import HaluowodeCore

public struct DeliveryPreviewView: View {
    public let deliverable: WishDeliverableDTO
    @Binding public var isPresented: Bool

    public init(deliverable: WishDeliverableDTO, isPresented: Binding<Bool>) {
        self.deliverable = deliverable
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.ink900.ignoresSafeArea()
                mediaContent
                    .padding(.horizontal, DesignSystem.spacing20)
                    .padding(.bottom, deliverable.note == nil ? DesignSystem.spacing20 : 120)

                if let note = sanitizedNote {
                    VStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                            Text("交付留言")
                                .font(DesignSystem.headlineFont)
                                .foregroundStyle(.white)
                            Text(note)
                                .font(DesignSystem.bodyFont)
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(4)
                        }
                        .padding(DesignSystem.spacing16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                .fill(DesignSystem.ink700.opacity(0.9))
                        )
                        .padding(DesignSystem.spacing20)
                    }
                }
            }
            .navigationTitle("交付凭证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(DesignSystem.ink900, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("关闭交付预览")
                }
            }
        }
    }

    @ViewBuilder private var mediaContent: some View {
        switch deliverable.kind {
        case .spokenVideo, .sceneryVoiceover:
            CustomVideoPlayer(url: deliverable.url)
        case .handwrittenCard:
            AsyncImage(url: deliverable.url) { phase in
                switch phase {
                case .empty:
                    loadingView
                case .success(let image):
                    image.resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLarge))
                case .failure:
                    errorView
                @unknown default:
                    errorView
                }
            }
        case .link:
            VStack(spacing: DesignSystem.spacing20) {
                Image(systemName: "link")
                    .font(.largeTitle.weight(.regular))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text("交付内容将在浏览器中打开")
                    .font(DesignSystem.titleFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Link("打开交付内容", destination: deliverable.url)
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.ink900)
                    .padding(.horizontal, DesignSystem.spacing20)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(.white))
            }
        default:
            errorView
        }
    }

    private var sanitizedNote: String? {
        guard let note = deliverable.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
        return note
    }

    private var loadingView: some View {
        VStack(spacing: DesignSystem.spacing12) {
            SwiftUI.ProgressView().tint(.white)
            Text("正在加载交付内容")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(.white.opacity(0.82))
        }
        .accessibilityElement(children: .combine)
    }

    private var errorView: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            Text("交付链接不可用或已失效")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

struct CustomVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var playbackFailed = false
    @State private var statusObservation: NSKeyValueObservation?

    var body: some View {
        Group {
            if playbackFailed {
                failureView
            } else if let player {
                VideoPlayer(player: player)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLarge))
            } else {
                SwiftUI.ProgressView().tint(.white)
            }
        }
        .onAppear(perform: preparePlayer)
        .onDisappear {
            statusObservation?.invalidate()
            statusObservation = nil
            player?.pause()
        }
    }

    private var failureView: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(.white)
            Text("交付链接不可用或已失效")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private func preparePlayer() {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async { playbackFailed = true }
        }
    }
}

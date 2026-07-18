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
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: DesignSystem.spacing20) {
                // Top header bar controls
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text("交付凭证")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    // Dummy space to balance the close button
                    Spacer().frame(width: 44)
                }

                Spacer()

                // Content Area based on deliverable kind
                Group {
                    if deliverable.kind == .spokenVideo || deliverable.kind == .sceneryVoiceover {
                        VideoPlayer(player: AVPlayer(url: deliverable.url))
                            .aspectRatio(9/16, contentMode: .fit)
                            .cornerRadius(12)
                    } else if deliverable.kind == .handwrittenCard {
                        AsyncImage(url: deliverable.url) { phase in
                            switch phase {
                            case .empty:
                                SwiftUI.ProgressView()
                                    .tint(.white)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(12)
                            case .failure:
                                errorView
                            @unknown default:
                                errorView
                            }
                        }
                    } else if deliverable.kind == .link {
                        VStack(spacing: DesignSystem.spacing16) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                            
                            Text("这是一个外部交付链接")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)

                            Link(destination: deliverable.url) {
                                Text("立即前往浏览器打开")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(DesignSystem.primaryBlue)
                                    .cornerRadius(DesignSystem.radiusSmall)
                            }
                        }
                    } else {
                        errorView
                    }
                }
                .padding(.horizontal, DesignSystem.spacing20)

                Spacer()

                // Translucent Bottom Overlay
                if let note = deliverable.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                        Text("交付留言")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        Text(note)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(4)
                            .lineSpacing(2)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, DesignSystem.spacing20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var errorView: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.8))
            Text("交付链接不可用或已失效")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

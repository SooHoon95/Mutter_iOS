import SwiftUI

/// "무음 편지 0" 음악 플레이어 바 — 골드 원형 재생/일시정지 버튼 + 곡 제목·작곡가 + 재생 중 이퀄라이저.
/// (Compose 미리듣기 · Read 열람 공용.)
public struct MusicPlayerBar: View {
  private let title: String
  private let author: String?
  private let isPlaying: Bool
  private let onToggle: () -> Void

  public init(title: String, author: String? = nil, isPlaying: Bool, onToggle: @escaping () -> Void) {
    self.title = title
    self.author = author
    self.isPlaying = isPlaying
    self.onToggle = onToggle
  }

  public var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggle) {
        MutterIcon(isPlaying ? Asset.Images.pause : Asset.Images.play, size: 18)
          .foregroundStyle(Asset.Colors.onGold.color)
          .frame(width: 44, height: 44)
          .background(MutterGradient.gold, in: Circle())
          .shadows(.shadowLow)
      }
      .buttonStyle(PressableButtonStyle())

      VStack(alignment: .leading, spacing: 2) {
        Text(title).fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color).lineLimit(1)
        if let author {
          HStack(spacing: 5) {
            MutterIcon(Asset.Images.note, size: 12).foregroundStyle(Asset.Colors.inkFaint.color)
            Text(author).fonts(.caption).foregroundStyle(Asset.Colors.inkSoft.color).lineLimit(1)
          }
        }
      }
      Spacer(minLength: 8)

      if isPlaying {
        EqualizerView(color: Asset.Colors.gold.color, isPlaying: true)
      }
    }
    .padding(.vertical, 10)
    .padding(.leading, 10)
    .padding(.trailing, 14)
    .background(Asset.Colors.surface.color, in: Capsule())
    .overlay(Capsule().stroke(Asset.Colors.hairline.color, lineWidth: 1))
    .shadows(.shadowLow)
  }
}

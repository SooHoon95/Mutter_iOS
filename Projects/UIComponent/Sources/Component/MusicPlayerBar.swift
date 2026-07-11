import SwiftUI

/// 음악 플레이어 바 — 골드 원형 재생/일시정지 버튼 + 곡 제목·작곡가 + SoundCloud 출처 + 재생 중 이퀄라이저.
/// (Compose 미리듣기 · Read 열람 공용.)
///
/// SoundCloud 컴플라이언스: 재생은 공식 위젯(숨김 호스트)이 하되, 이 바에 **SoundCloud 브랜딩을
/// 노출**하고 **탭하면 원곡(SoundCloud) 페이지로 이동**한다(Widget Terms: 브랜딩 표시 + 링크백).
public struct MusicPlayerBar: View {
  private let title: String
  private let author: String?
  private let isPlaying: Bool
  private let sourceURL: URL?
  private let onToggle: () -> Void

  @Environment(\.openURL) private var openURL

  /// SoundCloud 브랜드 오렌지 (#FF5500).
  private static let soundCloudOrange = Color(red: 1.0, green: 0.333, blue: 0.0)

  public init(
    title: String,
    author: String? = nil,
    isPlaying: Bool,
    sourceURL: URL? = nil,
    onToggle: @escaping () -> Void
  ) {
    self.title = title
    self.author = author
    self.isPlaying = isPlaying
    self.sourceURL = sourceURL
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

      // 곡 정보 + SoundCloud 출처 — 탭하면 원곡(SoundCloud)으로 이동.
      Button {
        if let sourceURL { openURL(sourceURL) }
      } label: {
        VStack(alignment: .leading, spacing: 3) {
          Text(title).fonts(.bodyMediumBold).foregroundStyle(Asset.Colors.ink.color).lineLimit(1)
          if let author {
            HStack(spacing: 5) {
              MutterIcon(Asset.Images.note, size: 12).foregroundStyle(Asset.Colors.inkFaint.color)
              Text(author).fonts(.caption).foregroundStyle(Asset.Colors.inkSoft.color).lineLimit(1)
            }
          }
          // SoundCloud 브랜딩 + 링크백(약관 준수).
          HStack(spacing: 4) {
            Text("SoundCloud").fonts(.caption).foregroundStyle(Self.soundCloudOrange)
            if sourceURL != nil {
              MutterIcon(Asset.Images.link, size: 10).foregroundStyle(Self.soundCloudOrange)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(sourceURL == nil)

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

import SwiftUI

/// 테마가 적용된 편지지. 제목 + 본문 단락을 테마 타이포/색으로 렌더한다.
/// (웹 `TemplateThemed` + `LetterView` 이식. 스크롤·음악큐는 상위 feature가 담당.)
public struct LetterPaperView: View {
  private let theme: LetterTheme
  private let title: String?
  private let text: String
  /// 스크롤 진입 시 단락을 한 줄씩(위에서 아래로) 페이드-하강으로 드러내는 연출.
  /// 음악이 있는 편지를 연 뒤에만 켠다(무음/열기 전은 즉시 표시). 웹 Paginated.revealOnScroll과 동형.
  private let revealOnScroll: Bool

  public init(theme: LetterTheme, title: String? = nil, text: String, revealOnScroll: Bool = false) {
    self.theme = theme
    self.title = title
    self.text = text
    self.revealOnScroll = revealOnScroll
  }

  /// 빈 줄 기준 단락 분리(웹과 동일한 문단 호흡).
  private var paragraphs: [String] {
    text
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if let title, !title.isEmpty {
        Text(title).letterHeading(theme)
      }
      ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
        if revealOnScroll {
          RevealingParagraph(text: paragraph, theme: theme, index: index)
        } else {
          Text(paragraph).letterBody(theme)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(28)
    .background(theme.background)
    .overlay(LetterPaperTexture(theme: theme))
  }
}

// MARK: - Reveal 연출 단락

/// 스크롤로 화면에 들어오면 "위에서 아래로" 페이드-하강하며 한 번 나타나는 단락.
/// 한 번 나타나면 유지한다(스크롤 왕복 재생 없음). reduce motion이면 즉시 표시.
private struct RevealingParagraph: View {
  let text: String
  let theme: LetterTheme
  /// 문단 순서 — 동시에 보이는 단락들이 위→아래로 계단식 등장하도록 지연에 사용.
  let index: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var revealed = false

  /// 계단식 지연 — 그룹(6) 단위로 순환해 상한(≈0.3s)을 유지한다(스크롤 진입 단락의 과도한 지연 방지).
  private var staggerDelay: Double { Double(index % 6) * 0.06 }

  var body: some View {
    // reduce motion: 연출 없이 즉시 표시. 그 외엔 나타나기 전까지 숨긴 채 위로 살짝 올려둔다.
    let hidden = !revealed && !reduceMotion
    Text(text)
      .letterBody(theme)
      .opacity(hidden ? 0 : 1)
      .offset(y: hidden ? -12 : 0)
      .onScrollVisibilityChange(threshold: 0.1) { visible in
        if visible && !revealed {
          withAnimation(.easeOut(duration: 0.6).delay(staggerDelay)) { revealed = true }
        }
      }
  }
}

// MARK: - 테마 텍스트 모디파이어

private struct LetterTextStyle: ViewModifier {
  let theme: LetterTheme
  let isHeading: Bool

  func body(content: Content) -> some View {
    content
      .font(.system(
        size: isHeading ? theme.headingSize : theme.bodySize,
        weight: isHeading ? .semibold : .regular,
        design: theme.fontDesign
      ))
      .foregroundStyle(theme.foreground)
      .lineSpacing(isHeading ? theme.headingLineSpacing : theme.bodyLineSpacing)
  }
}

public extension View {
  /// 편지 본문 텍스트 스타일(테마 폰트/줄높이/색).
  func letterBody(_ theme: LetterTheme) -> some View {
    modifier(LetterTextStyle(theme: theme, isHeading: false))
  }

  /// 편지 제목 텍스트 스타일.
  func letterHeading(_ theme: LetterTheme) -> some View {
    modifier(LetterTextStyle(theme: theme, isHeading: true))
  }
}

// MARK: - 종이 텍스처

/// 테마 accent를 아주 옅게 깐 종이결 오버레이(웹 paperTexture 그라데이션 근사).
private struct LetterPaperTexture: View {
  let theme: LetterTheme

  var body: some View {
    LinearGradient(
      colors: [theme.accent.opacity(0.05), .clear],
      startPoint: .topLeading,
      endPoint: .center
    )
    .allowsHitTesting(false)
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 0) {
      ForEach(LetterTheme.all) { theme in
        LetterPaperView(
          theme: theme,
          title: theme.name,
          text: "사랑하는 너에게,\n\n오늘 문득 네 생각이 났어. 우리가 함께 들었던 그 노래가 흘러나왔거든.\n\n언제나 고마워."
        )
      }
    }
  }
}

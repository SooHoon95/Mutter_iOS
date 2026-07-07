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

  /// reveal용 줄 그룹 — 각 단락을 개행(\n) 기준 줄로 쪼개고, 전체 줄에 연속 인덱스를 부여한다
  /// (위→아래 계단식 지연 계산용). 웹 Paginated의 [data-reveal-line]과 동형.
  private var revealGroups: [RevealGroup] {
    var global = 0
    return paragraphs.enumerated().map { pIndex, para in
      let lines = para.components(separatedBy: "\n").map { line -> RevealLine in
        let item = RevealLine(id: global, text: line)
        global += 1
        return item
      }
      return RevealGroup(id: pIndex, lines: lines)
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if revealOnScroll {
        // 스크롤 reveal: 제목도 첫 줄로 나타난다(스크롤 전엔 숨김). 문단 간격은 바깥 VStack(20),
        // 문단 내 줄 간격은 안쪽 VStack. 전체 줄에 연속 인덱스로 위→아래 계단식.
        if let title, !title.isEmpty {
          RevealingLine(text: title, theme: theme, isHeading: true)
        }
        ForEach(revealGroups) { group in
          VStack(alignment: .leading, spacing: theme.bodyLineSpacing) {
            ForEach(group.lines) { line in
              RevealingLine(text: line.text, theme: theme)
            }
          }
        }
      } else {
        if let title, !title.isEmpty {
          Text(title).letterHeading(theme)
        }
        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
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

// MARK: - reveal 줄 모델

private struct RevealLine: Identifiable {
  let id: Int  // 전역 줄 인덱스(계단식 지연에 사용)
  let text: String
}

private struct RevealGroup: Identifiable {
  let id: Int  // 문단 인덱스
  let lines: [RevealLine]
}

// MARK: - Reveal 연출 줄

/// 스크롤로 화면에 들어오면 "위에서 아래로" 페이드-하강하며 한 번 나타나는 한 줄.
/// 한 번 나타나면 유지한다(스크롤 왕복 재생 없음). 웹 .revealMode .line과 동형.
/// reduce motion이면 이동은 빼고 페이드만(연출은 유지).
private struct RevealingLine: View {
  let text: String
  let theme: LetterTheme
  /// 제목 줄이면 heading 타이포로 렌더.
  var isHeading: Bool = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var revealed = false

  var body: some View {
    styledText
      // 짧은 줄도 왼쪽 정렬 폭을 유지(가운데로 쏠리지 않게).
      .frame(maxWidth: .infinity, alignment: .leading)
      .opacity(revealed ? 1 : 0)
      // reduce motion: 이동 없이 페이드만. 그 외엔 위(-10)에서 아래로 내려오며 나타남.
      .offset(y: (revealed || reduceMotion) ? 0 : -10)
      // 각 줄은 화면에 들어오는 "그 순간" 재생 → 위→아래 자연 순서 보장.
      // (인덱스 기반 계단식 지연은 순서를 뒤집어 아래 줄이 먼저 나오던 문제가 있어 제거.)
      .onScrollVisibilityChange(threshold: 0.05) { visible in
        if visible && !revealed {
          withAnimation(.easeOut(duration: 0.5)) { revealed = true }
        }
      }
  }

  @ViewBuilder private var styledText: some View {
    if isHeading {
      Text(text).letterHeading(theme)
    } else {
      Text(text.isEmpty ? " " : text).letterBody(theme)
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

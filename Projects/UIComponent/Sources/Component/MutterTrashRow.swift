import SwiftUI

/// 삭제함 행 — 제목 + 부가 정보 줄 + 복구·완전히 삭제 캡슐 버튼.
/// 보낸 편지 삭제함·받은 편지 삭제함이 같은 모양을 쓴다. UIComponent는 Domain을 모르므로 표시 문자열만 받는다.
public struct MutterTrashRow: View {
  private let title: String
  private let details: [String]
  private let onRestore: () -> Void
  private let onPurge: () -> Void

  /// - Parameters:
  ///   - title: 빈 문자열이면 "제목 없음".
  ///   - details: 제목 아래 줄들(보낸이, 남은 기간 등).
  public init(title: String, details: [String], onRestore: @escaping () -> Void, onPurge: @escaping () -> Void) {
    self.title = title
    self.details = details
    self.onRestore = onRestore
    self.onPurge = onPurge
  }

  /// 남은 기간 문구(스펙 3.2) — N일 후 완전히 삭제 / 0 이하면 오늘 완전히 삭제.
  public static func remainingText(days: Int) -> String {
    days > 0 ? L10n.trashDaysLeft(days) : L10n.trashPurgeToday
  }

  public var body: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title.isEmpty ? L10n.trashUntitled : title)
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.ink.color)
          .lineLimit(1)
        ForEach(details, id: \.self) { line in
          Text(line)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.inkFaint.color)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 0)
      capsuleButton(L10n.trashRestore, foreground: Asset.Colors.gold.color, background: Asset.Colors.goldSoft.color, action: onRestore)
      capsuleButton(L10n.trashPurge, foreground: Asset.Colors.danger.color, background: Asset.Colors.warm100.color, action: onPurge)
    }
    .padding(16)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.shadowMediumLow)
  }

  /// List 행 안에서 버튼마다 따로 눌리도록 `.plain` 스타일을 쓴다
  /// (기본 스타일이면 행 전체가 한 버튼처럼 탭돼 두 동작이 함께 실행된다).
  private func capsuleButton(
    _ title: String,
    foreground: Color,
    background: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .fonts(.captionBold)
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(background, in: Capsule())
    }
    .buttonStyle(.plain)
  }
}

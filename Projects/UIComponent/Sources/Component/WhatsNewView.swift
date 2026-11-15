import SwiftUI

/// 새 소식 안내 — 업데이트한 사람에게 한 번 보여 주는 넘겨 보는 다섯 장(실제 화면 캡처 + 제목 + 설명).
/// 사양 `docs/specs/2026-11-15-whats-new.md`. 앱 첫 화면(한 번)과 프로필 「새 소식」(다시 보기)이 함께 쓴다.
///
/// 일수는 서버 값을 받아 문구에 넣는다(UIComponent는 Domain을 모른다). 닫는 길은 「건너뛰기」와 마지막 장의
/// 「시작하기」 둘뿐이고, 둘 다 `onDone`을 부른다 — 한 번 봤다고 기억하는 일은 호출부가 한다.
public struct WhatsNewView: View {
  private let freeDays: Int
  private let graceDays: Int
  private let onDone: () -> Void

  @State private var index = 0

  public init(freeDays: Int, graceDays: Int, onDone: @escaping () -> Void) {
    self.freeDays = freeDays
    self.graceDays = graceDays
    self.onDone = onDone
  }

  public var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()

      VStack(spacing: 0) {
        HStack {
          Spacer()
          Button(action: onDone) {
            Text(L10n.whatsNewSkip)
              .fonts(.bodyMedium)
              .foregroundStyle(Asset.Colors.inkSoft.color)
              .padding(.vertical, 8)
              .padding(.horizontal, 4)
          }
          // 마지막 장에서는 아래 버튼이 닫는 역할이라 숨긴다(자리는 남겨 화면이 흔들리지 않게).
          .opacity(isLast ? 0 : 1)
          .disabled(isLast)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)

        TabView(selection: $index) {
          ForEach(pages.indices, id: \.self) { number in
            page(pages[number]).tag(number)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        dots
          .padding(.bottom, 16)

        MutterButton(isLast ? L10n.whatsNewStart : L10n.whatsNewNext) {
          if isLast {
            onDone()
          } else {
            withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
      }
      .frame(maxWidth: 520)
    }
  }

  private var isLast: Bool { index == pages.count - 1 }

  /// 다섯 장 — 그림, 제목, 설명(문장마다 줄을 바꾼다).
  private var pages: [(image: ImageAsset, title: String, detail: String)] {
    [
      (Asset.Images.whatsNew1, L10n.whatsNewPage1Title, L10n.whatsNewPage1Body),
      (Asset.Images.whatsNew2, L10n.whatsNewPage2Title, L10n.whatsNewPage2Body(freeDays)),
      (Asset.Images.whatsNew3, L10n.whatsNewPage3Title(freeDays, freeDays), L10n.whatsNewPage3Body(freeDays, graceDays)),
      (Asset.Images.whatsNew4, L10n.whatsNewPage4Title, L10n.whatsNewPage4Body),
      (Asset.Images.whatsNew5, L10n.whatsNewPage5Title, L10n.whatsNewPage5Body)
    ]
  }

  private func page(_ page: (image: ImageAsset, title: String, detail: String)) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      page.image.image
        .resizable()
        .scaledToFit()
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
          RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Asset.Colors.hairline.color, lineWidth: 1)
        )
        .shadows(.shadowLow)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 그림 속 글자를 하나씩 읽지 않도록 제목으로 대신한다.
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 8) {
        Text(page.title)
          .fonts(.title)
          .foregroundStyle(Asset.Colors.ink.color)
        Text(page.detail)
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.inkSoft.color)
          .lineSpacing(3)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
      .padding(.top, 20)
      .accessibilityElement(children: .combine)
    }
    .padding(.horizontal, 24)
    .padding(.top, 4)
    .padding(.bottom, 12)
  }

  /// 장 표시 점 — 지금 장은 길게.
  private var dots: some View {
    HStack(spacing: 7) {
      ForEach(pages.indices, id: \.self) { number in
        Capsule()
          .fill(number == index ? Asset.Colors.gold.color : Asset.Colors.hairlineStrong.color)
          .frame(width: number == index ? 20 : 7, height: 7)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: index)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(index + 1) / \(pages.count)")
  }
}

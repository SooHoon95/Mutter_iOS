import SwiftUI

import Domain
import UIComponent
import AudioSync

/// 수신/열람 화면 — 무마찰 원칙: 링크→웹뷰 없이 네이티브로 "열기 ▶" 한 탭.
public struct ViewerView: View {
  @State private var model: ViewerModelData
  /// 뒤로가기 — 라우팅 레이어 modifier 대신 뷰어 내부 내비바가 직접 호출(MU-7).
  private let onBack: () -> Void

  init(
    source: ViewerModelData.Source,
    deliveryUsecase: DeliveryUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterUsecase: LetterUsecasable,
    inboxUsecase: InboxUsecasable?,
    audioUsecase: AudioUsecasable,
    onBack: @escaping () -> Void
  ) {
    self.onBack = onBack
    _model = State(initialValue: ViewerModelData(
      source: source,
      deliveryUsecase: deliveryUsecase,
      receiptUsecase: receiptUsecase,
      letterUsecase: letterUsecase,
      inboxUsecase: inboxUsecase,
      audioUsecase: audioUsecase
    ))
  }

  public var body: some View {
    ZStack {
      // 숨김 오디오 뷰(SoundCloud WKWebView). 소스 타입을 모른 채 계층에 둔다(없으면 표시 안 함).
      // 소스 인스턴스에 .id를 묶어 재렌더마다 WKWebView가 재생성(위젯 JS 소실)되는 것을 막는다.
      if let source = model.player.currentSource, let attachment = source.attachmentView {
        attachment.id(ObjectIdentifier(source))
      }
      content
    }
    // 뷰어는 시스템 내비바를 숨기고, 편지 테마색과 맞춘 내비바를 Component로 직접 얹는다(MU-7).
    // 라우팅 레이어 modifier와 달리 여기선 model.state의 테마 배경/전경을 알 수 있다.
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .top, spacing: 0) {
      MutterNavigationBar(
        navColors.background,
        nil,
        foregroundColor: navColors.foreground,
        leftButtons: { MutterBackButton(foregroundColor: navColors.foreground, action: onBack) },
        rightButtons: { EmptyView() }
      )
    }
    .task { await model.load() }
  }

  /// 현재 상태의 배경/전경 — 내비바를 편지 테마(또는 스테이지 배경)와 정합시킨다.
  /// 열람 중=편지지 테마, 열기 전(openGate)=warm50, 예약공개=다크(ink), 그 외=ivory.
  private var navColors: (background: Color, foreground: Color) {
    switch model.state {
    case .ready(_, let theme):
      return model.isOpened
        ? (theme.background, theme.foreground)
        : (Asset.Colors.warm50.color, Asset.Colors.ink.color)
    case .revealPending:
      return (Asset.Colors.ink.color, Asset.Colors.ivory.color)
    default:
      return (Asset.Colors.ivory.color, Asset.Colors.ink.color)
    }
  }

  @ViewBuilder
  private var content: some View {
    switch model.state {
    case .loading:
      stage(Asset.Colors.ivory.color) {
        ProgressView().tint(Asset.Colors.gold.color)
      }
    case .passwordRequired:
      passwordGate
    case .revealPending(let date):
      revealPending(date)
    case .failed(let message):
      stage(Asset.Colors.ivory.color) {
        VStack(spacing: 8) {
          Text("편지를 열 수 없어요").fonts(.title).foregroundStyle(Asset.Colors.ink.color)
          Text(message).fonts(.bodyMedium).foregroundStyle(Asset.Colors.inkSoft.color)
        }
      }
    case .ready(let payload, let theme):
      if model.isOpened {
        reader(payload, theme)
      } else {
        openGate(payload, theme)
      }
    }
  }

  // MARK: - Open Gate (Screen 4)

  private func openGate(_ payload: LetterPayload, _ theme: LetterTheme) -> some View {
    stage(Asset.Colors.warm50.color) {
      VStack(spacing: 0) {
        Spacer()

        VStack(spacing: 24) {
          // 봉투 배지 — 골드 그라데이션 96pt 라운드 스퀘어
          ZStack {
            RoundedRectangle(cornerRadius: 28)
              .fill(MutterGradient.gold)
              .frame(width: 96, height: 96)
              .shadows(.shadowLow)
            MutterIcon(Asset.Images.envelope, size: 46)
              .foregroundStyle(Asset.Colors.onGold.color)
          }

          VStack(spacing: 8) {
            // 발신자 캡션 (LetterPayload에 sender 필드 없음 — 중립 문구 사용)
            Text("편지가 도착했어요")
              .fonts(.caption)
              .foregroundStyle(Asset.Colors.inkSoft.color)

            // 편지 제목
            Text(payload.title.isEmpty ? "소중한 편지" : payload.title)
              .fonts(.titleLarge)
              .foregroundStyle(Asset.Colors.ink.color)
              .multilineTextAlignment(.center)
          }

          // 안내 문구
          Text("음악과 함께 천천히 읽어보세요.\n편지를 열면 바로 시작됩니다.")
            .fonts(.bodyMedium)
            .foregroundStyle(Asset.Colors.inkSoft.color)
            .multilineTextAlignment(.center)
            .lineSpacing(4)

          // 열기 CTA
          MutterButton("편지 열기", icon: Asset.Images.play) {
            Task { await model.open() }
          }
          .frame(minWidth: 200, maxWidth: 280)

          // 설치 불필요 푸터
          HStack(spacing: 5) {
            MutterIcon(Asset.Images.check, size: 14)
              .foregroundStyle(Asset.Colors.inkFaint.color)
            Text("설치 없이 바로 열려요")
              .fonts(.caption)
              .foregroundStyle(Asset.Colors.inkFaint.color)
          }
        }
        .padding(.horizontal, 32)

        Spacer()
      }
    }
  }

  // MARK: - Reader (Screen 5)

  private func reader(_ payload: LetterPayload, _ theme: LetterTheme) -> some View {
    // 큐가 있고 재생 가능한 때만 하단 플레이어 표시(무음 편지·재생 불가 시 숨김).
    let hasPlayer = !payload.audioDisabled && payload.cue != nil && !model.player.isUnavailable

    return ZStack(alignment: .bottom) {
      theme.background.ignoresSafeArea()

      // 편지 본문 스크롤 — 화면 전체 높이. 상단 바는 라우팅 레이어의 MutterNavigationBar가 담당.
      // 열람 화면에선 항상 스크롤 reveal 연출(음악 유무 무관, 웹과 동일). 계단식 등장.
      ScrollView {
        VStack(spacing: 0) {
          // 처음엔 "스크롤 해주세요"만 한 화면 가득 — 편지(제목 포함)를 아래로 밀어내
          // 스크롤해야 한 줄씩 뷰포트에 들어오며 나타나게 한다(웹과 동일).
          ScrollPromptView(foreground: theme.foreground)

          LetterPaperView(theme: theme, title: payload.title, text: payload.body, revealOnScroll: true)
            .frame(maxWidth: .infinity)

          // 서버가 열람 시 자동 저장(마이그레이션 0022) — 인증 사용자 대상 토큰 수신에서만 표시.
          if model.canSaveToInbox && model.savedToInbox {
            HStack(spacing: 6) {
              MutterIcon(Asset.Images.check, size: 16)
                .foregroundStyle(Asset.Colors.gold.color)
              Text("받은 편지함에 저장됐어요")
                .fonts(.caption)
                .foregroundStyle(Asset.Colors.inkSoft.color)
            }
            .padding(.top, 8)
          }

          // 하단 고정 플레이어에 마지막 줄이 가려지지 않도록 여유 인셋(플레이어 있을 때만 크게).
          Color.clear.frame(height: hasPlayer ? 96 : 40)
        }
      }

      // 음악 플레이어 바 — 화면 최하단 고정 오버레이(safeArea 존중 — home indicator 위).
      if hasPlayer {
        MusicPlayerBar(
          title: payload.cue?.title ?? "SoundCloud 트랙",
          author: payload.cue?.author,
          isPlaying: model.player.isPlaying,
          sourceURL: payload.cue?.sourceUrl.flatMap { URL(string: $0) },
          onToggle: { model.player.toggle() }
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
      }
    }
  }

  // MARK: - Password Gate

  private var passwordGate: some View {
    stage(Asset.Colors.ivory.color) {
      VStack(spacing: 20) {
        // 자물쇠 배지 — 골드 소프트 배경 원형
        ZStack {
          Circle()
            .fill(Asset.Colors.goldSoft.color)
            .frame(width: 72, height: 72)
          MutterIcon(Asset.Images.lock, size: 32)
            .foregroundStyle(Asset.Colors.gold.color)
        }

        VStack(spacing: 6) {
          Text("암호가 걸린 편지예요")
            .fonts(.title)
            .foregroundStyle(Asset.Colors.ink.color)
          Text("발신자가 설정한 암호를 입력해 주세요")
            .fonts(.bodyMedium)
            .foregroundStyle(Asset.Colors.inkSoft.color)
        }

        // 암호 입력 필드
        SecureField("암호", text: $model.password)
          .textFieldStyle(.plain)
          .fonts(.bodyMedium)
          .foregroundStyle(Asset.Colors.ink.color)
          .padding(14)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))

        MutterButton("열기", isEnabled: !model.password.isEmpty) {
          Task { await model.submitPassword() }
        }
      }
      .padding(24)
      .frame(maxWidth: 360)
    }
  }

  // MARK: - Reveal Pending

  private func revealPending(_ date: Date) -> some View {
    stage(Asset.Colors.ink.color) {
      VStack(spacing: 12) {
        MutterIcon(Asset.Images.lock, size: 28).foregroundStyle(Asset.Colors.gold.color)
        Text("아직 열 수 없는 편지예요").fonts(.title).foregroundStyle(Asset.Colors.ivory.color)
        Text(Self.dateFormatter.string(from: date) + "에 열려요")
          .fonts(.bodyMedium).foregroundStyle(Asset.Colors.goldSoft.color)
      }
      .padding(32)
    }
  }

  // MARK: - Helpers

  private func stage<Inner: View>(_ background: Color, @ViewBuilder _ inner: () -> Inner) -> some View {
    ZStack {
      background.ignoresSafeArea()
      inner()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 a h시"
    return formatter
  }()
}

// MARK: - 스크롤 안내 인트로

/// 열람 첫 화면을 가득 채우는 "스크롤 해주세요" 안내 — 편지를 아래로 밀어내 스크롤을 유도한다.
/// containerRelativeFrame으로 스크롤 컨테이너 한 화면 높이를 차지한다(iOS 17+).
private struct ScrollPromptView: View {
  let foreground: Color

  var body: some View {
    VStack(spacing: 12) {
      Text("스크롤 해주세요")
        .fonts(.bodyMedium)
        .foregroundStyle(foreground.opacity(0.7))
      Image(systemName: "chevron.down")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(foreground.opacity(0.6))
        .symbolEffect(.bounce, options: .repeating)
    }
    .frame(maxWidth: .infinity)
    .containerRelativeFrame(.vertical)
  }
}

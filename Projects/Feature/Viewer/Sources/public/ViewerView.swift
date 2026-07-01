import SwiftUI

import Domain
import UIComponent
import AudioSync

/// 수신/열람 화면 — 무마찰 원칙: 링크→웹뷰 없이 네이티브로 "열기 ▶" 한 탭.
public struct ViewerView: View {
  @State private var model: ViewerModelData

  init(
    source: ViewerModelData.Source,
    deliveryUsecase: DeliveryUsecasable,
    receiptUsecase: ReceiptUsecasable,
    letterUsecase: LetterUsecasable,
    audioUsecase: AudioUsecasable
  ) {
    _model = State(initialValue: ViewerModelData(
      source: source,
      deliveryUsecase: deliveryUsecase,
      receiptUsecase: receiptUsecase,
      letterUsecase: letterUsecase,
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
    .task { await model.load() }
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
              .shadows(.gold)
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
    ZStack(alignment: .bottom) {
      theme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        // 상단 바 — 뒤로가기(인터트) + 더보기(인터트, 액션 없음)
        HStack {
          Button(action: {}) {
            MutterIcon(Asset.Images.back, size: 22)
              .foregroundStyle(theme.foreground)
          }
          Spacer()
          Button(action: {}) {
            MutterIcon(Asset.Images.more, size: 22)
              .foregroundStyle(theme.foreground)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)

        // 음악 플레이어 바
        if !payload.audioDisabled {
          MusicPlayerBar(
            title: payload.title.isEmpty ? "음악" : payload.title,
            author: nil,
            isPlaying: model.player.isPlaying,
            onToggle: { model.player.toggle() }
          )
          .padding(.horizontal, 20)
          .padding(.bottom, 12)
        }

        // 편지 본문 스크롤
        ScrollView {
          LetterPaperView(theme: theme, title: payload.title, text: payload.body)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 100)
        }
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

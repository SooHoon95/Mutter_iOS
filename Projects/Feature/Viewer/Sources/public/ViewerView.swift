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

  // MARK: - Stages

  private func openGate(_ payload: LetterPayload, _ theme: LetterTheme) -> some View {
    stage(theme.background) {
      VStack(spacing: 16) {
        Text(payload.title.isEmpty ? "편지가 도착했어요" : payload.title)
          .font(.system(size: theme.headingSize, weight: .semibold, design: theme.fontDesign))
          .foregroundStyle(theme.foreground)
          .multilineTextAlignment(.center)
        Button {
          Task { await model.open() }
        } label: {
          HStack(spacing: 8) {
            MutterIcon(Asset.Images.play, size: 14)
            Text("편지 열기")
          }
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(theme.background)
          .padding(.horizontal, 28).padding(.vertical, 14)
          .background(theme.accent, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        Text("음악과 함께 시작됩니다")
          .font(.system(size: 13, design: theme.fontDesign))
          .foregroundStyle(theme.muted)
      }
      .padding(32)
    }
  }

  private func reader(_ payload: LetterPayload, _ theme: LetterTheme) -> some View {
    ZStack(alignment: .bottomTrailing) {
      ScrollView {
        LetterPaperView(theme: theme, title: payload.title, text: payload.body)
          .frame(maxWidth: .infinity)
      }
      .background(theme.background.ignoresSafeArea())

      if !payload.audioDisabled {
        audioPill(theme).padding(20)
      }
    }
  }

  private func audioPill(_ theme: LetterTheme) -> some View {
    Button {
      model.player.toggle()
    } label: {
      HStack(spacing: 8) {
        if model.player.isPlaying {
          EqualizerView(color: theme.accent, isPlaying: true)
        } else {
          MutterIcon(Asset.Images.play, size: 14).foregroundStyle(theme.accent)
        }
      }
      .padding(.horizontal, 14).padding(.vertical, 10)
      .background(theme.background, in: Capsule())
      .overlay(Capsule().stroke(theme.border, lineWidth: 1))
      .shadows(.soft)
    }
  }

  private var passwordGate: some View {
    stage(Asset.Colors.ivory.color) {
      VStack(spacing: 12) {
        Text("암호가 걸린 편지예요").fonts(.title).foregroundStyle(Asset.Colors.ink.color)
        SecureField("암호", text: $model.password)
          .textFieldStyle(.plain)
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

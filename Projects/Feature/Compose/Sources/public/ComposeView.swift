import SwiftUI
import UIKit

import Domain
import UIComponent

/// 편지 제작 화면 — 편지지(테마) + 본문 + 음악 1곡 + 저장/발송.
public struct ComposeView: View {
  @State private var model: ComposeModelData
  private let navTitle: String
  private let onBack: () -> Void

  init(
    mode: ComposeModelData.Mode,
    navTitle: String,
    letterUsecase: LetterUsecasable,
    connectionUsecase: ConnectionUsecasable,
    deliveryUsecase: DeliveryUsecasable,
    audioUsecase: AudioUsecasable,
    linkBaseURL: String,
    onDone: @escaping () -> Void,
    onBack: @escaping () -> Void
  ) {
    self.navTitle = navTitle
    self.onBack = onBack
    _model = State(initialValue: ComposeModelData(
      mode: mode,
      letterUsecase: letterUsecase,
      connectionUsecase: connectionUsecase,
      deliveryUsecase: deliveryUsecase,
      audioUsecase: audioUsecase,
      linkBaseURL: linkBaseURL,
      onDone: onDone
    ))
  }

  public var body: some View {
    ZStack {
      // SoundCloud 미리듣기용 숨김 오디오 뷰. 소스 인스턴스에 .id를 묶어 재렌더마다
      // WKWebView가 재생성(위젯 JS 컨텍스트 소실)되는 것을 막는다 — 소스가 바뀔 때만 교체.
      if let source = model.player.currentSource, let attachment = source.attachmentView {
        attachment.id(ObjectIdentifier(source))
      }
      Asset.Colors.ivory.color.ignoresSafeArea()

      // Mercury 패턴: navbar를 body 최상단 Component로 직접 배치(모디파이어 아님).
      VStack(spacing: 0) {
        MutterNavigationBar(
          Asset.Colors.ivory.color,
          navTitle,
          foregroundColor: Asset.Colors.ink.color,
          leftButtons: { MutterBackButton(action: onBack) },
          rightButtons: { EmptyView() }
        )

        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            templatePicker
            paper
            musicSection
            if let message = model.errorMessage {
              Text(message).fonts(.caption).foregroundStyle(Asset.Colors.goldDeep.color)
            }
            actions
          }
          .padding(20)
          .frame(maxWidth: 600)
        }
        // 스크롤을 아래로 끌면 키보드가 함께 내려간다(대화형 dismiss).
        .scrollDismissesKeyboard(.interactively)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    // 키보드 위 '완료' 버튼 — 어떤 입력(제목·본문·SC 링크)에서든 명시적으로 내린다.
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("완료") { dismissKeyboard() }
          .fonts(.bodyMediumBold)
          .foregroundStyle(Asset.Colors.goldDeep.color)
      }
    }
    .task { await model.load() }
    .sheet(isPresented: $model.showSendSheet) {
      SendSheet(model: model)
    }
  }

  /// 현재 포커스된 입력의 키보드를 내린다(전역 first responder 해제).
  private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }

  // MARK: - Template

  private var templatePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(model.allThemes) { theme in
          Button { model.selectTemplate(theme) } label: {
            VStack(spacing: 4) {
              RoundedRectangle(cornerRadius: 6)
                .fill(theme.background)
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(
                  theme.id == model.templateId ? Asset.Colors.gold.color : theme.border,
                  lineWidth: theme.id == model.templateId ? 2 : 1))
              Text(theme.name).fonts(.caption)
                .foregroundStyle(theme.id == model.templateId ? Asset.Colors.ink.color : Asset.Colors.inkSoft.color)
            }
          }
        }
      }
      .padding(.horizontal, 2)
    }
  }

  // MARK: - Paper (편집)

  private var paper: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("제목", text: $model.title)
        .font(.system(size: model.theme.headingSize, weight: .semibold, design: model.theme.fontDesign))
        .foregroundStyle(model.theme.foreground)

      TextEditor(text: $model.content)
        .font(.system(size: model.theme.bodySize, design: model.theme.fontDesign))
        .foregroundStyle(model.theme.foreground)
        .frame(minHeight: 260)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .topLeading) {
          if model.content.isEmpty {
            Text("마음을 담아 적어보세요…")
              .font(.system(size: model.theme.bodySize, design: model.theme.fontDesign))
              .foregroundStyle(model.theme.muted)
              .padding(.top, 8).padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }
    }
    .padding(20)
    .background(model.theme.background, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .overlay(RoundedRectangle(cornerRadius: MutterRadius.lg).stroke(model.theme.border, lineWidth: 1))
  }

  // MARK: - Music

  private var musicSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("함께 흐를 음악 · 한 곡")
        .fonts(.captionBold).foregroundStyle(Asset.Colors.inkFaint.color)
        .frame(maxWidth: .infinity, alignment: .leading)

      // 선택된 곡 — 골드 플레이어 바(미리듣기).
      if model.cue != nil {
        MusicPlayerBar(
          title: model.appliedCueLabel ?? "선택된 음악",
          isPlaying: model.player.isPlaying,
          sourceURL: model.cue?.sourceUrl.flatMap { URL(string: $0) },
          onToggle: { Task { await model.previewAudio() } }
        )
      }

      HStack(spacing: 8) {
        TextField("SoundCloud 링크 붙여넣기", text: $model.soundcloudURL)
          .textFieldStyle(.plain)
          .padding(10)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        Button(model.isApplyingSoundCloud ? "확인 중…" : "적용") {
          Task { await model.applySoundCloudURL() }
        }
        .disabled(model.isApplyingSoundCloud)
        .fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
      }
    }
  }

  // MARK: - Actions

  private var actions: some View {
    VStack(spacing: 10) {
      if model.isReply {
        MutterButton("답장 보내기", isLoading: model.isSaving) {
          Task { await model.sendReply() }
        }
        MutterButton("임시 저장", style: .secondary, isLoading: model.isSaving) {
          Task { await model.saveAndClose() }
        }
      } else {
        MutterButton("저장하고 보내기", isLoading: model.isSaving) {
          Task { await model.saveAndOpenSend() }
        }
        MutterButton("임시 저장", style: .secondary, isLoading: model.isSaving) {
          Task { await model.saveAndClose() }
        }
      }
    }
  }
}

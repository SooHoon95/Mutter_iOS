import SwiftUI

import Domain
import UIComponent

/// 편지 제작 화면 — 편지지(테마) + 본문 + 음악 1곡 + 저장/발송.
public struct ComposeView: View {
  @State private var model: ComposeModelData

  init(
    mode: ComposeModelData.Mode,
    letterUsecase: LetterUsecasable,
    catalogUsecase: CatalogUsecasable,
    connectionUsecase: ConnectionUsecasable,
    deliveryUsecase: DeliveryUsecasable,
    audioUsecase: AudioUsecasable,
    linkBaseURL: String,
    onDone: @escaping () -> Void
  ) {
    _model = State(initialValue: ComposeModelData(
      mode: mode,
      letterUsecase: letterUsecase,
      catalogUsecase: catalogUsecase,
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
    }
    .task { await model.load() }
    .sheet(isPresented: $model.showSendSheet) {
      SendSheet(model: model)
    }
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
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(
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
          onToggle: { Task { await model.previewAudio() } }
        )
      }

      // 무드 픽커 — CC0 트랙 칩.
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(model.tracks) { track in
            MutterChip(track.title, icon: Asset.Images.note, selected: isSelected(track)) {
              model.selectTrack(track)
            }
          }
        }
      }

      HStack(spacing: 8) {
        TextField("SoundCloud 링크 붙여넣기", text: $model.soundcloudURL)
          .textFieldStyle(.plain)
          .padding(10)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        Button("적용") { model.applySoundCloudURL() }
          .fonts(.captionBold).foregroundStyle(Asset.Colors.goldDeep.color)
      }
    }
  }

  private func isSelected(_ track: Track) -> Bool {
    if let cue = model.cue, cue.source == .hosted, cue.ref == track.url { return true }
    return false
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

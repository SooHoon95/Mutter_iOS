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
    audioUsecase: AudioUsecasable,
    onDone: @escaping () -> Void
  ) {
    _model = State(initialValue: ComposeModelData(
      mode: mode,
      letterUsecase: letterUsecase,
      catalogUsecase: catalogUsecase,
      connectionUsecase: connectionUsecase,
      audioUsecase: audioUsecase,
      onDone: onDone
    ))
  }

  public var body: some View {
    ZStack {
      // SoundCloud 미리듣기용 숨김 오디오 뷰.
      if let attachment = model.player.currentSource?.attachmentView {
        attachment
      }
      MutterColor.ivory.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          templatePicker
          paper
          musicSection
          if let message = model.errorMessage {
            Text(message).fonts(.caption).foregroundStyle(MutterColor.goldDeep)
          }
          actions
        }
        .padding(20)
        .frame(maxWidth: 600)
      }
    }
    .task { await model.load() }
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
                  theme.id == model.templateId ? MutterColor.gold : theme.border,
                  lineWidth: theme.id == model.templateId ? 2 : 1))
              Text(theme.name).fonts(.caption)
                .foregroundStyle(theme.id == model.templateId ? MutterColor.ink : MutterColor.inkSoft)
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
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("음악").fonts(.bodyMediumBold).foregroundStyle(MutterColor.ink)
        Spacer()
        if model.cue != nil {
          Button {
            Task { await model.previewAudio() }
          } label: {
            Image(systemName: model.player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
              .font(.system(size: 22)).foregroundStyle(MutterColor.gold)
          }
        }
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(model.tracks) { track in
            Button { model.selectTrack(track) } label: {
              Text(track.title)
                .fonts(.caption)
                .foregroundStyle(isSelected(track) ? MutterColor.onGold : MutterColor.ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(isSelected(track) ? MutterColor.gold : MutterColor.surface, in: Capsule())
            }
          }
        }
      }

      HStack(spacing: 8) {
        TextField("SoundCloud 링크 붙여넣기", text: $model.soundcloudURL)
          .textFieldStyle(.plain)
          .padding(10)
          .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.md))
        Button("적용") { model.applySoundCloudURL() }
          .fonts(.captionBold).foregroundStyle(MutterColor.goldDeep)
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
      }
      MutterButton(model.isReply ? "임시 저장" : "저장", style: model.isReply ? .secondary : .primary, isLoading: model.isSaving) {
        Task { await model.saveAndClose() }
      }
    }
  }
}

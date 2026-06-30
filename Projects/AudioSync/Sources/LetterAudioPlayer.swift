import SwiftUI
import os

import Domain

/// 편지 1통의 음악 1곡을 재생하는 플레이어(Compose 미리듣기·Viewer 수신 공유).
/// 게이트 언락(▶) 시 시작해 끝까지 재생한다(스크롤 동기 없음 — PRD v5 단일트랙).
/// 무음0: SC 실패 시 항상 CC0로 폴백한다.
@MainActor
@Observable
public final class LetterAudioPlayer {
  public private(set) var isPlaying = false
  public private(set) var isReady = false
  /// 현재 소스. SoundCloud면 `attachmentView`(숨김 WKWebView)를 수신 화면이 배치해야 한다.
  public private(set) var currentSource: TrackSource?

  private let audioUsecase: AudioUsecasable
  private static let log = Logger(subsystem: "com.efreedom.mutter", category: "audio")

  public init(audioUsecase: AudioUsecasable) {
    self.audioUsecase = audioUsecase
  }

  /// 큐를 준비한다. SC 우선 → 실패 시 기본 CC0 폴백(무음0).
  public func prepare(cue: MusicCue) async {
    if await tryLoad(cue: cue) { return }
    if let fallback = try? await audioUsecase.defaultCue() {
      _ = await tryLoad(cue: fallback)
    }
  }

  /// 게이트 언락(▶) 시 호출 — 사용자 제스처 컨텍스트에서 재생 시작(iOS 오디오 언락).
  public func start() {
    play()
  }

  public func play() {
    currentSource?.play()
    isPlaying = true
  }

  public func pause() {
    currentSource?.pause()
    isPlaying = false
  }

  public func toggle() {
    isPlaying ? pause() : play()
  }

  public func setVolume(_ volume: Double) {
    currentSource?.setVolume(volume)
  }

  // MARK: - Private

  private func tryLoad(cue: MusicCue) async -> Bool {
    guard let spec = try? audioUsecase.resolvePlayback(cue) else {
      Self.log.error("resolvePlayback 실패 source=\(String(describing: cue.source)) ref=\(cue.ref, privacy: .public)")
      return false
    }
    Self.log.debug("tryLoad source=\(String(describing: cue.source)) ref=\(cue.ref, privacy: .public)")
    let source = TrackSourceFactory.make(spec: spec)
    source.onFinish = { [weak self] in self?.handleFinish() }
    // attachmentView 마운트를 위해 source를 먼저 노출 → 이어서 load 대기(SC는 webview READY 필요).
    currentSource = source
    isReady = false
    do {
      try await source.load()
      isReady = true
      Self.log.debug("tryLoad 성공 source=\(String(describing: cue.source))")
      return true
    } catch {
      Self.log.error("source.load() 실패(폴백) source=\(String(describing: cue.source)): \(error.localizedDescription, privacy: .public)")
      currentSource = nil
      return false
    }
  }

  private func handleFinish() {
    isPlaying = false
  }
}

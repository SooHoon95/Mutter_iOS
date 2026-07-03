import SwiftUI
import os

import Domain

/// 편지 1통의 음악 1곡을 재생하는 플레이어(Compose 미리듣기·Viewer 수신 공유).
/// 게이트 언락(▶) 시 시작해 끝까지 재생한다(스크롤 동기 없음 — PRD 단일트랙).
/// 음원은 SoundCloud 단일 — 로드/재생 실패 시 폴백 없이 "음악 없음"으로 정리한다(무음 허용, 사용자 결정).
@MainActor
@Observable
public final class LetterAudioPlayer {
  public private(set) var isPlaying = false
  public private(set) var isReady = false
  /// 재생이 불가로 판명됨(로드 실패·위젯 무음). UI가 "음악을 재생할 수 없어요" 표시에 사용.
  public private(set) var isUnavailable = false
  /// 현재 소스. SoundCloud면 `attachmentView`(숨김 WKWebView)를 수신 화면이 배치해야 한다.
  public private(set) var currentSource: TrackSource?

  private let audioUsecase: AudioUsecasable
  /// 소스 생성 지점(테스트 주입용 심 — 프로덕션은 팩토리 그대로).
  @ObservationIgnored var makeSource: (TrackSourceSpec) -> TrackSource = { TrackSourceFactory.make(spec: $0) }
  private static let log = Logger(subsystem: "com.efreedom.mutter", category: "audio")

  public init(audioUsecase: AudioUsecasable) {
    self.audioUsecase = audioUsecase
  }

  /// 큐를 준비한다. 실패하면 음악 없음(isUnavailable) — 폴백 없음.
  public func prepare(cue: MusicCue) async {
    isUnavailable = false
    guard let spec = try? audioUsecase.resolvePlayback(cue) else {
      Self.log.error("resolvePlayback 실패 source=\(String(describing: cue.source)) ref=\(cue.ref, privacy: .public)")
      markUnavailable()
      return
    }
    Self.log.debug("prepare source=\(String(describing: cue.source)) ref=\(cue.ref, privacy: .public)")
    let source = makeSource(spec)
    source.onFinish = { [weak self] in self?.isPlaying = false }
    // 재생 불발(READY 후 무음·위젯 ERROR) — 재생 중인 척하지 않도록 상태를 정리한다.
    source.onPlaybackStalled = { [weak self, weak source] in
      guard let self, let source, self.currentSource === source else { return }
      Self.log.error("재생 불발 감지 — 음악 없음 처리")
      self.markUnavailable()
    }
    // attachmentView 마운트를 위해 source를 먼저 노출 → 이어서 load 대기(SC는 webview READY 필요).
    currentSource = source
    isReady = false
    do {
      try await source.load()
      isReady = true
      Self.log.debug("prepare 성공")
      // 로드 대기 중에 이미 ▶로 재생을 시작했다면 재생 의도를 이어간다.
      if isPlaying { source.play() }
    } catch {
      Self.log.error("source.load() 실패: \(error.localizedDescription, privacy: .public)")
      markUnavailable()
    }
  }

  /// 게이트 언락(▶) 시 호출 — 사용자 제스처 컨텍스트에서 재생 시작(iOS 오디오 언락).
  public func start() {
    play()
  }

  public func play() {
    guard !isUnavailable else { return }
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

  private func markUnavailable() {
    currentSource = nil
    isReady = false
    isPlaying = false
    isUnavailable = true
  }
}

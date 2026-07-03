import SwiftUI
import AVFoundation
import MediaPlayer
import os

import AppFoundation

/// 호스팅 오디오(CC0 폴백·Storage) 재생 — AVPlayer 기반.
/// 백그라운드/잠금화면 재생을 위해 AVAudioSession(.playback) + 원격 명령(재생/일시정지)을 설정한다.
/// (백그라운드 오디오는 MutterApp Info.plist의 UIBackgroundModes=audio 필요 — 합성 루트에서 설정.)
@MainActor
public final class HostedAudioSource: TrackSource {
  private let url: URL
  private let startMs: Int

  private var player: AVPlayer?
  private var endObserver: NSObjectProtocol?
  private var remoteConfigured = false
  private static let log = Logger(subsystem: "com.efreedom.mutter", category: "audio")

  public var onFinish: (() -> Void)?
  /// AVPlayer 항목이 재생 불가로 판명될 때 통지(번들 파일은 사실상 발생 안 함 — 원격 URL 대비).
  public var onPlaybackStalled: (() -> Void)?

  public init(url: URL, startMs: Int = 0) {
    self.url = url
    self.startMs = startMs
  }

  deinit {
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
  }

  public func load() async throws {
    configureAudioSession()   // 비치명적 — 세션 설정 실패해도 재생은 시도한다(무음0).

    let fileOK = url.isFileURL ? FileManager.default.fileExists(atPath: url.path) : true
    Self.log.debug("Hosted load url=\(self.url.absoluteString, privacy: .public) isFile=\(self.url.isFileURL) exists=\(fileOK)")
    if !fileOK {
      // 번들 파일 부재 = 재생 불가 확정 — 조용히 무음으로 가지 말고 실패시켜 폴백을 태운다(무음0).
      Self.log.error("Hosted 음원 파일 없음 → load 실패 처리(폴백 유도)")
      throw MutterError(.server("음원 파일을 찾을 수 없어요."))
    }

    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    player.automaticallyWaitsToMinimizeStalling = true
    self.player = player

    if startMs > 0 {
      // async 컨텍스트에서는 seek(to:)의 async 오버로드가 선택된다(결과 Bool은 무시).
      await player.seek(to: time(ms: startMs))
    }
    observeEnd(item: item)
    configureRemoteCommands()
  }

  public func play() {
    player?.play()
    Self.log.debug("Hosted play() rate=\(self.player?.rate ?? -1) itemStatus=\(self.player?.currentItem?.status.rawValue ?? -99)")
    updateNowPlaying(rate: 1)
  }

  public func pause() {
    player?.pause()
    updateNowPlaying(rate: 0)
  }

  public func seek(toMs ms: Int) {
    player?.seek(to: time(ms: ms))
  }

  public func setVolume(_ volume: Double) {
    player?.volume = Float(max(0, min(1, volume)))
  }

  // MARK: - Private

  private func time(ms: Int) -> CMTime {
    CMTime(value: CMTimeValue(ms), timescale: 1000)
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
    } catch {
      Self.log.error("AVAudioSession 설정 실패(무시): \(error.localizedDescription, privacy: .public)")
    }
  }

  private func observeEnd(item: AVPlayerItem) {
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.onFinish?() }
    }
  }

  private func configureRemoteCommands() {
    guard !remoteConfigured else { return }
    remoteConfigured = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { [weak self] _ in
      self?.play()
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      self?.pause()
      return .success
    }
  }

  private func updateNowPlaying(rate: Double) {
    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
    info[MPNowPlayingInfoPropertyPlaybackRate] = rate
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }
}

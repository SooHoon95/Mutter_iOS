import XCTest

import Domain
@testable import AudioSync

/// LetterAudioPlayer 동작 회귀 테스트 (SC 단일 음원, 무음 허용 정책).
/// 버그 이력: 로드 대기 중 ▶가 먼저 오면 재생 의도가 유실돼 무음이 되던 문제 —
/// 재생 의도 승계와 실패 시 상태 정리(isUnavailable)를 고정한다.
@MainActor
final class LetterAudioPlayerTests: XCTestCase {

  // MARK: - Fakes

  /// 로드 성공/실패와 play() 호출 여부를 기록하는 가짜 소스.
  final class FakeSource: TrackSource {
    let shouldFailLoad: Bool
    private(set) var didPlay = false
    var onFinish: (() -> Void)?
    var onPlaybackStalled: (() -> Void)?

    init(shouldFailLoad: Bool) { self.shouldFailLoad = shouldFailLoad }

    func load() async throws {
      if shouldFailLoad { throw NSError(domain: "test", code: 1) }
    }
    func play() { didPlay = true }
    func pause() {}
    func seek(toMs ms: Int) {}
    func setVolume(_ volume: Double) {}
  }

  final class FakeAudioUsecase: AudioUsecasable {
    func resolvePlayback(_ cue: MusicCue) throws -> TrackSourceSpec {
      .soundcloud(trackURL: URL(string: "https://soundcloud.com/t/x")!, startMs: cue.startMs)
    }
    func validateSoundCloud(url: String) async -> ScValidation {
      .ok(title: "", author: "", canonicalUrl: url)
    }
  }

  private let cue = MusicCue(source: .soundcloud, ref: "https://soundcloud.com/t/x", startMs: 0)

  private func makePlayer(source: FakeSource) -> LetterAudioPlayer {
    let player = LetterAudioPlayer(audioUsecase: FakeAudioUsecase())
    player.makeSource = { _ in source }
    return player
  }

  // MARK: - Tests

  /// 핵심 회귀: 로드 대기 중 ▶(play)가 먼저 와도, 로드 완료 시 재생 의도가 승계돼야 한다.
  func test_로드완료시_재생의도승계() async {
    let source = FakeSource(shouldFailLoad: false)
    let player = makePlayer(source: source)

    player.play()                    // 준비 완료 전에 ▶
    await player.prepare(cue: cue)

    XCTAssertTrue(source.didPlay, "로드 완료 후 보류된 재생 의도가 실행돼야 한다")
    XCTAssertTrue(player.isReady)
    XCTAssertTrue(player.isPlaying)
  }

  /// 로드 실패 → 폴백 없이 '음악 없음' 상태로 정리(무음 허용).
  func test_로드실패_음악없음처리() async {
    let source = FakeSource(shouldFailLoad: true)
    let player = makePlayer(source: source)

    player.play()
    await player.prepare(cue: cue)

    XCTAssertTrue(player.isUnavailable)
    XCTAssertFalse(player.isPlaying, "재생 중인 척하지 않는다")
    XCTAssertNil(player.currentSource)
    XCTAssertFalse(source.didPlay)
  }

  /// READY 후 무음(stalled) 통지 → '음악 없음' 상태로 정리(재생 중 표시 해제).
  func test_재생불발통지_상태정리() async {
    let source = FakeSource(shouldFailLoad: false)
    let player = makePlayer(source: source)

    await player.prepare(cue: cue)
    player.play()
    XCTAssertTrue(source.didPlay)

    source.onPlaybackStalled?()      // 위젯 무음/ERROR 감지 시뮬레이션

    XCTAssertTrue(player.isUnavailable)
    XCTAssertFalse(player.isPlaying)
    XCTAssertNil(player.currentSource)

    player.play()                    // 불가 상태에서 재생 시도 → 무시
    XCTAssertFalse(player.isPlaying)
  }
}

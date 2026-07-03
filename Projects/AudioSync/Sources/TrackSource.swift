import SwiftUI

/// 단일 음원 재생 추상화. 싱크 엔진/플레이어는 소스 타입(SoundCloud/호스팅)을 모른다.
/// 구현체: `HostedAudioSource`(AVPlayer), `SoundCloudSource`(WKWebView + Widget API).
@MainActor
public protocol TrackSource: AnyObject {
  /// 재생 준비(네트워크/위젯 초기화). 완료 후 play 가능. 실패 시 throw(폴백 트리거).
  func load() async throws
  func play()
  func pause()
  /// 지정 위치로 이동(ms).
  func seek(toMs ms: Int)
  /// 볼륨 0.0...1.0(페이드용).
  func setVolume(_ volume: Double)
  /// 재생 종료 콜백.
  var onFinish: (() -> Void)? { get set }
  /// 재생을 시작했어야 하는데 소리가 나지 못한 경우(위젯 차단·오류 등) 통지.
  /// 플레이어가 이 신호로 CC0 폴백을 트리거한다(무음0).
  var onPlaybackStalled: (() -> Void)? { get set }
  /// 이 소스가 동작하려면 뷰 계층에 있어야 하는 숨김 뷰(SoundCloud=WKWebView). AVPlayer=nil.
  /// 수신 화면이 소스 타입을 모른 채 이 뷰만 숨겨서 배치한다.
  var attachmentView: AnyView? { get }
}

public extension TrackSource {
  var attachmentView: AnyView? { nil }
}

import Foundation

/// SoundCloud paste-URL 검증 결과(웹 `scOembed.ts`와 동형).
/// 성공 시 canonicalUrl을 큐에 저장한다 — 단축링크(on.soundcloud.com)는 위젯이 직접 못 열므로
/// oEmbed가 변환해 준 canonical 트랙 URL이 실제 재생 가능한 참조다.
public enum ScValidation: Equatable {
  case ok(title: String, author: String, canonicalUrl: String)
  case fail(ScValidationFailReason)
}

/// 거부 사유(웹과 동일 분류).
public enum ScValidationFailReason: Equatable {
  /// soundcloud.com 호스트가 아님.
  case invalidUrl
  /// fetch 자체 실패(오프라인 등).
  case network
  /// 401/403 — 비공개 또는 지역 제한(SC가 둘 다 403이라 구분 불가, 통합).
  case privateTrack
  /// 404 등 — 없는/삭제된 트랙.
  case notFound
  /// 200이지만 embed html이 빈 경우 — 작성자가 임베드를 막은 트랙.
  case embedDisabled
}

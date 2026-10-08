import Foundation

/// 편지 사진 저장소 접근 프로토콜(구현은 Infrastructure — Storage `letter-photos` 버킷 + Edge Function `letter-photo-urls`).
public protocol LetterPhotoRepositorable {
  /// JPEG를 `<uid>/<letterId>/<uuid>.jpg`로 올리고 그 경로를 돌려준다.
  func upload(jpeg: Data, letterId: String) async throws -> String
  /// 이 편지 폴더에 실제로 올라가 있는 객체 경로.
  func storedPaths(letterId: String) async throws -> [String]
  func delete(paths: [String]) async throws
  /// 편지 폴더 전체 삭제(편지 삭제 시).
  func deleteAll(letterId: String) async throws
  /// 수신자 모드 서명 URL(path → URL). 링크 검증은 서버가 get_letter_by_token으로 재사용한다.
  func signedURLs(token: String, password: String?) async throws -> [String: URL]
  /// 소유자 모드 서명 URL(path → URL).
  func signedURLs(letterId: String) async throws -> [String: URL]
}

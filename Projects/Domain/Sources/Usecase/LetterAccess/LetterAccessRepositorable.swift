import Foundation

/// 편지 접근 상태 데이터 접근 프로토콜(구현은 Infrastructure — get_letter_cover·get_letter_access_states·
/// get_letter_readers·request_keep_letter·get_letter_keep_requests RPC, duplicate-letter Edge Function).
public protocol LetterAccessRepositorable {
  /// 봉투(본문·열람 기록 없음). 로그인 전 화면·잠김 화면용.
  func cover(token: String) async throws -> LetterCover
  /// 내가 보냈거나 받은 편지함에 가진 편지의 접근 상태.
  func accessStates(letterIds: [String]) async throws -> [LetterAccessState]
  /// 보낸 편지의 열람자(소유자만). 처음 연 순.
  func readers(letterId: String) async throws -> [LetterReader]
  /// 같은 내용으로 새 편지를 만든다. 새 편지 id를 돌려준다(링크 없음 — 이어서 발송 흐름).
  func duplicate(letterId: String) async throws -> String
  /// 받은 사람이 잠긴 편지를 보낸 사람에게 간직하고 싶다고 알린다.
  /// 새로 알렸으면 true, 이미 알렸거나 알릴 일이 없으면 false — 둘 다 성공이다.
  func requestKeep(token: String, password: String?) async throws -> Bool
  /// 보낸 편지의 간직 요청자(소유자만). 요청한 순.
  func keepRequests(letterId: String) async throws -> [LetterKeepRequest]
}

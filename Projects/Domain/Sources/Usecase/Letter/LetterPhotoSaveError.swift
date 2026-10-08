import Foundation

/// 편지 행은 있지만 사진 단계(업로드·경로 반영)가 실패한 경우. 세 플랫폼 공통으로 "저장 실패"로 알린다.
/// 새 편지라면 이 시점에 행이 이미 만들어졌으므로, 호출부는 `letterId`로 이후 저장을 갱신(update)으로 바꿔
/// 같은 편지가 중복 생성되지 않게 한다. 이미 올라간 객체는 다음 저장의 정리 단계가 지운다.
public struct LetterPhotoSaveError: Error {
  public let letterId: String
  public let underlying: Error

  public init(letterId: String, underlying: Error) {
    self.letterId = letterId
    self.underlying = underlying
  }
}

import Foundation

/// `verify-purchase` 요청(iOS) `{ platform: "ios", jws }`. 사용자 JWT는 SDK가 Authorization에 싣는다.
struct VerifyPurchaseRequest: Encodable {
  let platform: String
  let jws: String
}

/// `verify-purchase` 200 응답. granted=false(이미 지급된 영수증)도 성공이다.
struct VerifyPurchaseResponse: Decodable {
  let granted: Bool
  let tickets: Int
}

/// `verify-purchase` 오류 본문 `{ error: "<코드>" }`.
struct VerifyPurchaseErrorBody: Decodable {
  let error: String
}

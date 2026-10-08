import Foundation

/// `letter-photo-urls` 수신자 모드 요청. password는 null도 명시해 보낸다(함수가 키 존재로 모드를 가른다).
struct LetterPhotoURLsTokenRequest: Encodable {
  let token: String
  let password: String?

  enum CodingKeys: String, CodingKey { case token, password }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(token, forKey: .token)
    try c.encode(password, forKey: .password)
  }
}

/// `letter-photo-urls` 소유자 모드 요청(사용자 JWT는 SDK가 Authorization에 싣는다).
struct LetterPhotoURLsOwnerRequest: Encodable {
  let letterId: String
}

/// `letter-photo-urls` 응답 — `{ urls: { <path>: <signedUrl> }, expiresIn }`.
struct LetterPhotoURLsResponse: Decodable {
  let urls: [String: String]
  let expiresIn: Int?

  func toDomain() -> [String: URL] {
    urls.compactMapValues(URL.init(string:))
  }
}

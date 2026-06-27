import Foundation

import Domain

/// profiles 테이블 row(조회용).
struct ProfileDTO: Decodable {
  let id: String
  let nickname: String?

  func toDomain() -> Profile {
    Profile(id: id, nickname: nickname)
  }
}

/// profiles upsert 페이로드(닉네임 저장용).
struct ProfileUpsertDTO: Encodable {
  let id: String
  let nickname: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case nickname
    case updatedAt = "updated_at"
  }
}

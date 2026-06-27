import Foundation

import Domain

/// tracks.json 항목(번들 카탈로그). source/provenance/_note 등 추가 키는 무시.
struct CatalogEntryDTO: Decodable {
  let id: String
  let title: String
  let author: String
  let license: String
  let url: String
  let mood: String?

  func toDomain() -> Track {
    Track(id: id, title: title, author: author, license: license, url: url, mood: mood ?? "")
  }
}

import Foundation

import Domain

/// 블록 편집기의 한 칸. 텍스트 칸은 TextEditor 바인딩과 포커스를 위해 안정적인 id가 필요해
/// 도메인 `LetterBlock`(id 없는 텍스트) 대신 이 형태로 편집한다.
struct ComposeBlock: Identifiable, Equatable {
  let id: String
  var text: String
  /// 있으면 사진 칸(text는 쓰지 않는다).
  var photo: LetterPhoto?

  static func text(_ text: String) -> ComposeBlock {
    ComposeBlock(id: UUID().uuidString, text: text, photo: nil)
  }

  static func photo(_ photo: LetterPhoto) -> ComposeBlock {
    ComposeBlock(id: photo.id, text: "", photo: photo)
  }

  init(id: String, text: String, photo: LetterPhoto?) {
    self.id = id
    self.text = text
    self.photo = photo
  }

  init(_ block: LetterBlock) {
    switch block {
    case .text(let text): self = .text(text)
    case .photo(let photo): self = .photo(photo)
    }
  }

  var letterBlock: LetterBlock {
    photo.map(LetterBlock.photo) ?? .text(text)
  }
}

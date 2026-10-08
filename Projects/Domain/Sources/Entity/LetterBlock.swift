import Foundation

/// 편지 본문을 이루는 블록. 텍스트와 사진이 순서대로 섞인다.
/// 저장 형식(`paragraphs` jsonb)과의 변환은 Infrastructure(`LetterContentCodec`)가 맡는다.
public enum LetterBlock: Equatable {
  case text(String)
  case photo(LetterPhoto)

  public var photo: LetterPhoto? {
    if case .photo(let photo) = self { return photo }
    return nil
  }
}

public extension Array where Element == LetterBlock {
  /// 텍스트 블록만 빈 줄로 이은 본문. 목록 미리보기 등 사진을 모르는 호출부가 쓴다.
  var joinedText: String {
    compactMap { block -> String? in
      if case .text(let text) = block { return text }
      return nil
    }
    .joined(separator: "\n\n")
  }

  var photos: [LetterPhoto] { compactMap(\.photo) }

  /// 저장된(path가 있는) 사진 경로.
  var photoPaths: [String] { photos.compactMap(\.path) }
}

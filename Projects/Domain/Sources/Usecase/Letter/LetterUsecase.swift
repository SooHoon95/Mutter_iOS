import Foundation

import AppFoundation

/// 편지 유스케이스 구현. 음악은 선택 사항(SC 단일 음원, 무음 허용) — cue nil이면 그대로 저장.
/// 사진 저장 순서(세 플랫폼 공통): letterId 확보 → 대기 사진 업로드 → 경로 반영 update → 안 쓰는 객체 정리.
public final class LetterUsecase: LetterUsecasable {
  private let repository: LetterRepositorable
  private let photoRepository: LetterPhotoRepositorable

  public init(repository: LetterRepositorable, photoRepository: LetterPhotoRepositorable) {
    self.repository = repository
    self.photoRepository = photoRepository
  }

  public func create(_ draft: LetterDraft) async throws -> Letter {
    // 경로가 없는 대기 사진은 저장 형식에 실리지 않으므로, 먼저 텍스트만으로 행을 만들어 letterId를 얻는다.
    var letter = try await repository.create(draft)
    guard draft.blocks.photos.contains(where: { $0.pendingJPEG != nil }) else { return letter }
    do {
      letter.blocks = try await update(id: letter.id, draft)
      return letter
    } catch let error as LetterPhotoSaveError {
      throw error
    } catch {
      throw LetterPhotoSaveError(letterId: letter.id, underlying: error)
    }
  }

  @discardableResult
  public func update(id: String, _ draft: LetterDraft) async throws -> [LetterBlock] {
    let blocks: [LetterBlock]
    do {
      blocks = try await uploadPendingPhotos(draft.blocks, letterId: id)
    } catch {
      throw LetterPhotoSaveError(letterId: id, underlying: error)
    }
    var resolved = draft
    resolved.blocks = blocks
    try await repository.update(id: id, resolved)
    await removeUnreferencedPhotos(letterId: id, keeping: Set(blocks.photoPaths))
    return blocks
  }

  public func letter(id: String) async throws -> Letter? {
    try await repository.letter(id: id)
  }

  public func myLetters() async throws -> [Letter] {
    try await repository.myLetters()
  }

  public func myLettersWithStatus() async throws -> [LetterWithStatus] {
    try await repository.myLettersWithStatus()
  }

  public func delete(id: String) async throws {
    try await repository.delete(id: id)
    // 사진 정리는 best effort — 편지 삭제 자체는 이미 끝났으므로 실패를 사용자에게 올리지 않는다.
    try? await photoRepository.deleteAll(letterId: id)
  }

  public func photoURLs(token: String, password: String?) async throws -> [String: URL] {
    try await photoRepository.signedURLs(token: token, password: password)
  }

  public func photoURLs(letterId: String) async throws -> [String: URL] {
    try await photoRepository.signedURLs(letterId: letterId)
  }

  // MARK: - Private

  /// 대기 사진을 순서대로 올려 path를 채운다. 하나라도 실패하면 저장 실패로 던진다
  /// (이미 올라간 객체는 남겨 두고 다음 저장의 정리 단계가 지운다).
  private func uploadPendingPhotos(_ blocks: [LetterBlock], letterId: String) async throws -> [LetterBlock] {
    var resolved: [LetterBlock] = []
    for block in blocks {
      guard case .photo(var photo) = block, let jpeg = photo.pendingJPEG else {
        resolved.append(block)
        continue
      }
      photo.path = try await photoRepository.upload(jpeg: jpeg, letterId: letterId)
      photo.pendingJPEG = nil
      resolved.append(.photo(photo))
    }
    return resolved
  }

  /// 폴더에 있지만 본문이 더는 참조하지 않는 객체(지운 사진, 지난 실패 업로드)를 지운다. best effort.
  private func removeUnreferencedPhotos(letterId: String, keeping: Set<String>) async {
    guard let stored = try? await photoRepository.storedPaths(letterId: letterId) else { return }
    let stale = stored.filter { !keeping.contains($0) }
    guard !stale.isEmpty else { return }
    try? await photoRepository.delete(paths: stale)
  }
}

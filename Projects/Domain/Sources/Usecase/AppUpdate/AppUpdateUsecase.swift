import Foundation

/// 강제 업데이트 판단 구현 — 설치 버전 vs App Store 최신 버전 시맨틱 비교.
public final class AppUpdateUsecase: AppUpdateUsecasable {
  private let repository: AppUpdateRepositorable

  public init(repository: AppUpdateRepositorable) {
    self.repository = repository
  }

  public func isUpdateRequired(currentVersion: String) async -> Bool {
    // 조회 실패/미게시면 강제하지 않는다(fail-open) — 네트워크 문제로 앱이 잠기는 것을 막는다.
    guard let store = try? await repository.latestAppStoreVersion(), !store.isEmpty else {
      return false
    }
    // 메이저 버전이 올라간 경우에만 강제. 마이너/패치 업데이트는 사용자가 수동으로 한다.
    return Self.isMajorUpdate(current: currentVersion, store: store)
  }

  /// 스토어 최신의 메이저(첫 번째) 버전이 설치 버전보다 높으면 true(= 메이저 업데이트 → 강제).
  /// 예) 1.4.2 → 2.0.0 은 강제, 1.0.1 → 1.3.0(마이너)·1.0.1 → 1.0.9(패치)는 강제 아님.
  static func isMajorUpdate(current: String, store: String) -> Bool {
    major(store) > major(current)
  }

  /// "1.0.2" 형식에서 메이저(첫 번째) 정수를 뽑는다. 파싱 실패 시 0.
  private static func major(_ version: String) -> Int {
    version.split(separator: ".").first
      .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
  }
}

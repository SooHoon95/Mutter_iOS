import Foundation

public extension Error {
  /// raw 에러를 `MutterError`로 정규화한다. 이미 `MutterError`면 그대로, 아니면 알 수 있는 만큼 매핑한다.
  /// 미매핑 에러는 nil을 반환하므로 호출부에서 `?? MutterError(.unknown)`으로 마무리한다.
  func toMutterError() -> MutterError? {
    if let mutterError = self as? MutterError { return mutterError }
    if let urlError = self as? URLError {
      switch urlError.code {
      case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost:
        return MutterError(.network)
      default:
        return MutterError(.unknown)
      }
    }
    return nil
  }
}

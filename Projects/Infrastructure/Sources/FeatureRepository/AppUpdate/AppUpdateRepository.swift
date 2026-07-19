import Foundation

import Domain

/// App Store 최신 버전 조회 — iTunes Lookup 공개 API(인증 불필요).
/// 스토어에 게시된 **라이브 버전**을 돌려준다(심사 중/미출시 버전은 반영되지 않음).
public final class AppUpdateRepository: AppUpdateRepositorable {
  private let bundleId: String
  private let country: String
  private let session: URLSession

  public init(
    bundleId: String,
    country: String = "kr",
    session: URLSession = .shared
  ) {
    self.bundleId = bundleId
    self.country = country
    self.session = session
  }

  public func latestAppStoreVersion() async throws -> String? {
    guard var comps = URLComponents(string: "https://itunes.apple.com/lookup") else { return nil }
    comps.queryItems = [
      URLQueryItem(name: "bundleId", value: bundleId),
      URLQueryItem(name: "country", value: country)
    ]
    guard let url = comps.url else { return nil }

    let (data, _) = try await session.data(from: url)
    let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
    return decoded.results.first?.version
  }

  /// iTunes Lookup 응답(필요한 필드만).
  private struct LookupResponse: Decodable {
    let results: [Entry]
    struct Entry: Decodable { let version: String }
  }
}

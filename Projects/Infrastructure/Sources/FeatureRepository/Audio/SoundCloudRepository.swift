import Foundation

import Domain

/// SoundCloud oEmbed 검증(웹 `scOembed.ts` 이식) — 자격증명 불필요한 공개 엔드포인트.
///
/// ## 왜 필요한가
/// 위젯(player)은 아무 SC URL이나 열지 못한다:
///   - 모바일 공유 단축링크(`on.soundcloud.com/...`)는 위젯이 직접 해석 못 하는 경우가 있고,
///   - 비공개·임베드 금지 트랙은 로드 자체가 실패한다(→ 수신자는 CC0 폴백만 듣게 됨).
/// 그래서 **붙여넣는 시점**에 oEmbed로 (a) 임베드 가능 여부를 확정하고
/// (b) 위젯이 확실히 열 수 있는 canonical URL(`api.soundcloud.com/tracks/ID`)로 변환한다.
///
/// ## oEmbed 흐름
/// 1. `GET https://soundcloud.com/oembed?format=json&url=<붙인 URL>`
/// 2. 401/403 → 비공개/지역제한(SC는 둘 다 403이라 구분 불가), 404 등 → 없는 트랙.
/// 3. 200이면 JSON의 `html`(iframe 임베드 코드)에서 `src=".../player/?url=<canonical>"`을 추출.
///    `html`이 비어 있으면 작성자가 임베드를 막은 트랙.
public final class SoundCloudRepository: SoundCloudRepositorable {
  private static let endpoint = "https://soundcloud.com/oembed"
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func validate(url raw: String) async -> ScValidation {
    // 1) 형식 사전 검증 — soundcloud.com 계열 호스트만(스트림 rip/프록시 금지 전제).
    guard let host = URL(string: raw)?.host?.lowercased(),
          host == "soundcloud.com" || host.hasSuffix(".soundcloud.com") else {
      return .fail(.invalidUrl)
    }

    // 2) oEmbed 호출.
    var components = URLComponents(string: Self.endpoint)!
    components.queryItems = [
      URLQueryItem(name: "format", value: "json"),
      URLQueryItem(name: "url", value: raw),
    ]
    let data: Data
    let status: Int
    do {
      let (body, response) = try await session.data(from: components.url!)
      data = body
      status = (response as? HTTPURLResponse)?.statusCode ?? 0
    } catch {
      return .fail(.network)
    }

    // 3) 상태 코드 분류(웹과 동일).
    if status == 401 || status == 403 { return .fail(.privateTrack) }
    guard status == 200 else { return .fail(.notFound) }

    // 4) 임베드 html 확인 + canonical 추출.
    struct OembedResponse: Decodable {
      let title: String?
      let authorName: String?
      let html: String?
      enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case html
      }
    }
    guard let parsed = try? JSONDecoder().decode(OembedResponse.self, from: data) else {
      return .fail(.notFound)
    }
    guard let html = parsed.html, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return .fail(.embedDisabled)
    }

    // canonical = iframe src의 `url=` 쿼리 파라미터. 추출 실패 시 입력 URL로 폴백(웹 동일).
    let canonical = Self.extractCanonicalUrl(fromEmbedHTML: html) ?? raw
    return .ok(title: parsed.title ?? "", author: parsed.authorName ?? "", canonicalUrl: canonical)
  }

  /// `<iframe ... src="https://w.soundcloud.com/player/?url=<canonical>&...">`에서 url 파라미터 추출.
  static func extractCanonicalUrl(fromEmbedHTML html: String) -> String? {
    // src="..." 첫 매치를 찾아 HTML 엔티티(&amp;)를 되돌린 뒤 쿼리를 파싱한다.
    guard let range = html.range(of: #"src="([^"]+)""#, options: .regularExpression) else { return nil }
    let src = String(html[range]).dropFirst(5).dropLast(1).replacingOccurrences(of: "&amp;", with: "&")
    guard let components = URLComponents(string: String(src)) else { return nil }
    return components.queryItems?.first { $0.name == "url" }?.value
  }
}

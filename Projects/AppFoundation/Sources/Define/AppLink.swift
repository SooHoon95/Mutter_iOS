import Foundation

/// 전달/연결 링크 베이스 URL(Universal Link 도메인). 발급·초대 링크 생성에 사용한다.
/// 현재 배포 도메인 = Vercel(live). `mutter.app`은 미연결(HTTP 000)이라 링크가 죽어 있었음(MU-6).
/// 커스텀 도메인 확보 시 `productionBaseURL` 한 줄만 교체하면 초대·전달·UL 도메인이 함께 이동한다.
public enum AppLink {
  private static let productionBaseURL = "https://letter-app-nine-kohl.vercel.app"

  /// 개발 서버를 볼 때(Debug + `XCConfigs/DevServer.xcconfig`)는 그 파일의 `LINK_BASE_URL`(로컬 웹)을 쓴다.
  /// 설정이 없으면 Info.plist 값이 비어 운영 도메인으로 떨어진다.
  public static let baseURL: String = {
    guard let value = Bundle.main.object(forInfoDictionaryKey: "LINK_BASE_URL") as? String,
          !value.isEmpty else {
      return productionBaseURL
    }
    return value
  }()
}

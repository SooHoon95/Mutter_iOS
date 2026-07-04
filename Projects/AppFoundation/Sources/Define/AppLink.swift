import Foundation

/// 전달/연결 링크 베이스 URL(Universal Link 도메인). 발급·초대 링크 생성에 사용한다.
/// 현재 배포 도메인 = Vercel(live). `mutter.app`은 미연결(HTTP 000)이라 링크가 죽어 있었음(MU-6).
/// 커스텀 도메인 확보 시 이 한 줄만 교체하면 초대·전달·UL 도메인이 함께 이동한다.
public enum AppLink {
  public static let baseURL = "https://letter-app-nine-kohl.vercel.app"
}

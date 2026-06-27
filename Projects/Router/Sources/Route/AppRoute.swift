import Foundation

/// 루트 탭(MainTab). 각 탭이 자체 NavigationStack을 가진다.
public enum AppRoute: Hashable, CaseIterable {
  case home          // 우체통 — 보낸 편지 + 읽음상태
  case threads       // 주고받은 편지(상대별)
  case inbox         // 받은함
  case connections   // 연결(독점 1:1)
  case profile       // 프로필/설정
}

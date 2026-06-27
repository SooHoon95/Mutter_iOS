import Foundation

/// 스택에 push 가능한 화면 라우트 집합(Feature 간 공유 — Feature→Feature 의존 0).
public enum FeatureRoute: Hashable {
  case auth(AuthRoute)
  case compose(ComposeRoute)
  case viewer(ViewerRoute)
  case delivery(letterId: String)     // 발급/만료/revoke 관리
  case connect(ConnectRoute)
  case thread(counterpartId: String)  // 특정 상대와의 스레드
  case legal(LegalRoute)
}

/// 인증 플로우.
public enum AuthRoute: Hashable {
  case signIn
  case onboardNickname  // 가입 후 닉네임 온보딩
}

/// 제작 플로우.
public enum ComposeRoute: Hashable {
  case new
  case edit(letterId: String)         // 이어쓰기(기존 편지 재편집)
  case reply(recipientId: String)     // 답장(상대 preselect → send_to_connection 재사용)
}

/// 수신/열람 플로우.
public enum ViewerRoute: Hashable {
  case token(String, password: String?)  // 딥링크 수신(/l/:token)
  case myLetter(letterId: String)         // 내 편지 미리보기
}

/// 연결 초대 플로우(/connect/:token).
public enum ConnectRoute: Hashable {
  case invite(token: String)
}

/// 법적/정보 화면.
public enum LegalRoute: Hashable {
  case takedown
  case terms
  case privacy
}

import ProjectDescription
import ProjectDescriptionHelpers

// 모듈명 "Auth"는 supabase-swift의 Auth 모듈과 충돌하므로 "AuthFeature"로.
let project = Project.framework(
  name: "AuthFeature",
  platform: .iOS,
  dependencies: [
    .uiComponent,
    .router,
    .domain,
    // 소셜 로그인 SDK (Mercury Onboard 대응).
    .googleSignIn,
    .googleSignInSwift,
    .kakaoAuth,
    .kakaoUser
  ],
  testDependencies: []
)

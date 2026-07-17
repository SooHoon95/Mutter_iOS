# Mutter Android — 네이티브 파리티 설계

- 날짜: 2026-07-17
- 상태: 승인됨(설계) → 구현 플랜 대기
- 목표: 현재 네이티브 SwiftUI iOS `Mutter`와 **기능 동등한 안드로이드 앱**을 신규(그린필드) 개발. 백엔드(Supabase)·수신자 웹 경험은 그대로 재사용.

## 1. 대원칙 / 결정 사항

- **스택**: Kotlin + Jetpack Compose (네이티브). Compose only(UIKit/XML 지양 = iOS의 SwiftUI-only 철학 대응).
- **아키텍처**: Clean Architecture + Micro-Feature, **Gradle 멀티모듈**(Tuist 모듈러 1:1 대응).
- **비동기**: Coroutines + Flow (Combine + Swift Concurrency 대응).
- **DI**: **Hilt** (표준·컴파일 안전).
- **minSdk = 26 (Android 8.0)**, target/compile = 최신(35+).
- **디자인**: Pretendard 폰트 번들 + Material3 기반 커스텀 테마로 iOS 룩(웜 아이보리 + 골드 + 명조 감성) 재현.
- **applicationId**: `com.efreedom.mutter` (iOS 번들 ID와 동일).
- **백엔드**: 기존 Supabase 프로젝트 그대로(테이블 7 · RPC 17). 서버 변경 없음.
- **범위 밖(out of scope)**: 수신자 웹 랜딩/뷰어(무설치 웹 유지), 기존 iOS 앱 변경, 서버 RPC 신규.

## 2. 모듈 구조 (Gradle 멀티모듈)

- `:app` — 진입점(Application, MainActivity), 컴포지션 루트, Navigation host, Firebase/푸시 배선.
- `:core:designsystem` — 테마(Color/Type/Shape), Pretendard, 공통 컴포넌트(MutterButton/NavigationBar 등) = iOS `UIComponent` 대응.
- `:core:common` — 에러(`MutterError`), 세션, 공용 유틸, 설정(AppConfig) = iOS `AppFoundation` 대응.
- `:core:navigation` — type-safe route 정의(AppRoute/AuthRoute) + Coordinator 래퍼 = iOS `Router` 대응.
- `:core:network` — `SupabaseProvider`(supabase-kt 단일 진입점), 네트워크 로깅.
- `:domain` — Model, UseCase, Repository 인터페이스(플랫폼 비의존).
- `:data` — Repository 구현 + DTO↔Domain 매핑 + `SupabaseErrorMapper` = iOS `Infrastructure` 대응.
- `:feature:*` — 화면별 모듈(auth, compose, viewer, delivery, inbox, connections, threads, profile, home, legal, maintab).
- `build-logic` — convention plugins(공통 컴파일/Compose/Hilt 설정), `gradle/libs.versions.toml` 버전 카탈로그.

의존 방향: `app → feature:* → (domain, core:*)`, `data → (domain, core:network, core:common)`, `domain`은 다른 레이어에 비의존. UI 레이어는 `data` 세부구현을 직접 참조하지 않고 `domain` 인터페이스 + DI로 배선.

## 3. iOS → Android 매핑

| iOS | Android |
|---|---|
| SwiftUI View / `ModelData` | Compose / `ViewModel`(StateFlow 상태) |
| Combine + async/await | Coroutines + Flow |
| `MutterContainer`(서비스 로케이터) + 컴포지션 루트 생성자 주입 | Hilt(모듈/`@HiltViewModel`/`@Inject`) |
| `NavigationCoordinator` + `AppRoute`/`AuthRoute` | Navigation Compose(type-safe) + Coordinator 래퍼 |
| supabase-swift(auth/from/rpc/functions), Keychain 세션 | supabase-kt(Auth/Postgrest/Functions), 세션 = Encrypted DataStore |
| `MutterError` + `SupabaseErrorMapper`(코드 매핑) | sealed `MutterError` + 동일 코드 매핑(LINK_EXPIRED / INVITE_ALREADY_USED / TOKEN_NOT_FOUND / NOT_YET_REVEALED:<ISO> / WRONG_PASSWORD / LINK_REVOKED / NOT_CONNECTED …) |
| L10n(SwiftGen) 한/영 | `res/values-ko`, `res/values-en` `strings.xml`(동일 키 세트) |
| Asset(Colors/Images) | Compose Theme + drawable/vector, Pretendard `.ttf` |
| AVFoundation 음악 자동재생 | Media3(ExoPlayer) + 필요 시 WebView |
| WKWebView + JS bridge(뷰어/SoundCloud) | Android WebView + `@JavascriptInterface` |
| Firebase Messaging(APNs→FCM) | FCM(동일 Firebase 프로젝트 `mutter-1e8c3` + `google-services.json`) |
| Universal Links + 커스텀 스킴(`mutter://connect/<token>`) | App Links(intent-filter + `assetlinks.json`) + 커스텀 스킴 |
| Google Sign-In + Kakao SDK + 이메일 OTP | Google(Credential Manager) + Kakao SDK(Android) + 이메일 OTP |
| XCConfig Debug/Stage/Release + `Sensitive.xcconfig` | Gradle buildTypes/flavors + `BuildConfig`, secrets = `local.properties`(gitignore) |

## 4. 기능 파리티 (11)

각 기능은 `View(Compose) + ViewModel + (domain UseCase) + (data Repository)` 구성. iOS 화면과 1:1.

1. **Auth** — 이메일 OTP + Google + Kakao 로그인, 닉네임 온보딩.
2. **Compose** — 편지 에디터(테마 입힌 본문) + 음악 1곡 선택.
3. **Viewer** — 인앱 편지 뷰어 + 음악 자동재생 + 스크롤 연출(reveal).
4. **Delivery** — 전달 링크 발급/무효화, 예약공개(revealAt), 암호.
5. **Inbox** — 보관한 편지 목록.
6. **Connections** — 독점 1:1 연결 초대/수락/해제(+초대 딥링크 처리).
7. **Threads** — 상대별 주고받음 + 답장(Compose 재사용).
8. **Profile** — 닉네임 수정/로그아웃/계정 삭제.
9. **Home** — 통계 카드 + 최근 보낸 편지(읽음) + 임시저장.
10. **Legal** — 신고(takedown) + 약관 문서.
11. **MainTab** — 하단 탭(홈/주고받음/받은함/연결/프로필).

## 5. 구현 순서 (의존 기반 바텀업, iOS와 동일)

토대(모듈 스캐폴드 · Hilt · Navigation · DesignSystem · SupabaseProvider · 세션) → Auth → Compose → Viewer(+음악) → Delivery → Inbox → Connections → Threads → Profile → Home → Legal → MainTab.

## 6. 구성 / 시크릿 / 서명

- Supabase URL/anonKey, Google/Kakao 키, reversed client id 등 → `local.properties`(gitignore) → `BuildConfig`/manifest placeholder 주입(iOS의 xcconfig→Info.plist 대응).
- Firebase: 동일 프로젝트에 **안드로이드 앱 추가** 후 `google-services.json` 배치(gitignore).
- 서명: debug(자동) / release(keystore). 배포는 Play Console(별도 트랙) — 본 스펙 범위는 앱 개발까지.

## 7. 테스트 전략

- `:domain` UseCase 단위 테스트.
- `:data` Repository 계약 테스트(DTO 매핑 · 에러 매핑 포함).
- 핵심 플로우 Compose UI 테스트(로그인 → 작성 → 발급 → 뷰어).

## 8. 리스크 / 오픈 이슈

- (a) **SoundCloud 음악 재생** 방식 — iOS `SoundCloudRepository`/WKWebView 경로와 동일하게 맞출지, Media3 네이티브 스트리밍으로 갈지 구현 단계에서 확정.
- (b) **Kakao 로그인 안드로이드** 설정 — 네이티브 앱키 · 키해시 등록 필요.
- (c) **뷰어 스크롤 연출**(iOS `revealOnScroll`)의 Compose 재현.
- (d) **Firebase 안드로이드 앱 등록** 선행 필요.

## 9. 완료 기준(파리티)

iOS의 11개 기능이 안드로이드에서 동일 사용자 플로우로 동작하고, 동일 Supabase RPC 계약을 사용하며, 한/영 로컬라이징 · 웜 아이보리+골드+명조 룩이 재현되면 파리티 완료.

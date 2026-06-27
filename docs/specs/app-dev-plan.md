# Mutter iOS — 앱 개발 계획 (App Development Plan)

> 웹(letter-app, PRD v5)에서 가닥 잡힌 기능을 **iOS 네이티브로 풀 패리티 포팅**하는 로드맵.
> 설계 상세는 `module-architecture.md`(SSOT). 이 문서는 그 위에 **순서·마일스톤·수용기준·검증 게이트·리스크·실행 루프**를 입힌다.
> 결정(사용자): **① 범위 = 풀 기능 패리티** · **② 빌드 순서 = 기반 우선 바텀업**.

## 0. 전제 / 현재 상태
- **Phase 0 완료**: Tuist 스캐폴드(Mercury 1:1 복제) + 빈 19모듈 + 하네스(CLAUDE.md·스킬·커맨드, 이번에 Mutter 정합 정리 완료) + `tuist generate` 그린.
- **백엔드 재사용**: Supabase 그대로(supabase-swift). 테이블 7 · RPC 17 (`module-architecture.md` §5).
- **무설치 수신 웹뷰는 유지** — 앱은 발신/제작 + 인앱 뷰어를 더한다(수신자 무마찰 불변).
- **불변 원칙**: 무음 편지 0(SC 실패→CC0 폴백) · 수신자 무마찰 · 기본값 프라이버시.

## P0. 프리플라이트 게이트 (코딩 전 1회)
> 별도 스펙 `harness-gap-and-git-setup.md`로 Mutter 세션에서 ralplan→ralph 실행.
- [ ] `git init`+`Mutter_iOS` 원격 연결, 민감정보 분리(Sensitive.xcconfig*), 첫 커밋 비밀값 0.
- [ ] **웹 패리티 검증** — 웹의 실제 RPC/스키마 표면을 `module-architecture.md` §5와 대조. PRD v5 신규 기능(**읽음확인·예약공개·답장·이어쓰기**)이 엔티티·RPC·화면에 반영됐는지 확인하고, 누락 시 설계를 먼저 보강(아래 §리스크 R5).
- [ ] OAuth/서명 사전조건: Apple App ID(`com.efreedom.mutter`)·Google/Kakao 콘솔·Supabase allowed bundle id 갱신(번들ID 변경 반영).

## 1. 단계별 로드맵

각 단계 = **모듈/피처별 ralplan→ralph 사이클**(Mutter 세션). 공통 완료 게이트:
`tuist build` 0 에러 · `/arch-check` 위반 0 · 모듈 `tuist test`(Mapper/UseCase) · One-Type-Per-File.

### Phase 1 — 공통 기반 (바텀업)
순서: **AppFoundation → UIComponent → Domain → Network → Infrastructure → Router → AudioSync**. 모듈별 SampleApp+Tests.

| 모듈 | 핵심 산출물 | 수용기준(AC) |
|---|---|---|
| **AppFoundation** | `MutterContainer`(DI), `MutterError`+Define, `AppConfig`(Supabase URL/anonKey: xcconfig→Info.plist), `Deeplink`, Extensions, NetworkMonitor | DI register/resolve 동작 · `toMutterError()` 변환 · 비밀값 하드코딩 0 |
| **UIComponent** | 디자인 토큰(`MutterColor/MutterFont/MutterShadow`), 컴포넌트(`MutterButton/Alert/Toast/NavBar/Loading/EqualizerView`), `WKWebViewContainer`(JS 브리지), `LetterPaperView`(7 템플릿) | 토큰=웹 `tokens.css` 일치 · SampleApp에서 컴포넌트 렌더 · `LetterPaperView` 7테마 |
| **Domain** | 엔티티(Letter/MusicCue/Track/DeliveryLink/Profile/Connection/…), `<X>Usecasable`+`<X>Usecase`, `<X>Repositorable` 프로토콜 | 순수 Swift(UI 비의존) · UseCase는 Repository 프로토콜만 의존 |
| **Network** | `SupabaseProvider`(auth/from/rpc/functions, Keychain 세션, Pulse) | 환경별 URL/anonKey 주입 · 세션 Keychain 보관 |
| **Infrastructure** | Repository 구현 17 RPC 1:1, DTO+Mapper(`toDomain()`), `body↔paragraphs jsonb` 변환(웹 계약) | Mapper 단위테스트(DTO↔Domain·body↔paragraphs) · 호출은 Repo 구현체만 |
| **Router** | `NavigationCoordinator`, `<F>Route` enum, `<F>Viewable` 프로토콜, `ViewFactory`, Deeplink(`/l/:token`·`/connect/:token`) | Feature→Feature 의존 0 · 딥링크 파싱 |
| **AudioSync** | `TrackSource`(`HostedAudioSource`/`SoundCloudSource`/`FallbackTrackSource`), `LetterAudioPlayer`(1곡 자동재생/일시정지) | **무음0 폴백 동작** · ▶ 게이트 언락 · (SC 스파이크는 Phase 2 Viewer) |

### Phase 2 — Feature (풀 패리티)
순서: **Auth → Compose → Viewer → Delivery → Inbox → Connections → Threads → Profile → Home → Legal → MainTab**.
구조: `public/{View,ViewFactory}` · `internal/{SubViews,ModelData}`. ModelData=`@MainActor @Observable`, `@Inject usecase`.

- **Auth**: 이메일 코드/비번 + **Apple · Google · Kakao** 로그인. (OAuth 콘솔 사전 등록 필요)
- **Compose**(+Audio): `LetterPaperView` WYSIWYG + 템플릿 픽커 + 음악 1곡(SC paste/CC0 무드) + 저장/보내기 + **이어쓰기(임시저장)**.
- **Viewer**(+Audio): 딥링크/내편지 인앱 열람 + "편지 열기 ▶" 게이트 + `LetterAudioPlayer` + **읽음확인 마킹**. ⚠ **SC WKWebView 재생 디바이스 스파이크 = 이 단계의 하드 게이트(R1)**.
- **Delivery**: 링크 발급(암호 기본 ON)·만료·revoke + **예약공개(날짜 게이트)**.
- **Inbox**: 받은편지 보관·다시보기(보낸이 표시).
- **Connections**: 1:1 연결 초대·수락(독점)·직접 발송·해제.
- **Threads**: 상대별 주고받은 편지 + **답장**.
- **Profile**: 닉네임·로그아웃·계정 삭제(연쇄).
- **Home**: 우체통(보낸 편지 비주얼)+바로가기. **Legal**: 약관·takedown. **MainTab**: 루트 탭.

게이트(피처별): 해피+불행 경로 동작 · `/arch-check` 0 · 실기기 1회 스모크.

### Phase 3 — App 통합 (합성 루트)
- `MutterApp`: 전 Repository/UseCase/SupabaseProvider DI 등록 + ViewFactory 배선.
- `AppDelegate`: Firebase(Push/Crashlytics) · APNs · `AVAudioSession`(백그라운드·잠금화면 오디오) · Universal Link 라우팅.
- 엔타이틀먼트: Sign in with Apple · Push · Associated Domains.
- 게이트: 콜드 실행 → 딥링크 열람 → 음악 재생 → 백그라운드 지속 e2e.

### Phase 4 — 출시 준비
- 서명/프로비저닝(`com.efreedom.mutter`), Stage/Release xcconfig, 스크린샷/메타.
- **TestFlight** 내부 테스트 → 피드백 → App Store 심사. (Android·푸시 고도화는 비목표/후속)

## 2. 교차 리스크 & 게이트
| ID | 리스크 | 대응(게이트) |
|---|---|---|
| **R1** | SC WKWebView 인앱 오디오 재생(최대 리스크) | Phase 2 Viewer 진입 시 **디바이스 스파이크 go/no-go**. 실패 시 CC0-only로 강등(무음0 유지) 또는 SC 전략 재검토 |
| R2 | iOS 백그라운드·잠금화면 오디오 | `AVAudioSession(.playback)`+`MPNowPlayingInfoCenter` Phase 3 e2e |
| R3 | OAuth(Apple/Google/Kakao) 무계정 수신 불간섭 | 콘솔 사전 등록 + Auth 단계 실기기 |
| R4 | 번들ID 변경 파급(서명·OAuth allowed id) | P0 프리플라이트에서 처리 |
| **R5** | **웹↔설계 패리티 갭**(읽음확인·예약공개·답장·이어쓰기 RPC/스키마 미반영 가능) | **P0 패리티 검증**에서 대조→설계 보강 후 Phase 2 진입 |
| R6 | 무음 편지 0 | `FallbackTrackSource` Phase 1 AudioSync AC |

## 3. 실행 모델
- **단위**: 모듈/피처 1개 = ralplan(합의 계획) → ralph(AC 검증 실행) 1사이클. Mutter 디렉터리 세션에서.
- **검증**: 단계마다 `tuist build`/`test` + `/arch-check` + (오디오·딥링크는) 실기기. 자가 승인 금지 — 커밋 전 `code-reviewer`/`critic` 독립 패스(Codex 미사용).
- **추적**: `tasks/todo.md`(현재 단계 체크리스트) + `tasks/lessons.md`(교정 누적).
- **순서 요약**: P0 프리플라이트 → Phase1(7모듈) → Phase2(11피처) → Phase3(앱) → Phase4(출시).

## 4. 다음 액션
1. (Mutter 세션) `harness-gap-and-git-setup.md` ralplan→ralph = **P0 프리플라이트**(git·secrets·패리티검증).
2. 이어서 **Phase 1 AppFoundation**부터 ralplan→ralph.

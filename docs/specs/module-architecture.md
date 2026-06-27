# Mutter — 모듈 상세설계 (Module Architecture)

> 승인된 모듈 분할(`module split`)의 구현 레벨 상세. Tuist 스캐폴드는 Mercury 1:1 복제,
> 백엔드는 Supabase 그대로 재사용(supabase-swift). 편지 = 테마 본문 1장 + 음악 1곡.

## 의존성 그래프 (확정)
```
AppFoundation ─┬─ UIComponent ─┐
               ├─ Domain ───────┼─ AudioSync
               ├─ Networking    │
               └─ Router        │
Domain + Networking + AppFoundation ─ Infrastructure
Feature/* : UIComponent + Router + Domain (+ AudioSync: Compose·Viewer)
MutterApp : 전체(합성 루트)
```
금지: Feature→Feature, Domain→(Infrastructure/Networking). 모듈당 3타깃(Source/SampleApp/Tests).

---

## 1. AppFoundation (deps: 없음)
- **DI** `MutterContainer`(=Mercury MercuryContainer 복제): `register<T>(_:instance:)`, `resolve<T>()`. 프로퍼티래퍼 `@Inject` / `@LazyInject`.
- **MutterError**: Supabase/네트워크 에러 → 사용자 메시지(한국어) 정규화. 케이스: `network`, `unauthorized`, `notFound`, `rateLimited`, `wrongPassword`, `linkRevoked`, `linkExpired`, `server(String)`, `unknown`.
- **Define**: `UserDefaultsKey`(세션·온보딩), `AppConfig`(Supabase URL/anonKey — xcconfig→Info.plist 주입), `Deeplink`(host/path).
- **ViewModifiers**: `ViewDidLoadModifier` 등. **Extension/**: Date/String/Color(hex) 등.
- **NetworkMonitor**: 연결 상태.

## 2. UIComponent (deps: AppFoundation)
- **DesignSystem**: 웹 `tokens.css` 이식 → `MutterColor`(warm ivory/ink/gold/gold-deep/gold-soft), `MutterFont`(Nanum Myeongjo 디스플레이 + 본문 sans), `MutterShadow`. 7 템플릿 테마값(`LetterTheme`: bg/fg/accent/font/lineHeight/paperTexture).
- **컴포넌트**: `MutterButton`(골드 CTA), `MutterAlert`, `MutterToast`, `MutterNavigationBar`, `CachedAsyncImage`, `MutterLoading`, `EqualizerView`(재생 표시).
- **`WKWebViewContainer`**: WKWebView 래퍼 — SoundCloud Widget 호스팅(+JS 브리지). AudioSync가 사용.
- **`LetterPaperView`**: `LetterTheme` 적용된 "편지지"(제목+본문 렌더). Compose 편집/Viewer 열람 공용. 7 템플릿.

## 3. Domain (deps: AppFoundation · 순수 Swift)
패턴: `Usecase/<영역>/`에 `<X>Usecasable`(프로토콜) + `<X>Usecase`(구현, Repository 프로토콜 조합) + `<X>Repositorable`(프로토콜) + `Model/`.

### 엔티티
```swift
struct Letter { let id: String; var title: String; var body: String; var templateId: String; var cue: MusicCue? }   // body=본문 1장, cue=음악 1곡
struct MusicCue { enum Source { case soundcloud, hosted }; let source: Source; let ref: String; let startMs: Int? }
struct Track { let id, title, author: String; let license: String; let url: String; let mood: String }              // CC0 카탈로그
struct DeliveryLink { let token: String; let letterId: String; let hasPassword: Bool; let expiresAt: Date?; let revoked: Bool }
struct LetterPayload { let id, title, body, templateId: String; let cue: MusicCue?; let audioDisabled: Bool }          // 수신 페이로드
struct Profile { let id: String; var nickname: String? }
struct Connection { let userId: String; let nickname: String?; let connectedAt: Date }
struct ConnectInvite { let inviterId: String; let inviterNickname: String?; let isSelf, alreadyConnected, viewerHasConnection, inviterHasConnection: Bool }
struct InboxItem { let letterId, token, title: String; let savedAt: Date }
struct Counterpart { let userId: String; let nickname: String?; let exchangeCount: Int }
struct ThreadLetter { let letterId: String; let direction: Direction; let token: String?; let title: String; let sentAt: Date }  // Direction: sent/received
```

### Usecasable (핵심 메서드 — async throws)
| 영역 | 프로토콜 메서드 |
|------|------|
| Auth | `requestCode(email)` · `verifyCode(email, code)` · `signIn(email, password)` · `signInApple(idToken, nonce)` · `signInSocial(provider, token)` · `signOut()` · `currentSession() -> Session?` |
| Profile | `myProfile() -> Profile?` · `updateNickname(_)` · `deleteAccount()` |
| Letter | `create(draft) -> Letter` · `update(id, draft)` · `letter(id) -> Letter?` · `myLetters() -> [Letter]` · `delete(id)` · `ensureCue(_) -> MusicCue`(무음0: 미선택 시 기본 CC0) |
| Catalog | `all() -> [Track]` · `track(id) -> Track?` · `byMood(_) -> [Track]` |
| Delivery | `issue(letterId, password?) -> DeliveryLink` · `revoke(token)` · `links(letterId) -> [DeliveryLink]` · `open(token, password?) -> LetterPayload` |
| Inbox | `save(token)` · `myInbox() -> [InboxItem]` |
| Connection | `createInvite(token) -> String` · `invite(token) -> ConnectInvite` · `accept(token)` · `myConnections() -> [Connection]` · `disconnect()` · `send(letterId, recipientId, token)` |
| Thread | `counterparts() -> [Counterpart]` · `thread(counterpartId) -> [ThreadLetter]` · `sentWithRecipients() -> [...]` |
| Takedown | `report(letterId?, trackRef?, claimant, contact, reason)` |
| Audio | `defaultCue() -> MusicCue`(첫 CC0) · `resolvePlayback(cue) -> TrackSourceSpec`(hosted→url, soundcloud→widget) |

`Repositorable`: 각 Usecase가 의존하는 데이터 접근 프로토콜(구현은 Infrastructure). `Protocol/`: `SessionProvidable`, `DeeplinkHandlable`, `PushTokenRegisterable`.

## 4. Networking (target명 `Networking`, deps: AppFoundation)
- **`SupabaseProvider`**(싱글톤/주입): supabase-swift `SupabaseClient`(url, anonKey). `auth`, `from(table)`, `rpc(fn, params)`, `functions` 노출. 세션 보관(Keychain).
- Pulse 로깅 연동.

## 5. Infrastructure (deps: AppFoundation, Domain, Networking)
- `FeatureRepository/<영역>/`: Domain `<X>Repositorable` **구현**. `Model/`에 DTO(Codable) + `Mapper`(DTO↔Domain).
- **RPC 17개 매핑**(메서드 1:1): `get_letter_by_token`(2-arg)→open · `issue_link`·`revoke_link`·`list`(delivery_links select) · `save_to_inbox`·`get_my_inbox` · `get_my_sent_with_recipients`·`get_counterparts`·`get_thread` · `create/get/accept_connect_invite`·`get_my_connections`·`send_to_connection`·`disconnect_connection` · `report_takedown` · `delete_my_account`. 테이블 직접: `profiles`(upsert), `letters`(CRUD).
- **`paragraphs jsonb`↔`body` 변환**: 저장 시 body를 빈 줄 split → paragraphs[], cue는 paragraphs[0].cue. 로드 시 역변환. (웹과 동일 계약)
- `Service/`: `PushTokenService`(FCM 토큰 등록 → `push_tokens` 테이블). `UserDefaults/`: 로컬 캐시.

## 6. Router (deps: AppFoundation)
- **`NavigationCoordinator<Route: Hashable>`**(Mercury 복제): push/pop/popToRoot/presentFullScreen.
- **`Route/<F>Route`**: `AppRoute`(루트 탭) · `ComposeRoute` · `ViewerRoute` · `ConnectRoute` 등 enum.
- **`ViewProtocol/<F>Viewable`**: `AuthViewable`, `ComposeViewable`, `ViewerViewable`… (각 Feature View가 채택). Router는 이 프로토콜로 화면 생성 → **Feature→Feature 의존 0**.
- **`ViewFactory`**: Viewable 구현 보관. App 합성 루트가 주입.
- **Deeplink**: `/l/:token`→ViewerRoute, `/connect/:token`→ConnectRoute 파싱.

## 7. AudioSync (deps: Domain, UIComponent) — 제품 핵심
```swift
protocol TrackSource { func load() async throws; func play(); func pause(); func seek(toMs:); func setVolume(_:); var onFinish: (() -> Void)? }
final class HostedAudioSource: TrackSource   // AVPlayer + AVAudioSession(.playback) + MPNowPlayingInfoCenter/MPRemoteCommandCenter (잠금화면·백그라운드)
final class SoundCloudSource: TrackSource    // UIComponent WKWebView + SC Widget API(JS 브리지). ← 최대 리스크: 출시 전 디바이스 스파이크
final class FallbackTrackSource: TrackSource // 1차 실패 → CC0 폴백(무음 편지 0)
@MainActor final class LetterAudioPlayer: ObservableObject  // 편지 1곡 자동재생/일시정지. 게이트 언락 시 시작, 끝까지(스크롤 동기 없음). @Published isPlaying
```
Compose(미리듣기)·Viewer(수신 재생)가 `LetterAudioPlayer` 공유.

## 8. Feature 모듈 (각 deps: UIComponent·Router·Domain[, +AudioSync])
구조: `public/{<F>View, <F>ViewFactory}` · `internal/{SubViews, ModelData}`. ModelData = `@MainActor ObservableObject`, `@Inject var usecase: <X>Usecasable`.
- **Auth**: 코드/비번/소셜/Apple 로그인. `AuthModelData`.
- **Compose**(+Audio): `LetterPaperView` 위 WYSIWYG 편집 + 템플릿 픽커 + 음악 1곡 선택 + 저장/보내기. `ComposeModelData`.
- **Viewer**(+Audio): 딥링크/내편지 네이티브 열람 + 열기 게이트 + `LetterAudioPlayer`. `ViewerModelData`.
- **Delivery/Inbox/Connections/Threads/Profile/Home/Legal**: 웹 대응 화면 1:1.
- **Home**: 우체통(보낸 편지 수 비주얼) + 바로가기. **MainTab**: 루트 탭(ViewFactory로 각 탭 구성).

## 9. MutterApp (합성 루트)
- **DI 등록**: 모든 Repository 구현·UseCase·SupabaseProvider를 `MutterContainer`에 register.
- **ViewFactory 배선**: 각 Feature의 Viewable 구현 등록.
- **AppDelegate**: Firebase(Core/Messaging/Crashlytics/Analytics) init, APNs 등록, `AVAudioSession` 설정, Universal Link/Deeplink 라우팅.
- **엔타이틀먼트**: Sign in with Apple, Push, Associated Domains(Universal Links).

---

## 빌드 순서 / 검증
1. **Phase 0**(현재): Tuist 스캐폴드(Mercury 복제) + 빈 19모듈 → `tuist generate` 그린.
2. **Phase 1**(공통): AppFoundation→UIComponent→Domain→Networking→Infrastructure→Router→AudioSync. 모듈별 SampleApp+Tests.
3. **Phase 2**(Feature): Auth→Compose→Viewer(+SC WKWebView 스파이크)→Delivery→Inbox→Connections→Threads→Profile→Home→Legal→MainTab.
4. **Phase 3**(App): 합성 루트·푸시·Apple 로그인·Universal Links·백그라운드 오디오.

검증: 단계마다 `tuist build` 0 에러 · `/arch-check` 위반 0 · 모듈 `tuist test` · Infra Mapper(DTO↔Domain·body↔paragraphs) 단위테스트 · **SC WKWebView 재생 디바이스 스파이크**.

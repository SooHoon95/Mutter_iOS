# PLAN v3 — 링크 앱 핸드오프 (연결 `/connect/` + 편지 `/l/`) · 4케이스 커버

> 모드: **deliberate**. 합의: Planner→Architect→Critic. v3 = Architect(5델타)+Critic(ITERATE 1블로킹+비블로킹) 반영.
> 저장소 2곳: 앱 `Mutter`(iOS), 웹 `letter-app`(Vite/React/Vercel).

## 문제 / 목표
초대·편지 링크가 폰에서도 웹으로만 열려 웹 로그인을 강제(특히 카톡 인앱 브라우저). 목표: **여는 맥락(4케이스)별 분기** — 폰+앱이면 앱, 아니면 웹. 데스크톱은 웹 그대로.

### 4케이스 × 링크 종류
| # | 맥락 | `/connect/` (로그인 필수) | `/l/` (무설치 열람이 제품 핵심) |
|---|---|---|---|
| ① | PC 데스크톱 웹 | 웹 로그인→수락 (기존) | 웹 뷰어 즉시 (기존) |
| ② | 폰 Safari/메시지 직접탭 + 앱 | **UL 네이티브 앱** | UL 앱 뷰어 |
| ③ | 폰 Safari + 앱 없음 | **웹 보호 플로우**(스킴 발화 안 함) | 웹 뷰어 즉시(설치벽 금지) |
| ④ | 폰 인앱브라우저(카톡) + 앱 | **커스텀 스킴 앱**, 없으면 폴백 | 웹 뷰어 + 비차단 "앱에서 열기" |

## 원칙
- **P1 무설치 웹 유지** — 편지(`/l/`)는 앱 없이 즉시 웹 열람. 편지엔 강제 인터스티셜 금지, 웹 우선.
- **P2 어디서든 동작 > 이상적 UX만** — 스킴이 하한선(webview), UL은 향상(Safari/메시지).
- **P3 Root-cause / Minimal Impact** — 여는 시점 분기. 보내는 쪽 최소 변경.
- **P4 데드엔드/퇴행/팝업 금지** — 모든 분기 동작 폴백. 앱 미출시 기간엔 인터스티셜 OFF(지연 0). **Safari엔 스킴 미발화**(시스템 팝업 회피).
- **P5 기존 흐름 재사용** — 앱 `pendingConnectToken`/`pendingLetter`, 웹 기존 `Connect`/`RequireAuth`, lazy 라우팅 유지.

## 결정 동인 (top 3)
- **D1** 카톡 인앱브라우저 다수 → UL 불충분, **스킴은 webview 전용**.
- **D2** 앱 **미출시** → 폴백 죽으면 안 됨 + 전환기 지연 순손해 → **`HANDOFF_ENABLED` 플래그로 dark-ship**.
- **D3** 편지 무설치 열람이 제품 핵심 → 편지는 웹 우선(연결과 다르게).

## 옵션
- **Opt A (채택, v3)**: 스킴 핸드오프 인터스티셜(connect, **플래그+webview 게이팅**) + 웹우선 배너(letter) + 앱 `Deeplink` 스킴 파싱 + UL 포털 + (요청)공유 시트.
- **Opt E (Architect 반론)**: 보호 유지 + 로그인된 Connect 안 "앱에서 열기" 버튼만. → **통찰 흡수**: 플래그 OFF 또는 비-webview일 때 Opt A가 정확히 오늘 동작으로 축퇴 → Opt E "지연 0" 이점 자동 확보.
- **Opt B** UL만→카톡 실패. **Opt C** Edge→설치판별 불가. **Opt D** Smart Banner→webview 미표시(향후 가산).

## 설계 (What we build)

### A. 웹 (letter-app)
1. **`src/lib/device.ts`** — `isIOS()`, `isAndroid()`, `isMobile()`, `isInAppBrowser()`(카톡/인스타/페북/라인 UA), `isStandalonePWA()`. **기존 `Connect.tsx`의 `isIOSDevice()` 이관·통합**.
2. **`src/lib/appLinks.ts`** — `APP_SCHEME='mutter'`, 스킴 빌더(`mutter://connect/<t>`,`mutter://l/<t>`), `APP_STORE_URL = import.meta.env.VITE_IOS_APP_STORE_URL ?? null`(**기존 env 재사용**), `HANDOFF_ENABLED = !!APP_STORE_URL || import.meta.env.VITE_ENABLE_HANDOFF === 'true'`.
3. **`/connect/:token` — `ConnectHandoff` 래퍼(별도 라우트 X)**:
   - `router.tsx:71`을 `withProtectedCreatorShell(<Connect/>)` → `withSuspense(<ConnectHandoff/>)`로 교체(**ConnectHandoff도 lazy** — 코드 스플리팅 유지). AASA/서브경로 변경 없음.
   - 분기 (**Critic 블로킹 반영 — Safari엔 스킴 미발화**):
     - `isIOS() && HANDOFF_ENABLED && isInAppBrowser()` → **인터스티셜**(§A4). ← 카톡 등 webview 전용(④).
     - 그 외(데스크톱 / Android / **iOS Safari** / 플래그OFF) → **기존 `withProtectedCreatorShell(<Connect/>)` 그대로 미러**(이미 AppShell+RequireAuth 가드됨 — 재래핑 불필요, teammate 확인). (**오늘과 100% 동일, 지연·팝업 0**). 근거: Safari는 앱 있으면 UL이 가로챔(②), 없으면 웹(③) — 스킴 자동발화는 "페이지 열 수 없음" 팝업만 유발.
   - **기존 `Connect.tsx`의 `AppInstallBanner`(line 34/84)·`IOS_APP_STORE_URL`(line 25)·`isIOSDevice`(line 28) 제거** — 현재도 스토어링크 no-op(env 미설정). iOS 렌더는 `ConnectHandoff` 단독 소유(이중 배너 방지).
   - **⚠ 단일 소비자 불변(teammate CLAIM 3)**: 토큰은 **엄격 단일사용·단일소비자**(0027 `accept_connect_invite`·0022 `get_connect_invite` 둘 다 수락 후 `INVITE_ALREADY_USED`). → 인터스티셜/배너는 **`acceptInvite`를 절대 호출 안 함**, 토큰을 앱에 넘기기만(앱이 수락). 수락은 **앱 또는 "웹에서 계속" 중 한 곳만**. `getInvite`(초대자 이름 읽기)는 수락 전이라 안전.
   - **"앱에서 이미 수락" 처리**: 앱 수락 후 웹 복귀 시 `getInvite`가 `INVITE_ALREADY_USED`를 던짐(읽기도 잠김) → 에러 아닌 "이미 수락됨" 성공-등가로 표시(`connections.ts` getInvite 정규화 또는 ConnectHandoff 처리).
4. **인터스티셜 상태머신 — 타임아웃 주도(Architect Risk A/Delta 2)**:
   ```
   mount → 스킴 fire(invisible iframe src="mutter://connect/<t>"; Safari 팝업 억제·webview 호환) → 1400ms 타이머
     visibilitychange(hidden) 먼저 → clearTimeout, "앱에서 열렸어요"        (성공 스킵 최적화, 신뢰 안 함)
     타이머 만료 → 폴백 UI 확정                                            (모든 webview 보장 착지점)
   폴백: 주요 "웹에서 계속"(→ RequireAuth+Connect) + "앱으로 열기"(user-gesture 재시도) + "앱 설치"(APP_STORE_URL 있을 때만)
   ```
5. **`/l/:token` — 웹우선 + 비차단 배너**: 항상 웹 뷰어 즉시 렌더(P1). `isIOS() && isInAppBrowser()` → 상단 비차단 배너 "앱에서 열기"(탭 시 **웹 오디오 일시정지 후** `mutter://l/<t>` 발화 — 백그라운드 재생 글리치 방지). Safari 직접탭+UL은 웹 안 거치고 앱(②).

### B. 앱 (Mutter)
1. **`Deeplink.init?(url:)` 스킴 화이트리스트(Architect Delta 5)** (`AppFoundation/Sources/Define/Deeplink.swift`):
   ```
   scheme = url.scheme?.lowercased()
   if "mutter" && host non-empty → keyword=host, token=첫 path
   else if "https"/"http"        → keyword=path[0], token=path[1]   (기존)
   else                           → nil            (ftp:// 등 차단)
   switch keyword { "l"→.letter, "connect"→.connect, else nil }; token guard
   ```
2. `MainView.onOpenURL` 그대로 — 스킴 URL이 `.connect`/`.letter`로 파싱. 로그인 필요 시 `pendingConnectToken` 재사용. (`MutterApp.swift:27` OAuth 핸들러도 `mutter://`엔 false, 안전 — Architect Risk E 확인.)
3. **(요청) 네이티브 공유 시트** `ConnectionsView`: 클립보드 복사 → `ShareLink(item:)`. *독립 서브태스크*(핸드오프와 분리).
4. **entitlement**: `?mode=developer` 개발 유지, App Store 빌드 시 제거 — 배포 체크리스트.

### C. 포털 / 배포 (사용자 작업)
- Apple Developer → App ID `com.efreedom.mutter` → **Associated Domains ON** → 프로비저닝 갱신 → **앱 재설치**(② 직접탭 네이티브).
- **AASA `/connect/*` 커버 — 이미 확인됨**(curl: origin+Apple CDN 200, components에 `/l/*`·`/connect/*` 포함).
- 테스트 즉시검증: 프리뷰 배포에 `VITE_ENABLE_HANDOFF=true` → 사용자 dev 빌드로 ④ 스킴 경로 지금 검증.

## Pre-mortem (3 시나리오) + 검증된 비이슈
1. **WKWebView visibility 미발화 고착** → **타임아웃 주도 상태머신**(§A4), 카톡 실기기 테스트.
2. **전환기(미출시) UX 퇴행** → **`HANDOFF_ENABLED` 플래그** OFF로 오늘 동작.
3. **Safari 스킴 팝업 / App Store 데드 / Deeplink 회귀** → Safari엔 **스킴 미발화**(§A3), `APP_STORE_URL=null`→설치버튼 숨김, Deeplink **스킴 화이트리스트+유닛테스트**.
- **검증된 비이슈**(Critic): 토큰 이중소비 없음(DB 멱등 0027/0022, 웹 에러 정규화), onOpenURL 이중 디스패치 안전.

## 확장 테스트 플랜
- **Unit(앱)**: Deeplink — {https, mutter://, ftp://(→nil)} × {connect, l} × {정상, 토큰없음}.
- **Unit(웹)**: device.ts UA(iOS Safari/카톡/인스타/Android/데스크톱), appLinks 빌더, 상태머신(**타임아웃=주경로**), `HANDOFF_ENABLED` OFF→오늘 동작, Safari→인터스티셜 미진입.
- **Integration(웹)**: `/connect/` 분기(데스크톱·Safari·플래그OFF→보호Connect, iOS+webview+ON→인터스티셜), `/l/` 웹우선+배너.
- **E2E/수동(실기기 iPhone)**: 4케이스 × {connect, letter} — Safari 직접탭(UL), **Safari+앱없음+플래그ON(팝업 없어야)**, 카톡 webview(스킴), 앱 유/무, **앱수락→웹폴백 복귀(이미수락 표시)**, 데스크톱, 플래그 ON/OFF.
- **관측성**: 시도/성공/타임아웃/폴백 이벤트 로깅(Firebase Analytics).

## 수용 기준 (AC)
- **AC1** 데스크톱 `/connect/` → 기존 웹 로그인+수락(불변).
- **AC2** iPhone Safari 탭 `/connect/` + 앱 + UL → 앱 초대수락, 웹 플래시 없음.
- **AC3** iPhone **카톡 webview** `/connect/` + 앱 + 플래그ON → 스킴 즉시 발화·앱 오픈. (1.4s는 실패 임계 = 미발화 판정, 성공 임계 아님.)
- **AC4** iPhone webview `/connect/` + 앱 없음 → 타임아웃 후 폴백 "웹에서 계속" 동작(스토어 버튼은 설정 시).
- **AC5** `/l/` iPhone 앱 없음 → 웹 뷰어 즉시(설치벽 없음). 앱 있으면 UL 앱 뷰어 또는 비차단 배너(webview).
- **AC6** 앱 `mutter://connect|l/<t>` 파싱 정확, `ftp://`·OAuth 무영향.
- **AC7** `HANDOFF_ENABLED=false` 또는 **iOS Safari** → `/connect/`가 오늘과 동일(지연·팝업 0, 퇴행 없음).
- **AC8** 앱에서 수락 후 웹 폴백 복귀 → "이미 수락됨" 표시(raw 에러 X), 토큰 재소비 없음.
- **AC9** 앱 `ConnectionsView` 네이티브 공유 시트.
- **AC10** 앱 `tuist build` 성공, 웹 typecheck+테스트 통과.

## 실행 순서
1. 앱 `Deeplink` 스킴 화이트리스트 + 유닛테스트 → `tuist build`. (B1,B2)
2. 웹 `device.ts`/`appLinks.ts`/`ConnectHandoff`(lazy 래퍼+타임아웃주도+iframe+webview게이팅) + `Connect.tsx` iOS코드 통합/제거 + getInvite 정규화 + `/l/` 배너(오디오정지) + 테스트 → typecheck+test. (A)
3. 앱 공유 시트(독립). (B3)
4. 배포 체크리스트: 웹 배포(플래그 기본 OFF), 포털 UL(C), 출시 시 플래그·`VITE_IOS_APP_STORE_URL`·entitlement dev접미사, 실기기 검증.

## ADR
- **Decision**: Opt A(v3) — 스킴 핸드오프(플래그+webview 게이팅) + 웹우선 편지 + UL 병행 + 공유 시트.
- **Drivers**: D1 카톡 webview, D2 미출시 폴백/전환기, D3 편지 무설치.
- **Alternatives**: E(인페이지 버튼)→통찰 흡수(축퇴), B/C/D 기각(D 향후).
- **Consequences**: 웹 `/connect/`에 lazy 래퍼 1개(라우트/AASA 불변), 앱 Deeplink 스킴 파싱, 전환기 dark-ship, 실기기 검증 의존.
- **Follow-ups**: 출시 시 플래그·스토어URL·entitlement dev접미사, Smart App Banner 가산.

---
## 합의 상태
- **Architect**: 아키텍처 승인, 5개 synthesis 델타 전부 반영.
- **Critic**: v2에 ITERATE(블로킹 1 = Safari 스킴 미발화) → **v3에서 수정 완료** + 비블로킹(iframe·이미수락·lazy·오디오정지·AC명료화) 반영. 토큰 이중소비 등은 비이슈로 검증됨.

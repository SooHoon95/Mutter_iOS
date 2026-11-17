# GA4 분석 — 3플랫폼 계약 (2026-11-16)

iOS·Android·웹이 같은 GA4 속성(Firebase 프로젝트 `mutter-1e8c3`에 연결된 속성)에 같은 이름으로 이벤트를 보낸다.
앱은 Firebase Analytics SDK(앱용 GA4), 웹은 gtag.js.

## 원칙

- **개인정보를 보내지 않는다.** 이메일·닉네임·편지 본문·제목·링크 토큰·사용자 ID(`setUserId`)를 보내지 않는다. 파라미터는 아래 표의 값만 쓴다.
- **광고 신호를 끈다.** 광고 개인화 신호는 기본으로 끈다. Android는 광고 ID 수집과 `AD_ID` 권한을 뺀다. iOS는 AdSupport를 링크하지 않는다(IDFA 없음, ATT 프롬프트 없음).
- **화면 이름은 직접 보낸다.** SDK 자동 화면 기록을 끄고 아래 화면 이름으로 `screen_view`를 보낸다. SwiftUI·Compose 자동 기록은 호스팅 컨트롤러·액티비티 이름만 남아 쓸모가 없다.
- **분석이 실패해도 앱은 그대로 동작한다.** 기록은 fire-and-forget이고, 연결 전(샘플 앱·테스트)에는 no-op이다.

## 화면 이름 (`screen_view.screen_name`)

| 이름 | 화면 |
|---|---|
| `sign_in` | 로그인(비밀번호·코드·회원가입 단계 포함) |
| `onboard_nickname` | 가입 후 닉네임 |
| `home` · `inbox` · `threads` · `connections` · `profile` | 탭 |
| `compose` | 편지 작성(새 편지·이어쓰기·답장) |
| `viewer` | 편지 보기(링크로 받은 편지·내 편지 미리보기) |
| `delivery` | 링크 관리 |
| `connect_invite` | 연결 초대 수락 |
| `trash` · `inbox_trash` | 보낸·받은 편지 삭제함 |
| `tickets` | 편지권 |
| `ticket_checkout` | 결제 안내 시트 |
| `legal_terms` · `legal_privacy` · `legal_takedown` | 약관·처리방침·저작권 신고 |

웹은 GA4 향상된 측정(브라우저 기록 기반 페이지 변경)이 `page_view`를 보낸다. 화면 이름 대신 경로를 쓴다.

## 이벤트

| 이벤트 | 파라미터 | 언제 |
|---|---|---|
| `login` | `method`: `password` · `code` · `apple` · `google` · `kakao` | 로그인 성공(가입 포함) |
| `sign_up` | `method`: `email` (이메일 회원가입일 때만) | 이메일 회원가입 코드 인증 성공 |
| `onboard_complete` | — | 가입 후 닉네임 저장 성공(가입 방법 무관한 가입 완료 지점) |
| `letter_create` | `reply`: `true`/`false` | 새 편지 첫 저장 성공(이후 저장은 갱신이라 안 보냄) |
| `link_issue` | `permanent`, `has_password` (bool) | 전달 링크 발급 성공(작성 시트·링크 관리 둘 다) |
| `letter_send` | `permanent` (bool), `reply` (bool) | 연결 상대에게 직접 발송 성공 |
| `letter_open` | `source`: `link` · `my_letter` | 봉투에서 "편지 열기"를 눌러 본문이 열린 순간(화면당 1회) |
| `letter_keep` | — | 받은 사람이 편지권으로 간직 성공 |
| `letter_make_permanent` | — | 보낸 편지를 나중에 영구로 만들기 성공 |
| `ticket_purchase` | `product_id` | 편지권 구매 성공(서버 반영까지 끝난 뒤) |
| `invite_create` | — | 연결 초대 링크 만들기 성공 |

알려진 한계(두 앱 공통): 결제가 승인 대기였다가 나중에 승인되면 `ticket_purchase`가 빠진다. 이메일 가입은 `sign_up`과 `login`(code)을 둘 다 보낸다. Android는 처리방침을 외부 브라우저로 열어 `legal_privacy`가 없다.

bool 파라미터는 GA4가 bool을 받지 않는 플랫폼이 있어 `"true"`/`"false"` 문자열로 보낸다.

웹 수신자 이벤트(기존 `src/lib/analytics.ts`): `viewer_gate_open`, `letter_end_reached`, `cta_reply_click`, `cta_save_click`, `cta_send_click`, `store_redirect` — 이름 그대로 GA4로 보낸다.

## 웹 쿠키

- gtag `config`에 `cookie_expires: 0`을 준다. `_ga` 쿠키는 브라우저 세션이 끝나면 사라진다. 방문을 넘나드는 식별이 없고, 재방문자는 새 사용자로 잡힌다.
- `allow_google_signals: false`, `allow_ad_personalization_signals: false`.
- 측정 ID는 `VITE_GA_MEASUREMENT_ID`. 없으면 스크립트를 넣지 않는다(no-op).
- Consent Mode 저장 거부(`analytics_storage: denied`)는 쓰지 않는다. 쿠키는 0개지만 보고서에 원시 이벤트가 나오지 않는다.

## 사람이 할 일(콘솔)

- Firebase 콘솔 → 프로젝트 설정 → 통합 → Google Analytics가 연결돼 있는지 확인. 안 돼 있으면 연결.
- GA4 속성에 웹 데이터 스트림 추가 → 측정 ID(`G-…`)를 Vercel 환경변수 `VITE_GA_MEASUREMENT_ID`에.
- App Store 개인정보 표시: "사용 데이터 → 제품 상호작용"(분석, 연결 안 됨, 추적 아님), "식별자 → 기기 ID"(분석). Play 데이터 보안도 같은 기준.

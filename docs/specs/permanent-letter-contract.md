# 영구 편지권 · 관리자 — 서버 계약 (iOS · Android · 웹 공용)

서버 마이그레이션 `letter-app/supabase/migrations/0036~0039`와 Edge Function 4개의 계약.
설계: `docs/superpowers/specs/2026-11-11-permanent-letter-ticket-design.md` (9절 우선).

모든 RPC는 PostgREST `rpc/<이름>`. 표에 없는 기존 RPC는 시그니처·반환 형태가 그대로다.

## 상태

편지의 접근 상태 `state`는 넷 중 하나다.

| state | 뜻 | access_until | delete_at |
|---|---|---|---|
| `permanent` | 기간 제한 없음(기존 편지·영구 편지권·관리자) | null | null |
| `open` | 무료 기간 안. 아직 아무도 안 열었으면 시각이 둘 다 null | 잠기는 시각 또는 null | 삭제 예정 시각 또는 null |
| `locked` | 무료 기간이 끝남. 편지권을 붙이면 다시 열린다 | 잠긴 시각 | 삭제 예정 시각 |
| `gone` | 유예도 끝남. 되살릴 수 없다 | — | — |

- 14일은 **편지 단위**로 하나만 센다. 소유자가 아닌 로그인 사용자가 처음 본문을 받은 순간부터다.
- 보낸 사람(소유자)은 편지가 존재하는 한 항상 자기 편지를 연다.
- 일수(`free_days`, `grace_days`)는 `get_my_entitlements`가 준다. 코드에 14·30을 박지 않는다.

## 오류 코드 (RPC 예외 메시지)

| 메시지 | 뜻 | 화면 |
|---|---|---|
| `LOGIN_REQUIRED` | 이 편지는 로그인해야 열린다(익명 호출) | 봉투 화면 → 로그인 → 같은 편지로 복귀 |
| `LETTER_LOCKED:<ISO8601 UTC>` | 무료 기간이 끝났다. 뒤의 시각은 삭제 예정 시각 | 잠김 화면("○월 ○일까지 다시 열 수 있어요") |
| `LETTER_GONE` | 유예까지 끝났다 | "더 이상 열 수 없는 편지예요" |
| `NO_TICKET` | 편지권 잔액 부족 | 구매 화면(앱) / "뮤터 앱에서 살 수 있어요"(웹) |

기존 코드(`TOKEN_NOT_FOUND`·`LINK_REVOKED`·`LINK_EXPIRED`·`NOT_YET_REVEALED:<ISO>`·`WRONG_PASSWORD`·
`LETTER_NOT_FOUND`·`AUTH_REQUIRED`·`FORBIDDEN`)는 그대로다. 검사 순서는
토큰 → 회수 → 만료 → **로그인 요구** → 예약 공개 → 암호 → 편지 존재 → **잠김/삭제**.

## RPC

| RPC | 호출자 | 인자 | 반환 |
|---|---|---|---|
| `get_letter_by_token` (기존) | anon·로그인 | `p_token text, p_password text` | 기존 키 + `is_permanent boolean`, `access_until timestamptz\|null` |
| `get_letter_cover` | anon·로그인 | `p_token text` | 아래 "봉투" |
| `get_letter_access_states` | 로그인 | `p_letter_ids uuid[]` | `[{letter_id, state, access_until, delete_at, kept_by_recipient}]` — 내가 보냈거나 받은 편지함에 가진 편지만. `kept_by_recipient`는 받은 사람이 자기 편지권으로 영구로 만든 편지일 때 **보낸 사람에게만** true(삭제 확인 경고에 쓴다) |
| `get_letter_readers` | 소유자 | `p_letter_id uuid` | `[{user_id, nickname, first_opened_at, last_opened_at, open_count}]` 처음 연 순. 소유자 아니면 `FORBIDDEN` |
| `get_my_entitlements` | 로그인 | 없음 | `{is_admin, tickets, paid_enabled, free_days, grace_days}` |
| `get_my_ticket_history` | 로그인 | 없음 | `[{created_at, delta, reason, letter_title}]` 최근 순. `reason` ∈ `purchase`·`use`·`grant`·`refund` |
| `make_letter_permanent` | 소유자 | `p_letter_id uuid` | void. `FORBIDDEN`·`NO_TICKET`·`LETTER_GONE` |
| `keep_received_letter` | 로그인 | `p_token text, p_password text` | void. 링크 오류들 + `NO_TICKET`·`LETTER_GONE`. 성공하면 받은 편지함에 들어간다 |
| `is_admin` | 로그인 | 없음 | boolean |

- `make_letter_permanent`·`keep_received_letter`는 이미 영구인 편지에 부르면 차감 없이 성공한다.
- 관리자는 차감 없이 영구가 된다.
- `p_password`는 암호가 없어도 **키를 생략하지 말고 null을 보낸다**(Android: DTO에 `= null` 기본값 금지 —
  생략되면 PostgREST가 함수를 못 찾는다).

### 봉투 — `get_letter_cover`

본문 없음, 열람 기록 없음. 로그인 전 화면과 잠김 화면에 쓴다.

```json
{ "sealed": true }
```
토큰 없음·회수·만료·암호 걸림·예약 공개 전·삭제함 편지는 전부 이 모양이다(이유를 구분할 수 없다).

```json
{
  "sealed": false,
  "template_id": "classic-serif",
  "title": "…",
  "sender_nickname": "…" ,
  "state": "open",
  "access_until": null,
  "delete_at": null,
  "login_required": true
}
```
`login_required`는 "이 편지는 로그인이 필요한가"이며 호출자의 로그인 여부와 무관하다.
`sender_nickname`·`access_until`·`delete_at`은 null일 수 있다.

### 화면 노출 규칙

- `paid_enabled == false`이고 `is_admin == false` → 편지권 관련 UI(프로필 항목·구매·"영구 편지로 만들기")를 전부 숨긴다.
  상태 표시(○일 남음·자물쇠)는 `state`가 `permanent`가 아닌 편지에만 나오므로 따로 숨길 필요가 없다.
- `is_admin == true` → 구매 UI를 숨기고 편지에는 "영구"만 표시한다.

## Edge Function

### `verify-purchase` — 편지권 구매 검증·지급 (앱 전용)

`POST /functions/v1/verify-purchase`, `Authorization: Bearer <사용자 JWT>`

| 플랫폼 | 본문 |
|---|---|
| iOS | `{"platform":"ios","jws":"<StoreKit 2 Transaction의 jwsRepresentation>"}` |
| Android | `{"platform":"android","productId":"mutter.ticket.1","purchaseToken":"…"}` |

- `200 {"granted": true, "tickets": 5}` — `tickets`는 지급 후 잔액.
- `200 {"granted": false, "tickets": 5}` — 이미 지급된 영수증. **성공이다.** 앱은 이때도 거래를 finish/consume 한다.
- 오류 `{"error":"<코드>"}`: `401 unauthorized` · `403 not_tester` · `400 bad_request` · `400 invalid_receipt` ·
  `400 unknown_product` · `501 store_mode_unavailable` · `501 android_verify_unconfigured` · `500 internal`.
- 앱은 **200을 받은 뒤에만** 거래를 finish(iOS)/consume(Android) 한다. 그 외에는 거래를 남겨 두고 다음 실행 때 다시 보낸다.
- 상품: `mutter.ticket.1`(1장), `mutter.ticket.5`(5장). 소모성.
- 지금은 테스트 모드다: `purchase_testers`에 든 계정만 지급된다(그 외 `403 not_tester`).

### `duplicate-letter` — 같은 내용으로 한 통 더 보내기

`POST /functions/v1/duplicate-letter`, `Authorization: Bearer <사용자 JWT>`, 본문 `{"letterId":"<uuid>"}`

- `200 {"letterId":"<새 편지 uuid>"}` — 본문·테마·음악·사진이 복제된 새 편지. 무료 편지로 시작한다(원본이 영구여도).
- `401 unauthorized` · `404 letter_not_found`(남의 편지 포함) · `400 bad_request` · `500 copy_failed`.
- 새 편지는 링크가 없다. 이어서 기존 발송 흐름(링크 발급 또는 연결 상대에게 보내기)을 탄다.

### `letter-photo-urls` (기존)

수신자 모드 요청에 로그인 사용자의 `Authorization`이 있으면 그 권한으로 게이트를 지난다.
`403 {error}`에 `LOGIN_REQUIRED`·`LETTER_LOCKED:<ISO>`·`LETTER_GONE`이 올 수 있다. supabase SDK의
`functions.invoke`는 로그인 세션의 JWT를 자동으로 싣는다.

## 푸시

보낸 사람에게만 간다. data에 `type`과 `letter_id`가 있다.

| type | 제목 | 언제 |
|---|---|---|
| `letter_lock_soon` | 편지가 곧 닫혀요 | 잠기기 3일 전(편지당 1회) |
| `letter_locked` | 편지가 닫혔어요 | 잠긴 뒤(편지당 1회) |

탭하면 그 보낸 편지의 상세로 간다. Android 알림 태그는 `letter_id`를 써서 서로 덮어쓰지 않게 한다.

## 문구 (세 플랫폼 동일)

| 키 | 문구 |
|---|---|
| 닫힘 예고(받은 사람, 남은 기간 ≤ 3일) | `이 편지는 {n}일 뒤 닫혀요` (당일이면 `이 편지는 오늘 닫혀요`) |
| 잠김 화면 제목 | `보관 기간이 지난 편지예요` |
| 잠김 화면 본문 | `{M}월 {D}일까지 다시 열 수 있어요.` |
| 잠김 화면 버튼(앱, 로그인) | `편지권으로 간직하기` |
| 잠김 화면 안내(웹, 잔액 없음) | `편지권은 뮤터 앱에서 살 수 있어요` |
| 삭제 대상 | `더 이상 열 수 없는 편지예요` |
| 봉투 버튼 | `편지 열기` |
| 봉투 안내 | `로그인하면 편지가 열려요` |
| 보낸 사람 버튼 | `영구 편지로 만들기 · 편지권 1장` |
| 목록 상태 | `영구` / `{n}일 남음` / `닫힘` |
| 링크 발급 화면 안내 | `받는 분이 처음 연 날부터 {free_days}일 동안 열려요.` |
| 사본 | `같은 내용으로 한 통 더 보내기` |
| 열람자 행 | `{닉네임} · {M}월 {D}일에 열어봄` (닉네임 없으면 `이름 없는 사용자`) |
| 받은 사람이 편지권 쓸 때 확인 | `보낸 사람이 편지를 지우면 함께 사라지고 편지권은 돌려드려요.` |
| 받은 사람이 간직한 편지를 보낸 사람이 지울 때 | `받은 분이 편지권으로 간직한 편지예요. 지우면 영구가 풀려요.` |
| 편지권 남은 계정 탈퇴 | `남은 편지권 {n}장이 사라져요.` |
| 편지권 화면 제목 | `편지권` |
| 편지권 잔액 | `{n}장` |
| 편지권 설명 | `편지권 1장으로 편지 한 통을 기간 제한 없이 간직할 수 있어요.` |
| 편지권 부족 | `편지권이 없어요` |

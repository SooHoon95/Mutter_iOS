# 영구 편지권(수익화) · 관리자 권한 설계

작성일 2026-11-11. 대상: 서버(`letter-app/supabase`), iOS(`Mutter`), Android(`Mutter_android`), 웹(`letter-app`).

## 1. 의도

뮤터의 첫 수익화. 돈을 내는 사람은 **보낸 사람**이다. 편지를 공들여 쓴 사람에게는 "오래 남았으면" 하는 마음이 이미 있고, 받은 사람은 뮤터를 고른 적이 없으며 대부분 앱 없이 웹으로 연다. 받은 사람에게 결제창을 띄우면 그 불쾌함이 보낸 사람에게 돌아가 다음 편지가 사라진다. 그래서 받은 사람을 막는 대신 "간직하고 싶으면 남긴다"로 읽히게 만든다.

함께 붙이는 것: 운영자가 DB에서 지정하는 **관리자**. 관리자는 구매와 상관없이 모든 유료 기능을 쓴다.

## 2. 사용자와 합의한 것

- 무료 편지는 받은 사람이 **처음 연 날부터 14일** 동안 횟수 제한 없이 열린다.
- 보낸 사람이 **영구 편지권** 1장을 붙이면 그 편지는 기간 제한이 없어진다. 되돌릴 수 없다.
- 편지권은 **통 단위 구매**(구독 아님). 낱장과 묶음을 판다. 사 둔 편지권은 계정에 쌓인다.
- 14일이 지나면 편지는 지워지지 않고 **잠긴다**. 잠긴 뒤 **30일** 안에 편지권을 붙이면 다시 열린다. 그 30일도 지나면 완전히 삭제한다.
- 받은 사람이 받은 편지함에 저장해 둔 편지도 같은 규칙을 따른다(저장만으로 무료 영구가 되지 않는다).
- 받은 사람도 원하면 자기 편지권으로 그 편지를 영구로 만들 수 있다. 선택지일 뿐 강요하지 않는다.
- **지금까지 보낸 편지는 전부 영구로 둔다.** 새 편지부터 적용한다.
- 관리자는 DB에서 지정한다. 관리자가 보내는 편지는 편지권 없이 전부 자동 영구이고, 앱에 구매 화면이 뜨지 않는다.

## 3. 목표 · 비목표 · 반(反)목표

**목표**
- 위 규칙을 서버가 단독으로 강제한다(클라이언트를 고쳐도 우회 불가).
- iOS·Android에서 스토어 결제로 편지권을 사고, 세 플랫폼 모두에서 편지권을 붙일 수 있다.
- 기간·유예 일수는 앱 업데이트 없이 서버 설정으로 바꾼다.

**비목표(이번에 안 함)**
- 구독 상품.
- 웹 결제(결제 대행사 연동). 웹은 보유 편지권 사용만 된다.
- 환불 자동 회수(스토어 환불 알림 연동). 구매 기록은 남기되 회수는 수동.
- 편지권 선물·양도, 쿠폰.

**반목표(이렇게 되면 실패)**
- 기존 편지가 하나라도 잠기거나 사라진다.
- 받은 사람이 편지를 열려는 순간 결제 화면부터 본다.
- 결제는 됐는데 편지권이 안 들어온다, 또는 한 번 결제로 두 번 들어온다.
- 유료 전환을 켜기 전에 배포된 구버전 앱에서 편지가 이유 없이 안 열린다.

## 4. 현재 구조(확인한 사실)

- 받은 사람의 본문 읽기는 전부 `get_letter_by_token`(최신 정의 0022)을 지난다. 사진은 Edge Function `letter-photo-urls`가 같은 게이트를 재사용하고, 미리보기는 `get_letter_preview`(0033)다.
- `letter_opens`(0017)는 **토큰 단위**로 `first_opened_at`·`open_count`를 쌓는다. 기록은 클라이언트가 따로 부르는 `record_letter_open`이라 누락될 수 있다.
- 편지 본체는 `letters_all` 테이블 + `letters` 뷰(0035, 소프트 삭제). 받은 편지함은 `inbox_all` + `inbox` 뷰.
- 30일 지난 삭제 편지는 pg_cron → pg_net → Edge Function `purge-deleted-letters`가 사진까지 지운다(0035).
- `app_config`(0031)는 플랫폼별 버전 행이라 일수 설정을 넣기엔 맞지 않는다.
- 푸시는 Edge Function `send-push` + DB 트리거(0029).
- 세 클라이언트 어디에도 결제 코드는 없다.

## 5. 설계

### 5.1 편지의 상태

편지 단위로 판정한다(링크 단위 아님 — 링크를 새로 뽑아 기간을 되감는 구멍을 막는다).

`letters_all`에 추가:
- `first_opened_at timestamptz` — 소유자가 아닌 사람이 처음 본문을 받은 시각.
- `permanent_at timestamptz` — 영구가 된 시각(null이면 무료 편지).
- `permanent_by uuid`, `permanent_source text` — `'ticket' | 'admin'`. 기록용.

판정(서버 함수 하나 `letter_access_state(letter)`로 모은다):

| 상태 | 조건 |
|---|---|
| 영구 | `permanent_at`이 있음 / 유료 전환이 꺼져 있음 / `created_at < paid_from` |
| 열림 | `first_opened_at`이 없음, 또는 `now < first_opened_at + free_days` |
| 잠김 | `first_opened_at + free_days ≤ now < first_opened_at + free_days + grace_days` |
| 삭제 대상 | 그 이후 |

한 번도 열리지 않은 편지는 시계가 돌지 않으므로 잠기지도 지워지지도 않는다.

### 5.2 설정

새 테이블 `monetization_config`(단일 행, 공개 읽기, 쓰기는 service role만):
- `paid_from timestamptz` — null이면 유료 전환 꺼짐(모든 편지 영구 취급). 켤 때 그 시각을 넣는다. **이 시각 이전에 만든 편지는 영원히 영구**다. 기존 편지 보호와 단계 배포를 이 값 하나가 맡는다.
- `free_days int default 14`, `grace_days int default 30`.

### 5.3 읽기 게이트

`get_letter_by_token`을 고친다.
- 소유자가 아닌 호출이 성공하면 `first_opened_at`이 비어 있을 때 채운다(클라이언트의 `record_letter_open`에 의존하지 않는다).
- 잠김이면 본문을 주지 않고 오류 코드 `letter_locked`를 낸다. 응답에는 제목·보낸 사람 닉네임·`delete_at`만 싣는다.
- 열림이면 응답에 `access_until`(잠기는 시각)과 `is_permanent`를 싣는다.
- 소유자는 편지가 존재하는 한 자기 편지를 항상 본다. *(작성자 판단)*

같은 판정을 `letter-photo-urls`, `get_letter_preview`에 적용한다. 미리보기는 잠겨도 제목까지는 보인다.

목록 RPC에 상태를 싣는다: `get_my_inbox`, `get_my_deleted_inbox`, `get_my_letters_with_status`, `get_thread`에 `is_permanent`·`access_until`·`is_locked`·`delete_at`.

`mutter-networking`의 오류 매핑 표에 `letter_locked`를 먼저 추가하고 세 클라이언트에 반영한다.

### 5.4 관리자

- 새 테이블 `app_admins(user_id uuid primary key references auth.users, note text, created_at)`. RLS 켜고 정책 없음 → 대시보드/service role로만 넣고 뺀다. `profiles`에 컬럼을 두지 않는 이유는 본인이 자기 행을 고칠 수 있는 테이블이라서다.
- `is_admin()` — security definer, 로그인 사용자 본인 여부만 반환.
- 관리자가 편지를 만들면 트리거가 `permanent_at = now()`, `permanent_source = 'admin'`으로 채운다.
- `app_admins`에 행이 들어가면 그 사람의 기존 무료 편지도 영구로 바꾼다.
- 관리자에서 빼도 이미 영구가 된 편지는 그대로 둔다(받은 사람 쪽에서 갑자기 사라지면 안 된다).
- 운영 방법: `insert into app_admins (user_id, note) values ('<uuid>', '메모');`

### 5.5 편지권

- `ticket_purchases` — `id, user_id, platform('ios'|'android'), product_id, store_transaction_id(unique), tickets, status, raw jsonb, created_at`.
- `ticket_ledger` — `id, user_id, delta, reason('purchase'|'use'|'grant'|'refund'), purchase_id, letter_id, created_at`. 잔액 = `sum(delta)`. 두 테이블 모두 본인 조회만, 쓰기는 security definer 함수만.
- `get_my_entitlements()` → `{ is_admin, tickets, paid_enabled, free_days, grace_days }`. 앱은 이것 하나로 구매 화면 노출을 정한다.
- `make_letter_permanent(p_letter_id)` — 호출자가 편지 소유자이거나 그 편지를 받은 편지함에 가진 사람이어야 한다. 한 트랜잭션에서 잔액 확인 → `ticket_ledger`에 -1 → `permanent_at` 채움. 관리자는 차감 없음. 이미 영구면 차감 없이 성공. 열림·잠김 상태 모두에서 된다. 삭제 대상이 된 뒤에는 실패(`letter_gone`). 잔액 부족은 `no_ticket`.
- 운영자가 편지권을 그냥 줄 때: `ticket_ledger`에 `reason='grant'` 행을 직접 넣는다.

### 5.6 결제

- 상품(소모성): `mutter.ticket.1`(1장), `mutter.ticket.5`(5장). iOS·Android 같은 ID. 가격은 스토어에서 정하고 코드에 두지 않는다. 시작 가격 제안: 1장 1,100원, 5장 4,400원 *(작성자 제안, 스토어에서 변경 가능)*.
- iOS는 StoreKit 2, Android는 Play Billing. 외부 결제 SDK(RevenueCat 등)는 쓰지 않는다 — 상품이 둘뿐이고 제3자에 구매 데이터를 넘길 이유가 없다. *(작성자 판단)*
- 새 Edge Function `verify-purchase`: 앱이 구매 직후 영수증(iOS 서명 트랜잭션 / Android purchase token)을 보낸다. 서버가 **스토어 API로 직접 검증**한 뒤 `ticket_purchases`와 `ticket_ledger`에 기록한다. `store_transaction_id` unique로 중복 지급을 막고, 같은 영수증 재전송은 "이미 지급됨"으로 성공 처리한다.
- 앱은 서버가 지급을 확인한 뒤에만 트랜잭션을 finish/consume 한다. 앱 실행 시 미완료 트랜잭션을 다시 서버로 보낸다(결제는 됐는데 지급 전에 앱이 죽은 경우).
- 웹은 구매 없음. 잔액이 있으면 쓰고, 없으면 "편지권은 뮤터 앱에서 살 수 있어요" 안내만 한다.

### 5.7 알림

- 잠기기 3일 전과 잠긴 시점에 **보낸 사람**에게 푸시("○○에게 보낸 편지가 3일 뒤 닫혀요"). 하루 한 번 pg_cron이 대상을 골라 `send-push`를 부른다. 편지당 각 1회만(보낸 여부를 `letters_all`에 기록).
- 받은 사람에게는 푸시를 보내지 않는다. 화면 안내만 한다.

### 5.8 삭제

삭제 대상이 된 편지는 기존 `purge-deleted-letters`가 함께 지운다(사진 포함). 보낸 사람의 보낸 편지함에서도 사라진다. 휴지통 30일과는 별개 경로다.

### 5.9 화면

**받은 사람(뷰어, 세 플랫폼)**
- 열림이고 남은 기간이 3일 이하면 하단에 조용한 한 줄: "이 편지는 3일 뒤 닫혀요". 그 전에는 아무것도 띄우지 않는다.
- 잠김이면 본문 대신 잠김 화면: 제목, 보낸 사람, "보관 기간이 지난 편지예요. ○월 ○일까지 다시 열 수 있어요." 로그인한 받은 사람에게는 "편지권으로 간직하기" 버튼(앱), 웹은 앱 안내.

**받은 편지함** — 잠긴 편지는 목록에 남고 자물쇠 표시. 누르면 잠김 화면.

**보낸 사람**
- 전달(링크 발급) 화면과 보낸 편지 상세에 "영구 편지로 만들기 · 편지권 1장". 잔액이 없으면 구매 화면으로.
- 보낸 편지 목록에 상태: 영구 / "○일 남음" / 잠김.
- 프로필에 "편지권" 화면: 잔액, 1장·5장 구매, 구매 내역.
- 관리자에게는 구매 관련 UI를 전부 숨기고 편지에 "영구"만 표시.

문구는 `Localizable.strings`(iOS)·`strings.xml`(Android)에 두고 세 플랫폼이 같게 맞춘다.

## 6. 배포 순서

1. **서버**: 스키마·게이트·관리자·편지권 함수. `paid_from = null`이라 동작 변화 없음. 관리자 기능은 이 단계에서 바로 쓸 수 있다.
2. **앱·웹**: 잠김 화면, 상태 표시, 편지권 구매·사용. 유료 전환이 꺼져 있으면 관련 UI는 보이지 않는다(`paid_enabled`).
3. 세 플랫폼이 심사를 통과해 배포된 뒤 `app_config.min_version`을 올리고 `paid_from = now()`를 넣어 켠다. 켠 뒤 만든 편지부터 14일 규칙이 적용된다.

## 7. 사용자가 직접 해야 하는 것

- App Store Connect: 유료 앱 계약·세금·은행 정보, 인앱 상품 2개 등록, 서버 검증용 In-App Purchase 키 발급.
- Play Console: 결제 프로필, 인앱 상품 2개 등록, 서비스 계정에 주문 조회 권한.
- 유료 판매에 따른 약관·환불 안내 문구 확정, 사업자 정보 표시.

## 8. 만드는 사람에게 맡기는 것

- 스토어 검증의 구체 방식(iOS: App Store Server API 호출 또는 JWS 체인 검증).
- 마이그레이션 번호·분할, 모듈 배치(iOS는 `mutter-architecture`의 레이어 규칙, 결제는 Infrastructure에서만 StoreKit 접근).
- 잠김 화면·편지권 화면의 시각 디자인(기존 디자인 토큰 사용).

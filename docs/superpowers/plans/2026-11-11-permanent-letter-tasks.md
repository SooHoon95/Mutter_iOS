# 영구 편지권 · 관리자 — 전체 작업 목록 (ralplan)

스펙: `docs/superpowers/specs/2026-11-11-permanent-letter-ticket-design.md` (9절 우선)
서버 상세 계획: `docs/superpowers/plans/2026-11-11-permanent-letter-server.md`

저장소: 서버·웹 `../letter-app`, iOS `.`(Mutter), Android `../Mutter_android`.

## RALPLAN-DR

**원칙**
1. 서버가 단독으로 강제한다. 클라이언트는 표시만 한다.
2. 스위치가 꺼진 동안 기존 사용자·기존 앱의 동작은 바뀌지 않는다.
3. 기존 RPC 계약을 바꾸지 않고 새 RPC를 더한다.
4. 돈이 걸린 경로(지급·차감·환급)는 중복과 경합에 안전해야 한다.
5. 세 클라이언트는 같은 문구·같은 흐름(패리티).

**결정 동인**: (1) 기존 편지 26통과 배포된 앱 무손상 (2) 운영 DB 하나뿐, 로컬 DB 없음 (3) 결제는 테스트 모드만.

**선택지**
- A. 상태를 `letters_all` 컬럼에 둔다 — 조인 없음 / 소유자가 RLS로 직접 고칠 수 있어 가드 트리거 필요, `created_at` 위조 가능. **기각.**
- B. 상태를 별도 `letter_access` 테이블에 둔다(채택) — 클라이언트 접근 0, 생성 시각을 서버가 찍음 / 조인 1회, 트리거로 행 생성.
- C. 목록 RPC 반환 형태에 상태 열 추가 — 호출 1회 / 반환 타입 변경으로 drop+create, 배포된 앱 디코딩 위험. **기각.** 대신 `get_letter_access_states` 추가(채택).
- E. 환급 시점: (가) 삭제함으로 옮길 때 즉시 환급하고 영구 표시를 지운다(채택) — 받은 사람이 바로 돌려받음, 삭제→복구 악용 불가 / 복구된 편지가 영구가 아니게 됨(잠김 유예 30일은 보장). (나) 영구 삭제 때만 환급 — 구현 단순, 복구하면 그대로 영구 / 받은 사람은 편지를 잃고도 최대 30일 뒤에야 돌려받음. **(나) 기각.**
- F. 테스트 모드 영수증: (가) 서명 검증 없이 디코드 + 테스터 한정(채택) — Xcode 테스트 결제는 Apple 서명이 아니라 검증 자체가 불가, 스토어 등록 없이 바로 시험 / 테스터는 편지권을 위조할 수 있음(실판매 전 정리). (나) 지금 서명 체인 검증까지 — Sandbox 구매만 시험 가능, 유료 앱 계약·상품 등록이 선행돼야 함. **(나)는 실판매 전환 계획으로.**
- D. 결제 SDK(RevenueCat) — 검증 위임 / 제3자 의존, 상품 2개에 과함. **기각.** 직접 연동 + 서버 검증 함수(채택, 이번엔 테스트 모드).

## 작업 목록

각 작업은 "완료 조건"이 전부 증거로 확인돼야 끝난다. 서버 작업의 상세 단계·검사 항목은 서버 계획 문서의 같은 번호 Task.

### 서버 (letter-app)

| ID | 작업 | 완료 조건 |
|---|---|---|
| S1 | 설정·편지 상태·관리자 (`0036`) | 서버 계획 Task 1 예행 결과 `A~E=ok`, 되돌림 확인 |
| S2 | 읽기 게이트·열람자 (`0037`, `letter-photo-urls`) | Task 2 예행 `A~G=ok`, `deno check` 통과 |
| S3 | 편지권 (`0038`) | Task 3 예행 `A~H=ok` |
| S4 | 사본 보내기 (`duplicate-letter`) | `deno check` 통과, (반영 후) Task 4 Step 4의 A~C |
| S5 | 만료 푸시·삭제 (`0039`, `purge-deleted-letters`) | Task 5 예행 `A~E=ok`, `deno check` 통과 |
| S6 | 구매 검증 테스트 모드 (`verify-purchase`) | `deno check` 통과, (반영 후) Task 6 Step 4의 A~G |
| S7 | 계약 문서(반영 전)·운영 반영·회귀 확인 | `mutter-networking` 갱신 → 사용자가 `db push`·함수 배포 실행 → 스위치 꺼진 상태 회귀 확인 |

### iOS (Mutter)

| ID | 작업 | 완료 조건 |
|---|---|---|
| I1 | 도메인·인프라: 접근 상태·권한·편지권 | `LetterAccessState`(permanent/open/locked/gone + accessUntil/deleteAt), `Entitlements`, 새 UseCase·Repository가 S의 RPC를 호출. `MutterError`에 `loginRequired`·`letterLocked(deleteAt)`·`letterGone`·`noTicket` 매핑. Debug 컴파일 통과, `/arch-check` 위반 0 |
| I2 | 수신 화면: 로그인 봉투·잠김 화면·닫힘 예고 한 줄 | 로그아웃 상태에서 링크로 들어오면 `get_letter_cover` 봉투(제목·보낸 사람·"편지 열기") → 로그인 → 같은 편지로 복귀. 잠긴 편지를 열면 본문 대신 잠김 화면(제목·보낸 사람·"○월 ○일까지"). 남은 기간 3일 이하일 때만 한 줄. 시뮬레이터에서 테스터 편지로 두 상태 스크린샷 |
| I3 | 받은 편지함·보낸 편지 상태 표시 | 목록에 영구/"○일 남음"/자물쇠. 보낸 편지 상세에 열람자 목록과 "같은 내용으로 한 통 더 보내기" 동작. **증거:** 시뮬레이터에서 테스터 계정으로 세 상태 편지가 든 목록 스크린샷 1장, 열람자 목록 스크린샷 1장, 사본 보내기 뒤 `select count(*) from letters where owner_id = <테스터>`가 1 증가 |
| I4 | 편지권 화면·사용·푸시 | 새 푸시 타입 `letter_lock_soon`·`letter_locked`를 탭하면 그 보낸 편지 상세로 이동. 받은 사람이 편지권을 쓸 때 확인 문구에 "보낸 사람이 편지를 지우면 함께 사라지고 편지권은 돌려드려요". 편지권 잔액이 있는 계정이 탈퇴하려 하면 "남은 편지권 N장이 사라져요" 경고. 프로필에 편지권(잔액·1장/5장·내역). "영구 편지로 만들기"가 `make_letter_permanent`, 잠김 화면의 "편지권으로 간직하기"가 `keep_received_letter` 호출. 관리자·`paid_enabled=false`면 구매 UI 숨김. **증거:** `xcrun simctl push booted com.efreedom.mutter <payload.apns>`(type `letter_locked`)를 탭해 해당 편지 상세가 뜨는 스크린샷, 영구화 전후 `get_letter_access_states` 결과(`open`→`permanent`)와 잔액 -1, 일반 계정(`paid_enabled=false`)에서 프로필에 편지권 항목이 없는 스크린샷 |
| I5 | StoreKit 2 테스트 구매 | `Mutter.storekit` 설정 파일에 상품 2개, 구매 → `verify-purchase` → 잔액 증가 후에만 `finish()`. 앱 시작 시 미완료 트랜잭션 재전송. 시뮬레이터에서 구매 1회로 잔액 +1 확인 |

### Android (Mutter_android)

| ID | 작업 | 완료 조건 |
|---|---|---|
| A1 | 도메인·데이터 계층 | iOS I1과 같은 모델·오류 매핑. RPC 파라미터 DTO에 `= null` 기본값 없음(메모리 규칙). `./gradlew :app:assembleDebug` 통과 |
| A2 | 수신 화면 로그인 봉투·잠김·예고 | I2와 같은 동작·문구(앱 링크로 로그아웃 상태 진입 포함). **증거:** 에뮬레이터에서 `adb shell am start -a android.intent.action.VIEW -d "<편지 링크>"`로 로그아웃 진입 → 봉투, 로그인 후 본문, 잠긴 편지의 잠김 화면 — `adb exec-out screencap` 3장 |
| A3 | 목록 상태·열람자·사본 | I3과 같은 동작. **증거:** I3과 같은 항목을 에뮬레이터 스크린샷 + DB 조회로 |
| A4 | 편지권 화면·사용·푸시 | I4와 같은 동작(푸시 라우팅·환급 안내·탈퇴 경고 포함). 잠김 알림의 알림 태그는 `letter_id`를 써서 서로 덮어쓰지 않게 한다(`PushNotifications.kt:58`). **증거:** 알림 인텐트 extra(`type=letter_locked`, `letter_id`)로 `adb shell am start` 해 편지 상세 스크린샷, 영구화 전후 상태·잔액 조회, 일반 계정 프로필 스크린샷 |
| A5 | Play Billing 테스트 구매 | Billing 라이브러리 연동, 구매 → `verify-purchase` → 성공 후 `consume`. 컴파일 통과. **실구매 시험은 Play Console 상품 등록·라이선스 테스터 지정(사용자 작업) 후** — 그 전까지는 "코드 완료, 실기기 시험 대기"로 보고 |

### 웹 (letter-app/src)

| ID | 작업 | 완료 조건 |
|---|---|---|
| W1 | 데이터 계층 | `src/data`에 상태·권한·편지권 호출과 오류 매핑. `npx tsc -b` 통과, 기존 vitest 통과 |
| W2 | 뷰어 `/l/:token`: 로그인 봉투·잠김 화면·닫힘 예고 | 남은 기간 3일 이하일 때 "이 편지는 ○일 뒤 닫혀요" 한 줄(앱과 같은 문구). 비로그인 + `login_required`면 봉투(제목·보낸 사람·"편지 열기") → 로그인 → 같은 편지로 복귀. 잠김 화면. 스위치 꺼진 기존 편지는 지금처럼 바로 열림. 브라우저로 세 경우 확인 |
| W3 | 목록 상태·열람자·사본·편지권 사용 | 보낸 편지·받은 편지함에 상태 표시, 편지권 잔액이 있으면 사용, 없으면 "뮤터 앱에서 살 수 있어요" 안내. 구매 UI 없음. 받은 사람이 편지권을 쓸 때 환급 안내 문구, 편지권이 남은 계정 탈퇴 시 경고(앱과 같은 문구). **증거:** `npm run dev`로 띄워 Playwright로 테스터 계정 로그인 → 보낸 편지 목록(세 상태)·열람자·편지권 사용 전후 스크린샷, 사용 뒤 상태 조회가 `permanent` |

### 마무리

| ID | 작업 | 완료 조건 |
|---|---|---|
| F1 | 끝단 시험(테스터 계정) | 운영 DB의 테스트 편지 `first_opened_at`을 직접 고치는 단계가 있으므로 **사용자 확인을 받고** 진행. 테스터가 편지 발송 → 다른 계정으로 열람 → `first_opened_at`을 과거로 옮겨 잠김 → 편지권 구매(iOS 테스트 결제) → 영구화 → 다시 열림. 받은 사람 영구화 후 보낸 사람 삭제 → 환급 1장 |
| F2 | 검토·정리 | Architect 승인, 변경 파일 한정 정리. 정리 뒤 재실행: 서버 전체 예행(Task 7 Step 1) `ok`, `deno check` 4개 함수, iOS Debug 빌드, Android `:app:assembleDebug`, 웹 `npx tsc -b && npx vitest run` |

## Architect 검토 반영 (2026-11-11)

- 트리거 함수 전부 security definer, 검사는 authenticated + `letters` 뷰 경유.
- 환급 시 영구 표시를 함께 지운다(삭제→복구 반복으로 공짜 영구화 차단). Architect 제안(하드 삭제 때만 환급)보다 받은 사람에게 즉시 돌려준다. Critic 지적 반영: 이때 14일 시계를 "방금 잠김"으로 맞춰, 복구된 편지가 곧바로 삭제되지 않고 30일 유예를 갖게 한다.
- Critic 지적 반영: Xcode 테스트 결제의 거래 번호 재사용 대응, 삭제 작업이 집은 편지는 항상 `gone`, 소유자는 `keep_received_letter`에서 받은 편지함에 넣지 않음, 예행을 "검사마다 스스로 되돌림" 구조로, 웹에도 닫힘 예고·환급 안내·탈퇴 경고, 클라이언트 작업마다 증거 방법 명시.
- 차감은 편지 행 잠금 → 사용자 잠금 순서.
- 만료 삭제는 `claim_expired_letter`로 다시 확인 후 사진 삭제.
- 새 함수·테이블은 `public, anon, authenticated` 모두 revoke 후 필요한 것만 grant.
- 테스트 편지권은 원장에 환경을 남기고 실판매 전환 때 정리.
- 계약 문서 갱신을 운영 반영 전으로 이동, 앱에도 로그인 봉투·푸시 라우팅·환급 안내·탈퇴 경고 추가.
- 로그인 요구에 대한 반론(무설치 열람 약속과 충돌)은 인지했으나 사용자가 "전원 로그인"으로 결정함. 스위치(`require_login`)가 따로 있어 켜기 전에 되돌릴 수 있다.
- 영구 편지 내용 수정 가능은 감수(서버 계획 문서 끝 "감수하기로 한 것").

## 순서와 병렬

- S1 → S2 → S3 순차(같은 스키마). S4·S5·S6은 S3 뒤 서로 독립.
- **S7의 운영 반영은 사용자만 실행할 수 있다.** 반영 전에는 클라이언트의 런타임 확인이 불가능하다 → 반영 요청 시점에 클라이언트 I1·A1·W1(계약만 있으면 되는 계층)을 병행한다.
- I·A·W는 서로 독립(저장소가 다름) → 병렬 가능. 각 저장소 안에서는 번호 순.

## 사용자만 할 수 있는 것 (막히면 멈추고 요청)

1. `supabase db push`, 함수 배포, `supabase secrets set PURCHASE_MODE=test`
2. 테스터 계정 지정(어느 계정을 `purchase_testers`에 넣을지)
3. Play Console 인앱 상품 등록·라이선스 테스터(A5 실구매 시험)
4. 스토어 업로드·심사 제출, 스위치 켜기 — 이번 범위 밖

# 편지 삭제함(30일 보관) + 되돌리기 토스트

세 플랫폼(iOS·Android·웹) 공통 계약. 서버는 `letter-app/supabase`.

## 1. 목표

- 실수로 지운 편지를 되살릴 수 있게 한다 — 즉시(토스트 "되돌리기"), 나중에(삭제함), 그보다 나중엔 문의(운영자 복구).
- 삭제한 편지는 30일 보관 뒤 사진까지 완전히 지운다.
- 이미 배포된 앱(iOS 1.0.5, Android 1.3.0)이 보내는 "지우기" 요청도 서버에서 보관 처리로 바뀐다(앱 업데이트 전부터 보호).

## 2. 서버 (migration 0035_letter_trash)

### 2.1 테이블·뷰

- `letters` 테이블을 `letters_all`로 이름을 바꾸고 `deleted_at timestamptz` 열을 추가한다.
- 같은 자리에 뷰 `letters`(`security_invoker = true`)를 둔다: `deleted_at is null`인 행만, 기존 열만.
  - 기존 RPC·트리거·클라이언트 `from('letters')` 질의가 모두 이름으로 `letters`를 찾으므로 삭제된 편지는 손대지 않고도 모든 경로(내 편지·받은 편지함·스레드·링크 열람·미리보기·사진 URL·링크 발급·연결 전송)에서 사라진다.
  - FK(delivery_links·inbox·letter_opens·takedowns)는 OID를 따라 `letters_all`을 가리킨다. 보관 중엔 연관 행이 그대로 남아 복구하면 링크·상대 보관함까지 그대로 돌아온다.
  - insert/update는 단순 뷰 자동 갱신으로 그대로 동작한다. RLS(`letters_owner_rw`)는 `letters_all`에 남아 invoker 기준으로 적용된다.
- 뷰에 `INSTEAD OF DELETE` 트리거: 실제 삭제 대신 `update letters_all set deleted_at = now()`. 호출자 권한으로 실행돼 RLS가 소유자만 허용한다.
  - 서버 내부 삭제(계정 탈퇴의 FK cascade, 영구 삭제 RPC, 정리 작업)는 `letters_all`을 직접 지우므로 보관을 거치지 않는다.

### 2.2 RPC (모두 `authenticated`, security invoker + RLS, 비로그인 `AUTH_REQUIRED`)

| 함수 | 반환 | 동작 |
|---|---|---|
| `get_my_deleted_letters()` | `table(id uuid, title text, template_id text, deleted_at timestamptz, purge_at timestamptz)` | 내 보관 중 편지, 최근 삭제순. `purge_at = deleted_at + 30일` |
| `restore_letter(p_letter_id uuid)` | `void` | `deleted_at = null`. 대상 없으면 `LETTER_NOT_FOUND` |
| `purge_letter(p_letter_id uuid)` | `void` | 보관 중인 내 편지를 `letters_all`에서 영구 삭제(연관 행 cascade). 대상 없으면 `LETTER_NOT_FOUND` |

삭제는 기존 그대로 `from('letters').delete().eq('id', id)`(뷰 트리거가 보관 처리).

### 2.3 사진

- 삭제(보관) 시 사진은 지우지 않는다 — 클라이언트의 삭제 직후 사진 폴더 정리 코드를 제거한다.
- Storage `letter_photos_delete_own` 정책에 "보관 중인 편지의 사진은 못 지움" 조건 추가(구버전 앱이 삭제 후 사진을 지우려 해도 막힌다).
- 영구 삭제(`purge_letter`) 뒤에는 클라이언트가 기존 사진 폴더 정리를 best effort로 실행한다.

### 2.4 30일 정리

- Edge Function `purge-deleted-letters`(verify_jwt=false, service role): `deleted_at < now() - 30일`인 편지마다 사진 폴더를 지우고 행을 영구 삭제. 기한이 지난 것만 지우므로 누가 호출해도 무해하다(비밀값 불필요).
- `pg_cron` 매일 03:00 KST(18:00 UTC)에 `pg_net`으로 위 함수를 호출.

### 2.5 운영자 복구(문의)

`scripts/restore-letter.sh <letter_id>` — `update letters_all set deleted_at = null where id = …`(30일 안이면 복구 가능).

## 3. 클라이언트 UX (세 플랫폼 동일)

### 3.1 내 편지 삭제 → 토스트

- 삭제 즉시 목록에서 빼고 하단 토스트 **"편지를 삭제함으로 옮겼어요"** + 버튼 **"되돌리기"**, 5초.
- "되돌리기" → `restore_letter` → 목록 새로고침. 실패 시 에러 메시지.
- 기존 확인 모달(웹)은 문구만 "삭제함으로 옮길까요? 30일 뒤 완전히 지워져요."로 바꾼다. 앱은 확인 없이 스와이프 그대로(토스트가 안전망).

### 3.2 삭제함 화면

- 진입: 내 편지 목록 화면 상단의 "삭제함" 버튼(아이콘 trash).
- 안내 문구: "삭제한 편지는 30일 동안 보관된 뒤 완전히 지워져요."
- 행: 제목(없으면 "제목 없음"), "N일 후 완전히 삭제"(N = purge_at까지 남은 일수 올림, 최소 1; 0 이하면 "오늘 완전히 삭제").
- 행 동작: **복구**(`restore_letter` → 행 제거 + 토스트 "편지를 되살렸어요") / **완전히 삭제**(확인 다이얼로그 "완전히 삭제할까요? 되돌릴 수 없어요." → `purge_letter` → 사진 폴더 정리 best effort → 행 제거).
- 빈 상태: "삭제함이 비어 있어요".

### 3.3 받은 편지함 삭제 → 토스트

- 받은 편지함 삭제는 서버 변경 없이 **지연 삭제**: 즉시 목록에서 숨기고 토스트 **"보관함에서 뺐어요"** + **"되돌리기"** 5초. 시간이 지나거나 화면을 떠나면 실제 delete 실행, "되돌리기"면 아무 요청 없이 다시 보여준다.
  - 재-insert 방식은 `on_inbox_insert` 푸시 트리거가 다시 울리므로 쓰지 않는다.

## 4. 개인정보처리방침

보유 기간에 "이용자가 삭제한 편지는 삭제함에 30일간 보관된 뒤 완전히 삭제(삭제함에서 즉시 완전 삭제 가능)" 추가. 계정 삭제는 지금처럼 즉시 파기.

## 5. 검증

- DB: 마이그레이션 적용 후 트랜잭션 롤백 시나리오로 삭제→뷰에서 사라짐→삭제함 조회→복구→영구 삭제, 받은 사람 inbox 숨김/복구, 계정 삭제 cascade 확인.
- 웹: 단위 테스트 + 운영 반영 후 동작 확인.
- 앱: 컴파일 + 단위 테스트(실기기 육안 확인 필요).

---

## 6. 받은 편지함 — 편집 + 받은 편지 삭제함 (2026-11-10 추가)

배경: iOS 받은 편지함 헤더의 톱니바퀴 아이콘은 디자인 킷 적용(`8518c6f`) 때 들어간 자리표시로, 동작이 연결된 적이 없다(Android·웹엔 아이콘 자체가 없음). 설정은 프로필 탭에 이미 있어 톱니바퀴를 "편집 + 받은 편지 삭제함"으로 바꾼다. 3.3의 지연 삭제는 이 절로 대체한다.

### 6.1 서버 (같은 0035에 포함)

- `inbox` → `inbox_all` + `deleted_at`, 뷰 `inbox`(security_invoker, 미삭제만). `from('inbox').delete()`는 뷰 트리거가 보관으로 바꾼다(구버전 앱 포함).
- 삭제함에 있는 편지를 다시 받으면(링크 재열람 자동 저장·save_to_inbox·연결 재발송) 새 행 대신 그 행을 되살린다(푸시 재발송 없음).
- 받은 사람이 지운 편지는 보낸 사람의 "받은이"·스레드에서도 함께 빠지고, 복구하면 돌아온다.

| 함수 | 반환 | 동작 |
|---|---|---|
| `get_my_deleted_inbox()` | `table(letter_id uuid, token text, title text, sender_id uuid, sender_nickname text, deleted_at timestamptz, purge_at timestamptz)` | 내 받은 편지 삭제함, 최근 삭제순. 보낸 사람이 지운 편지는 제외 |
| `restore_inbox_items(p_letter_ids uuid[])` | `int`(되살린 수) | 복구 |
| `purge_inbox_items(p_letter_ids uuid[])` | `int`(지운 수) | 받은 편지함에서 영구 삭제(보낸 사람 편지는 그대로) |

삭제(여러 통 포함): `from('inbox').delete().in('letter_id', ids)` (한 통이면 `.eq`). 30일 지난 행은 pg_cron이 SQL로 지운다.

### 6.2 받은 편지함 화면

- 헤더 오른쪽: **삭제함** 아이콘(trash) + **편집** 텍스트 버튼(iOS의 톱니바퀴 자리).
- 편집 모드: 버튼 문구 "완료". 카드마다 선택 원(체크)이 붙고, 카드를 누르면 열지 않고 선택이 토글된다. 하단 바: 왼쪽 "전체 선택"/"선택 해제", 오른쪽 "삭제 (N)"(0이면 비활성). 편집 모드에선 스와이프·당겨서 새로고침 끈다.
- 삭제(편집 모드·스와이프 공통): 즉시 목록에서 빼고 서버에 삭제 → 편집 모드 종료 → 토스트 1통 "편지를 삭제함으로 옮겼어요" / 여러 통 "N통을 삭제함으로 옮겼어요" + "되돌리기" 5초 → `restore_inbox_items(ids)` → 새로고침. 실패하면 뺀 항목을 되살리고 에러 표시.
- 웹은 스와이프 없이 편집 모드만.

### 6.3 받은 편지 삭제함 화면

- 제목 "받은 편지 삭제함". 안내 "삭제한 편지는 30일 동안 보관된 뒤 받은 편지함에서 완전히 지워져요."
- 행: 제목(없으면 "제목 없음"), "보낸이: {닉네임}"(없으면 "알 수 없음"), 3.2와 같은 남은 기간 문구.
- 동작: **복구**(토스트 "편지를 되살렸어요") / **완전히 삭제**(확인 "완전히 삭제할까요? 받은 편지함에서만 지워지고, 링크를 다시 열면 다시 담겨요." → `purge_inbox_items([id])`). 빈 상태 "삭제함이 비어 있어요".
- 웹 경로 `/inbox/trash`.

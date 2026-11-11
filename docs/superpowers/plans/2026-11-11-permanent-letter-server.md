# 영구 편지권 · 관리자 — 서버 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supabase 서버가 "무료 편지 14일 → 잠김 30일 → 삭제", 영구 편지권, 관리자, 전원 로그인 규칙을 단독으로 강제하게 한다. 스위치가 꺼진 동안에는 기존 동작이 하나도 바뀌지 않는다.

**Architecture:** 편지별 상태는 클라이언트가 닿지 못하는 `letter_access` 테이블에 두고, 모든 읽기는 공용 게이트 `private.open_letter`를 지난다. 편지권은 원장(`ticket_ledger`) 합계로 잔액을 구하고, 지급은 Edge Function `verify-purchase`만 한다(이번엔 테스트 모드). 만료 처리(푸시·삭제)는 기존 pg_cron + Edge Function 경로를 넓힌다.

**Tech Stack:** Postgres(plpgsql, RLS, pg_cron, pg_net), Supabase Edge Functions(Deno/TypeScript), Supabase CLI 2.84.

**Spec:** `Mutter/docs/superpowers/specs/2026-11-11-permanent-letter-ticket-design.md` — 본문과 9절이 다르면 9절이 우선.

**저장소:** 모든 경로는 `/Users/choesuhun/Desktop/Code/letter-app` 기준. 클라이언트(iOS·Android·웹)는 별도 계획이며 이 계획의 "Produces"가 그 계약이다.

## Global Constraints

- `free_days` 기본 14, `grace_days` 기본 30. 코드에 숫자를 박지 않고 `monetization_config`에서 읽는다.
- `paid_from`이 null이고 `require_login`이 false이면 **기존 편지·기존 앱의 동작이 바이트 단위로 같아야 한다**(같은 예외 문자열, 같은 JSON 키 — 키 추가만 허용).
- 기존 RPC의 시그니처와 반환 형태를 바꾸지 않는다. 새 정보는 새 RPC로 준다.
- 예외 문자열은 대문자: `LOGIN_REQUIRED`, `LETTER_LOCKED:<ISO8601 UTC>`, `NO_TICKET`, `LETTER_GONE`, 기존 `AUTH_REQUIRED`·`FORBIDDEN`·`LETTER_NOT_FOUND`·`TOKEN_NOT_FOUND`.
- 새 테이블은 전부 RLS를 켠다. 쓰기는 security definer 함수(또는 service role)만.
- **권한은 명시적으로 닫는다.** Supabase는 public 스키마의 새 테이블·함수를 anon·authenticated에 자동 grant한다. 새 테이블은 `revoke all on <t> from public, anon, authenticated` 뒤 필요한 `grant select`만, 새 함수는 `revoke all on function … from public, anon, authenticated` 뒤 필요한 역할에만 `grant execute`.
- **트리거 함수는 전부 `security definer set search_path = public`.** 편지 작성·삭제는 authenticated 권한으로 `letters` 뷰를 거치고(`0035:37-57`), 기존 삭제 함수들은 invoker다. definer가 아니면 배포된 모든 앱에서 편지 작성·삭제가 permission denied로 실패한다.
- 마이그레이션 파일에 `begin`/`commit`/`concurrently`를 쓰지 않는다. 파일 첫 줄: `set lock_timeout = '3s'; set statement_timeout = '30s';`(세션 설정 — `db push`가 트랜잭션으로 감싸는지와 무관하게 적용된다)(운영 테이블에 트리거를 걸 때 잠금 대기로 서비스가 멈추지 않게).
- 상품 ID와 장수: `mutter.ticket.1` → 1, `mutter.ticket.5` → 5. 번들 ID `com.efreedom.mutter`.
- 테스트 코드 파일은 만들지 않는다(프로젝트 규칙). 검증은 아래 "검증 방식"의 되돌림 스크립트로 하고 저장소에 커밋하지 않는다. 기존 vitest가 깨지면 최소 수정만.
- 운영 DB 반영(`supabase db push`)과 함수 배포는 사용자가 실행한다. 각 태스크는 "반영 요청"에서 멈춘다.
- 커밋 메시지에 Co-Authored-By를 넣지 않는다. 비밀값을 커밋하지 않는다.

## 검증 방식 (모든 태스크 공통)

로컬 DB가 없다(docker 없음). 운영 DB에 **적용 전 예행**을 돌린다: 마이그레이션 SQL + 검사 블록들 + 마무리 블록을 한 번의 질의로 보낸다. 여러 문장 질의는 한 트랜잭션이고, 마무리 블록이 `raise exception 'RESULT: …'`로 끝나 마이그레이션까지 전부 되돌린다.

파일 구성(순서대로 이어 붙인다):
1. 마이그레이션들(`0036 …` 필요한 만큼).
2. `$SCRATCH/pre.sql`: `create temp table _r(k text, v text); delete from private.push_config;`
3. 태스크별 검사 `$SCRATCH/check_N.sql`: `do $$` 블록 하나. **안쪽 `begin … exception` 블록**에서 검사를 수행해 결과 문자열을 모은 뒤 `raise exception using message = <결과>`로 스스로 되돌리고, 바깥 `exception when others then insert into _r values ('taskN', sqlerrm)`로 결과만 남긴다. 이렇게 하면 검사가 바꾼 설정·테스터·관리자·편지가 다음 검사로 새지 않아 여러 태스크의 검사를 한 파일에 이어 붙일 수 있다.
4. `$SCRATCH/final.sql`: `do $$ begin raise exception 'RESULT: %', (select string_agg(k || '[' || v || ']', ' ') from _r); end $$;`

```bash
cat supabase/migrations/0036_*.sql "$SCRATCH/pre.sql" "$SCRATCH/check_1.sql" "$SCRATCH/final.sql" > "$SCRATCH/dry.sql"
supabase db query --linked --agent=no -f "$SCRATCH/dry.sql" 2>&1 | grep -o "RESULT:.*"
```

검사 블록 안에서 사용자를 흉내 낼 때:
```sql
perform set_config('role','authenticated',true);
perform set_config('request.jwt.claims', json_build_object('sub',v_user,'role','authenticated')::text, true);
-- 익명: set_config('role','anon',true) + claims '{"role":"anon"}'
-- 서버 권한으로 돌아갈 때: set_config('role','postgres',true)
```
검사 블록 공통 규칙:
- `pre.sql`이 `private.push_config`를 비워 두므로 검사 중 inbox insert 등이 실제 푸시를 큐에 넣지 않는다(트랜잭션이 되돌린다).
- 편지 작성·삭제·복구는 반드시 `role=authenticated`로 **`letters` 뷰를 통해** 실행한다(실제 앱 경로). 서버 권한으로만 검사하면 권한 결함을 못 잡는다.
- 예외를 잡는 `begin … exception` 블록이 되돌아가면 `set_config(…, true)`도 되돌아간다. 하위 검사마다 역할·claims를 다시 설정한다.

`$SCRATCH`는 세션 스크래치 디렉터리. 예행 뒤에는 `select to_regclass('public.<새 테이블>')`이 NULL인지 확인해 되돌림을 증명한다.

## Review Focus

1. **스위치가 꺼진 상태에서 익명 수신자가 기존 편지를 연다** → 지금과 똑같이 열려야 한다(Task 2 검사 A).
2. **소유자가 PostgREST로 `letter_access`나 `letters_all`을 직접 고쳐 영구로 만들려 한다** → 0행/권한 오류(Task 1 검사 C).
3. **같은 영수증을 두 번 보낸다 / 두 기기가 동시에 편지권 1장을 쓴다** → 지급 1회, 차감 1회(Task 3 검사 D·E, Task 6 검사 B).
4. **받은 사람이 편지권을 붙인 편지를 보낸 사람이 삭제함으로 보냈다가 복구한다** → 환급은 정확히 1장, 복구된 편지는 영구가 아니다(Task 3 검사 F).
5. **잠긴 편지의 사진 URL을 직접 요청한다** → 403(Task 2 검사 F).
6. **보낸 사람이 "되돌리기"로 편지를 복구한다** → 환급으로 영구가 풀린 편지라도 바로 삭제 대상이 되지 않는다. 최악의 경우 '잠김'이고 삭제 기한은 지운 날부터 30일로 센다(Task 3 검사 F).

---

### Task 1: 설정 · 편지 상태 · 관리자 (`0036_monetization_base.sql`)

**Files:**
- Create: `supabase/migrations/0036_monetization_base.sql`

**Interfaces:**
- Produces (테이블):
  - `monetization_config(id boolean primary key default true check (id), paid_from timestamptz, free_days int not null default 14, grace_days int not null default 30, require_login boolean not null default false)` — 행 1개 삽입, `select`는 anon·authenticated 허용, 쓰기 정책 없음.
  - `letter_access(letter_id uuid primary key references letters_all(id) on delete cascade, created_at timestamptz not null default now(), is_metered boolean not null default false, first_opened_at timestamptz, permanent_at timestamptz, permanent_by uuid, permanent_source text check (permanent_source in ('ticket','admin')), lock_warned_at timestamptz, lock_notified_at timestamptz, refunded_at timestamptz, purge_claimed_at timestamptz)` — RLS 켜고 정책 없음, `revoke all … from anon, authenticated`.
  - `app_admins(user_id uuid primary key references auth.users(id) on delete cascade, note text, created_at timestamptz not null default now())` — RLS 켜고 정책 없음.
  - `purchase_testers(user_id uuid primary key references auth.users(id) on delete cascade, note text, created_at timestamptz not null default now())` — 같은 방식.
- Produces (함수):
  - `private.is_admin_user(p_user uuid) returns boolean`, `private.is_tester(p_user uuid) returns boolean` — stable, security definer.
  - `public.is_admin() returns boolean` — `private.is_admin_user(auth.uid())`, authenticated에 grant.
  - `private.letter_state(p_letter_id uuid) returns table(state text, access_until timestamptz, delete_at timestamptz)` — `state ∈ 'permanent' | 'open' | 'locked' | 'gone'`. 규칙: **`purge_claimed_at`이 있으면 무조건 `gone`**(삭제 작업이 집은 편지는 설정이 바뀌어도 되살아나지 않는다). 아니면 `letter_access` 행이 없거나 `is_metered = false`이거나 `permanent_at`이 있으면 `permanent`(시각 둘 다 null). 아니면 `first_opened_at`이 null → `open`(시각 null). 아니면 `access_until = first_opened_at + free_days일`, `delete_at = access_until + grace_days일`이고 `now()`와 비교해 `open`/`locked`/`gone`.
- Produces (트리거):
  - `letter_access_init` — `after insert on letters_all`: `letter_access` 행 생성. `is_metered := (paid_from is not null and now() >= paid_from) or private.is_tester(new.owner_id)`. 소유자가 관리자면 `permanent_at = now(), permanent_by = owner, permanent_source = 'admin'`.
  - `app_admins_grant` — `after insert on app_admins`: 그 사용자 소유 편지의 `letter_access` 중 `permanent_at is null`이고 상태가 `gone`이 아닌 행을 `'admin'`으로 영구화(`gone`은 사진이 이미 지워졌을 수 있다).
- 백필: 기존 `letters_all` 전 행에 `letter_access(letter_id, created_at, is_metered=false)`.

- [ ] **Step 1: 예행 메커니즘 확인.** 한 파일로 보낸다: `create table public._dry(x int);` + `pre.sql` + 검사 블록(안쪽에서 `set_config('role','authenticated',true)` → `select current_user`가 `authenticated` → `set_config('role','postgres',true)` → `current_user`가 `postgres`인지, 그리고 `_dry`에 1행 insert) + `final.sql`. 기대: `RESULT: task0[role_auth=ok role_back=ok]`. 뒤이어 `select to_regclass('public._dry')`가 NULL인지, `select count(*) from private.push_config`가 원래 값인지 본다. `_dry`가 남아 있으면 `drop table public._dry`로 지우고 **멈춰서 보고한다**(검증 방식을 바꿔야 한다). 역할 전환이 안 되면 역시 멈춘다.
- [ ] **Step 2: `0036_monetization_base.sql` 작성.** 위 Interfaces 그대로. 파일 머리 주석에 스펙 경로와 "꺼진 동안 동작 변화 없음"을 적는다(0035의 주석 양식).
- [ ] **Step 3: 검사 스크립트 작성 후 예행.** 검사 항목과 기대값:
  - A. `select count(*) from letter_access` = `select count(*) from letters_all`, `is_metered` 전부 false.
  - B. `role=authenticated`(U)로 `insert into letters(owner_id,title,paragraphs,template_id)`가 **성공**하고(권한 오류 없음) → 그 편지의 `private.letter_state` = `permanent`. `insert into purchase_testers(U)` 뒤 새 편지 → `open`, `first_opened_at`을 15일 전으로 고치면 `locked`, 45일 전이면 `gone`. `free_days`를 7로 바꾸면 8일 전도 `locked`.
  - C. authenticated(U)로 `update letter_access set permanent_at = now()` → 권한 오류. `select * from letter_access` → 권한 오류.
  - D. `insert into app_admins(U)` → U의 metered 편지가 `permanent`, 이후 새 편지도 `permanent`·`permanent_source='admin'`. `delete from app_admins` 뒤에도 그 편지들은 `permanent`.
  - E. authenticated(U)로 `select is_admin()` → 관리자일 때 true, 아닐 때 false. anon으로 `select * from monetization_config` → 1행.
  기대 출력: `RESULT: task1[A=ok B=ok C=ok D=ok E=ok]`.
- [ ] **Step 4: 되돌림 확인.** `select to_regclass('public.letter_access')` → NULL.
- [ ] **Step 5: Commit.** `git add supabase/migrations/0036_monetization_base.sql && git commit -m "feat: 수익화 기반 — 설정·편지 상태(letter_access)·관리자·테스터 테이블"`

### Task 2: 읽기 게이트 · 열람자 (`0037_letter_gate.sql`, `letter-photo-urls`)

**Files:**
- Create: `supabase/migrations/0037_letter_gate.sql`
- Modify: `supabase/functions/letter-photo-urls/index.ts` (`openByToken`), `supabase/functions/letter-photo-urls/handler.ts`(Authorization 전달이 필요하면)

**Interfaces:**
- Consumes: Task 1의 `letter_access`, `private.letter_state`, `monetization_config`.
- Produces:
  - `letter_readers(letter_id uuid references letters_all(id) on delete cascade, user_id uuid references auth.users(id) on delete cascade, first_opened_at timestamptz not null default now(), last_opened_at timestamptz not null default now(), open_count int not null default 1, primary key (letter_id, user_id))` — RLS: 본인 행 select만.
  - `private.check_link(p_token text, p_password text) returns delivery_links` — 아래 ①~⑦ 중 링크·편지 존재 검사(①②③⑤⑥⑦)만 수행한다. `open_letter`와 Task 3의 `keep_received_letter`가 함께 쓴다.
  - `private.open_letter(p_token text, p_password text, p_record boolean) returns letters_all` — 검사 순서: ① 토큰 없음 `TOKEN_NOT_FOUND` ② `LINK_REVOKED` ③ `LINK_EXPIRED` ④ **로그인 요구**: `auth.uid() is null` 이고 (`require_login` 또는 그 편지가 `is_metered`)이면 `LOGIN_REQUIRED` ⑤ `NOT_YET_REVEALED:<ISO>` ⑥ `WRONG_PASSWORD` ⑦ 편지 없음(`letters` 뷰 기준) `LETTER_NOT_FOUND` ⑧ 호출자가 소유자가 아니면 상태 검사: `locked` → `LETTER_LOCKED:<delete_at ISO UTC>`, `gone` → `LETTER_GONE`. ⑨ `p_record`이고 로그인한 비소유자면 `letter_readers` upsert(횟수 +1) + `letter_access.first_opened_at`이 null이면 채움. **응답의 `access_until`은 ⑨ 뒤에 계산한다**(첫 열람 응답에도 지금+14일이 실린다). ①~⑦의 문자열·순서는 0022와 같다.
  - `get_letter_by_token(p_token text, p_password text) returns json` — `private.open_letter(…, true)` 사용. 기존 키(`id,title,paragraphs,template_id,cues,audio_disabled`)에 `is_permanent boolean`, `access_until timestamptz|null`만 더한다. 기존 ⑦ 받은 편지함 upsert 유지. grant는 그대로 anon·authenticated.
  - `get_letter_photo_access(p_token text, p_password text) returns json {id, paragraphs}` — `open_letter(…, false)`. 부수효과 없음. anon·authenticated.
  - `get_letter_cover(p_token text) returns json` — 본문 없음, 기록 없음. 토큰 없음·revoke·만료·암호 있음·예약 공개 전이면 `{"sealed":true}`만. 아니면 `{"sealed":false,"template_id","title","sender_nickname","state","access_until","delete_at","login_required":boolean}`. `login_required`는 ④와 같은 조건(호출자 로그인 여부와 무관하게 "이 편지는 로그인이 필요한가").
  - `get_letter_readers(p_letter_id uuid) returns table(user_id uuid, nickname text, first_opened_at timestamptz, last_opened_at timestamptz, open_count int)` — 소유자 아니면 `FORBIDDEN`. 처음 연 순.
  - `get_letter_access_states(p_letter_ids uuid[]) returns table(letter_id uuid, state text, access_until timestamptz, delete_at timestamptz)` — 호출자가 소유했거나 `inbox_all`에 가진 편지만 돌려준다(나머지는 조용히 빠짐).
  - `save_to_inbox`·`record_letter_open`: 로그인 사용자가 잠긴/사라진 편지에 대해 부르면 각각 `LETTER_LOCKED:…`/조용히 no-op. 그 외 동작 유지.
- `get_letter_cover`는 토큰만으로 제목·닉네임을 보여 준다 — 0033이 지킨 "카드에서는 아무것도 드러내지 않는다"에서 의도적으로 벗어난다(토큰 보유자는 원래 본문까지 읽을 수 있었으므로 새 노출이 아니다). 보낸 사람 닉네임은 새로 드러나는 정보다(스펙이 승인한 봉투 화면 요소). 함수 주석에 두 가지를 그대로 적는다. 삭제함에 있는 편지도 `{"sealed":true}`.
- `letter-photo-urls` 수신자 모드: `get_letter_photo_access`를 **요청의 Authorization이 실제 사용자 JWT일 때만(페이로드 `role == 'authenticated'`) 그 사용자 권한으로**, 아니면 기존 anon 클라이언트로 부른다(supabase-js는 로그아웃 상태에서도 anon 키를 Authorization에 싣는다). 기존 주석("JWT를 싣지 않는다")은 이유가 사라졌으니 새 이유로 고친다.

- [ ] **Step 1: `0037_letter_gate.sql` 작성.**
- [ ] **Step 2: 검사 스크립트 작성 후 예행**(0036 + 0037 + 검사를 이어 붙인다). 기존 편지 L0(소유자 A, 링크 T0, 암호 없음)과 테스터가 만든 새 편지 L1(링크 T1)로:
  - A. anon으로 `get_letter_by_token(T0, null)` → 성공, `is_permanent = true`, `letter_readers` 0행(스위치 꺼짐 = 기존 동작).
  - B. anon으로 `get_letter_by_token(T1, null)` → `LOGIN_REQUIRED`. `require_login = true`로 바꾸면 T0도 `LOGIN_REQUIRED`.
  - C. B(비소유자)로 T1 열기 → 성공, `access_until` = 지금 + 14일(±1분), `letter_readers` 1행, `inbox`에 1행. 한 번 더 열면 `open_count = 2`, `first_opened_at` 불변.
  - D. `first_opened_at`을 15일 전으로 → B는 `LETTER_LOCKED:` + ISO 시각, 소유자 A는 성공. 45일 전 → B는 `LETTER_GONE`.
  - E. `get_letter_cover(T1)`: anon에게 `sealed=false`, 제목·닉네임 있음, `login_required=true`, D 상태에서 `state='locked'`. 암호 걸린 링크는 `{"sealed":true}`만.
  - F. D 상태에서 B가 `get_letter_photo_access(T1,null)` → `LETTER_LOCKED:`. 열림 상태에서는 `letter_readers.open_count`가 늘지 않는다.
  - G. A가 `get_letter_readers(L1)` → B 1행. B가 부르면 `FORBIDDEN`. B가 `get_letter_access_states(array[L1, <남의 편지>])` → L1 1행만.
  기대: `RESULT: task2[A=ok … G=ok]`.
- [ ] **Step 3: `letter-photo-urls` 수정.** `deno check supabase/functions/letter-photo-urls/index.ts` 통과, 기존 `handler` 단위 테스트(`npx vitest run supabase/functions/letter-photo-urls`)가 있으면 통과(깨지면 최소 수정).
- [ ] **Step 4: Commit.** `git commit -m "feat: 편지 읽기 게이트 — 로그인 요구·14일 잠김·열람자 기록, 봉투/상태/열람자 RPC"`

### Task 3: 편지권 (`0038_tickets.sql`)

**Files:**
- Create: `supabase/migrations/0038_tickets.sql`

**Interfaces:**
- Consumes: `letter_access`, `private.letter_state`, `private.is_admin_user`, `private.is_tester`, `private.open_letter`.
- Produces:
  - `ticket_purchases(id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete set null, platform text not null check (platform in ('ios','android')), product_id text not null, store_transaction_id text not null, tickets int not null check (tickets > 0), environment text not null, raw jsonb, created_at timestamptz not null default now(), unique (platform, store_transaction_id))` — `store_transaction_id`는 호출자(Task 6)가 유일하게 만들어 넘긴다(테스트 환경의 거래 번호는 재사용되므로 Task 6 규칙 참고)
  - `ticket_ledger(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, delta int not null, reason text not null check (reason in ('purchase','use','grant','refund')), purchase_id uuid references ticket_purchases(id), letter_id uuid references letters_all(id) on delete set null, environment text, created_at timestamptz not null default now())` — 두 테이블 RLS: 본인 행 select만.
  - `private.ticket_balance(p_user uuid) returns int` — `coalesce(sum(delta),0)`.
  - `get_my_entitlements() returns json {"is_admin":bool,"tickets":int,"paid_enabled":bool,"free_days":int,"grace_days":int}` — `paid_enabled = (paid_from is not null and now() >= paid_from) or 호출자가 테스터`. 비로그인 `AUTH_REQUIRED`.
  - `get_my_ticket_history() returns table(created_at timestamptz, delta int, reason text, letter_title text)` — 최근 순.
  - `private.spend_ticket_on(p_user uuid, p_letter_id uuid) returns void` — 공통 본체. 잠금 순서 고정: ① `select … from letter_access where letter_id = p_letter_id for update`(편지 행) ② `pg_advisory_xact_lock(hashtext(p_user::text))`(사용자). 보낸 사람과 받은 사람이 같은 편지에 동시에 써도 한 명만 차감된다. 그 뒤 → 상태가 `gone`이면 `LETTER_GONE` → 이미 영구면 아무것도 안 하고 반환 → 관리자가 아니면 잔액 < 1일 때 `NO_TICKET`, 아니면 원장 `-1, 'use'` → `letter_access`에 `permanent_at=now(), permanent_by=p_user, permanent_source = 관리자면 'admin' 아니면 'ticket'`, `refunded_at = null`.
  - `make_letter_permanent(p_letter_id uuid) returns void` — 소유자 아니면 `FORBIDDEN`.
  - `keep_received_letter(p_token text, p_password text) returns void` — 비로그인 `AUTH_REQUIRED`. `private.open_letter`의 ①~⑦(토큰·revoke·만료·예약 공개·암호·편지 존재)을 `private.check_link`(Task 2)로 그대로 지난다. 성공하면 호출자가 **소유자가 아닐 때만** `inbox`에 upsert한다(잠긴 뒤 처음 온 사람도 받은 편지함에서 다시 찾을 수 있게; 소유자를 넣으면 자기 편지가 받은 편지함에 생기고 "편지가 도착했어요" 푸시가 간다 — `0022:203`과 같은 규칙). 편지 소유자가 불러도 된다.
  - `private.credit_purchase(p_user uuid, p_platform text, p_product_id text, p_transaction_id text, p_tickets int, p_environment text, p_raw jsonb) returns boolean` — 새로 지급하면 true, 같은 `(platform, transaction_id)`가 이미 있으면 false(원장 불변). `service_role`에만 grant, PostgREST로 부를 수 있게 `public.credit_purchase` 래퍼를 같은 grant로 둔다.
  - 환급 트리거 `letters_refund_on_remove`(security definer) — `letters_all`의 `before delete`, 그리고 `after update of deleted_at`(null → 값): `letter_access.permanent_source='ticket'` 이고 `permanent_by <> owner_id` 이고 `refunded_at is null`이면 `permanent_by`에게 `+1,'refund'`를 넣고 **영구 표시를 지운다**(`permanent_at = null, permanent_by = null, permanent_source = null, refunded_at = now()`). 이때 `first_opened_at`이 null이 아니면 `greatest(first_opened_at, now() - free_days일)`로 맞추고(null이면 null 그대로 — 열린 적 없는 편지가 복구 직후 잠기지 않게), `lock_warned_at`·`lock_notified_at`도 null로 되돌린다(다시 잠길 때 보낸 사람에게 알림이 가게) — 편지는 최악의 경우에도 "방금 잠긴" 상태가 되어 30일 유예를 온전히 갖는다(보낸 사람이 되돌리기로 복구했는데 다음 날 새벽 정리 작업이 편지와 사진을 지워 버리는 사고 방지. 아무도 공짜로 읽지는 못한다). 판단 전에 `letter_access` 행을 `for update`로 잠근다(같은 순간에 끝난 편지권 사용을 놓치지 않게). 그래서 보낸 사람이 삭제 → 복구를 반복해도 환급받은 편지가 영구로 남지 않는다(계정 두 개로 공짜 영구화 불가). 복구(값 → null) 때는 아무것도 하지 않는다. `permanent_by` 계정이 이미 없으면 환급 없이 표시만 지운다. PostgREST로 `letters_all.deleted_at`을 직접 바꾸는 경로도 같은 트리거가 잡는다.
  - `ticket_ledger`에 `environment text` 열을 둔다(구매 행은 `ticket_purchases.environment` 값, 그 외 null). `private.ticket_balance`는 전부 합산한다 — 테스트 편지권 정리는 실판매 전환 계획의 단계다(아래 "이 계획 밖").

- [ ] **Step 1: `0038_tickets.sql` 작성.**
- [ ] **Step 2: 검사 스크립트 작성 후 예행**(0036~0038 + 검사). 테스터 A의 metered 편지 L1(링크 T1), 비소유자 B:
  - A. A 잔액 0에서 `make_letter_permanent(L1)` → `NO_TICKET`. B가 부르면 `FORBIDDEN`.
  - B. `credit_purchase(A,'ios','mutter.ticket.5','tx1',5,'Xcode','{}')` → true, 잔액 5. 같은 인자로 한 번 더 → false, 잔액 5.
  - C. A가 `make_letter_permanent(L1)` → 잔액 4, 상태 `permanent`, `permanent_source='ticket'`. 한 번 더 → 잔액 4(차감 없음).
  - D. 새 편지 L2를 45일 전에 열린 것으로 → `make_letter_permanent(L2)` = `LETTER_GONE`, 잔액 4.
  - E. 새 편지 L3(링크 T3)을 15일 전에 열린 것으로(잠김). B에게 1장 지급 후 B가 `keep_received_letter(T3)` → B 잔액 0, L3 `permanent`, B가 `get_letter_by_token(T3)` 성공.
  - F. A가(`role=authenticated`, `letters` 뷰로) `delete from letters where id = L3`(삭제함) → 권한 오류 없이 성공, B 잔액 1, `refunded_at` 채워짐, `permanent_at` null. A가 `restore_letter(L3)` → L3 상태는 `locked`(영구 아님), `delete_at`이 지금+30일(±1분), B 잔액 1. 같은 시나리오를 **45일 전에 열린 편지**로 반복해도 복구 후 `locked`(`gone` 아님). A가 다시 삭제 → B 잔액 1(중복 환급 없음). B가 다시 1장 써서 영구화 → A가 `purge_letter` 전 단계로 삭제 → B 잔액 다시 +1.
  - F2. 경합: 같은 편지에 대해 A의 `make_letter_permanent`가 끝난 뒤 B의 `keep_received_letter` → B 차감 없음(이미 영구). (동시 실행은 한 연결에서 재현할 수 없으므로 잠금 순서는 코드 검토로 확인한다.)
  - F3. 받은 사람 B가 잠긴 편지에 `keep_received_letter(T3, null)` → B의 `inbox`에 L3 행이 있다. 암호 걸린 링크에 틀린 암호 → `WRONG_PASSWORD`, 차감 없음.
  - G. 관리자 C가 metered 편지를 만든 뒤(이미 영구) `get_my_entitlements()` → `is_admin=true`. 관리자가 남의 잠긴 편지에 `keep_received_letter` → 차감 없이 영구, `permanent_source='admin'`.
  - H. authenticated·anon이 `select credit_purchase(...)` → 권한 오류. `select * from ticket_ledger`는 본인 행만, insert는 권한 오류.
  기대: `RESULT: task3[A=ok … H=ok]`.
- [ ] **Step 3: Commit.** `git commit -m "feat: 영구 편지권 — 구매 기록·원장·사용 RPC·삭제 시 자동 환급"`

### Task 4: 사본 보내기 (`duplicate-letter` Edge Function)

**Files:**
- Create: `supabase/functions/duplicate-letter/index.ts`

**Interfaces:**
- Consumes: `letters` 뷰(소유자 RLS), Storage 버킷 `letter-photos`(경로 `<owner_id>/<letter_id>/<file>`), Task 1 트리거(새 편지의 `letter_access`가 자동 생성됨).
- Produces: `POST /functions/v1/duplicate-letter`, 헤더 `Authorization: Bearer <사용자 JWT>`, 본문 `{"letterId": "<uuid>"}` → `200 {"letterId": "<새 uuid>"}`. 오류: `401 {"error":"unauthorized"}`, `404 {"error":"letter_not_found"}`(남의 편지 포함), `500 {"error":"copy_failed"}`.
- 동작: 호출자 JWT 클라이언트로 원본을 읽는다(RLS가 소유자만 통과) → **새 편지 UUID를 먼저 만든다**(경로 규칙이 `<owner>/<새 id>/`를 요구한다, `handler.ts:77-81`) → service role로 사진 폴더를 새 편지 ID 아래로 복사 → 본문 `paragraphs` 안의 사진 경로에서 `/<옛 letter_id>/`를 `/<새 letter_id>/`로 바꿔 호출자 JWT로 새 편지 insert. 사진 복사가 하나라도 실패하면 이미 복사한 객체를 지우고 `copy_failed`. 새 편지는 무료 편지로 시작한다(영구 상태를 복사하지 않는다). 음악(`cues`)이 `letters` 외 테이블에 있으면 같은 호출 안에서 함께 복제한다 — 구현 전에 `grep -rn "cues\|letter_cues\|music" supabase/migrations`로 저장 위치를 확인하고, 본문 JSON 안에만 있으면 추가 작업 없음.
- 원본의 `audio_disabled`(신고로 음악이 꺼진 표시, `0004`)를 사본에 그대로 옮긴다 — 사본으로 차단을 우회하지 못하게 service role로 설정한다. 사진 복사 뒤 편지 insert가 실패해도 복사한 객체를 지운다.
- 배포 플래그: `--no-verify-jwt`(함수 안에서 직접 인증; `letter-photo-urls`와 같은 방식).

- [ ] **Step 1: 사진 경로가 `paragraphs`에 어떤 모양으로 들어 있는지 확인.** `supabase/functions/letter-photo-urls/handler.ts`의 경로 추출 로직을 읽고 같은 규칙으로 치환한다.
- [ ] **Step 2: 함수 작성.** `deno check supabase/functions/duplicate-letter/index.ts` 통과.
- [ ] **Step 3: Commit.** `git commit -m "feat: 같은 내용으로 한 통 더 보내기 — duplicate-letter 함수(사진 복사 포함)"`
- [ ] **Step 4(반영 후 검증, Task 7에서 실행):** A. 사진이 든 테스트 편지로 호출 → 새 편지 ID 반환, 새 폴더에 같은 수의 객체, 사본의 사진 URL이 열린다. B. 남의 편지 ID → 404 `letter_not_found`, 새 객체 0개. C. Authorization 없이 → 401. 시험으로 만든 사본은 끝나고 지운다.

### Task 5: 만료 처리 — 푸시와 삭제 (`0039_letter_expiry_jobs.sql`, `purge-deleted-letters`)

**Files:**
- Create: `supabase/migrations/0039_letter_expiry_jobs.sql`
- Modify: `supabase/functions/purge-deleted-letters/index.ts`

**Interfaces:**
- Consumes: `letter_access`, `private.letter_state`, 기존 `notify_push(p_recipient uuid, p_title text, p_body text, p_data jsonb)`(0029).
- Produces:
  - `private.notify_letter_locks() returns int` — 보낸 사람에게 푸시를 보내고 보낸 건수를 돌려준다. ① `state='open'`이고 `access_until - now() <= interval '3 days'`이고 `lock_warned_at is null` → 제목 `편지가 곧 닫혀요`, 본문 `"<편지 제목>" 편지가 3일 뒤 닫혀요. 편지권으로 간직할 수 있어요.`, data `{"type":"letter_lock_soon","letter_id":…}`, `lock_warned_at = now()`. ② `state='locked'`이고 `lock_notified_at is null` → 제목 `편지가 닫혔어요`, 본문 `"<편지 제목>" 편지의 보관 기간이 끝났어요. <M월 D일>까지 다시 열 수 있어요.`, data `type:"letter_locked"`, `lock_notified_at = now()`. 제목이 비면 `제목 없는 편지`. 삭제함에 있는 편지(`deleted_at is not null`)는 건너뛴다.
  - cron `notify-letter-locks` — `'0 0 * * *'`(09:00 KST) `select private.notify_letter_locks()`.
  - `public.expired_letter_ids(p_limit int) returns table(id uuid, owner_id uuid)` — `state='gone'`인 편지. `service_role`에만 grant.
  - `public.claim_expired_letter(p_letter_id uuid) returns boolean` — `service_role` 전용. `letter_access` 행을 `for update`로 잠그고 상태가 여전히 `gone`이면 `letter_access.is_metered`는 그대로 두고 `purge_claimed_at = now()`를 찍어 true(이후 이 편지는 `letter_state`가 항상 `gone` → `spend_ticket_on`은 `LETTER_GONE`, `app_admins_grant`는 건너뜀). 아니면 false. `purge_claimed_at` 열과 "찍히면 `gone`" 규칙은 Task 1에 있으므로 `spend_ticket_on`·`app_admins_grant`는 다시 정의할 필요가 없다(둘 다 `letter_state`의 `gone`을 본다).
  - `purge-deleted-letters`: 기존 삭제함 정리 뒤에 `expired_letter_ids(200)`을 받아 편지마다 **`claim_expired_letter` → true일 때만 사진 폴더 → 행** 순서로 지운다(목록을 받은 뒤 영구화된 편지의 사진을 지우는 사고 방지). 행 삭제는 `letters_all`에서 `id`로. 응답은 `{ purged, failed, expired }`로 키 하나 추가.

- [ ] **Step 1: 마이그레이션 작성 후 예행.** 검사: A. 12일 전에 열린 metered 편지 → `notify_letter_locks()` 반환 1, `lock_warned_at` 채워짐, 다시 부르면 0. B. 15일 전 → 반환 1(`locked` 알림), 다시 0. C. 영구 편지·기존 편지·삭제함 편지는 0. D. 45일 전 편지가 `expired_letter_ids(10)`에 나오고 영구 편지는 안 나온다. authenticated가 `expired_letter_ids`·`claim_expired_letter` 호출 → 권한 오류. E. `claim_expired_letter(gone 편지)` → true, 그 뒤 소유자의 `make_letter_permanent` → `LETTER_GONE`. 영구 편지에 `claim_expired_letter` → false. (공통 규칙대로 `private.push_config`를 비워 두므로 `notify_push`는 조용히 skip한다. 반환 건수는 "보내려 한 건수"로 센다.)
- [ ] **Step 2: `purge-deleted-letters` 수정.** `deno check` 통과. 머리 주석의 "삭제함 30일"에 "보관 기간이 끝난 무료 편지"를 덧붙인다.
- [ ] **Step 3: Commit.** `git commit -m "feat: 편지 만료 처리 — 잠김 예고·잠김 푸시, 기간 지난 편지 삭제"`

### Task 6: 구매 검증 — 테스트 모드 (`verify-purchase` Edge Function)

**Files:**
- Create: `supabase/functions/verify-purchase/handler.ts`(순수 로직), `supabase/functions/verify-purchase/index.ts`(배선)

**Interfaces:**
- Consumes: `public.credit_purchase(…)`(service role), `purchase_testers`, `private.ticket_balance`(잔액은 `get_my_entitlements`를 사용자 JWT로 불러 읽는다).
- Produces: `POST /functions/v1/verify-purchase`, 헤더 `Authorization: Bearer <사용자 JWT>`.
  - iOS 본문 `{"platform":"ios","jws":"<StoreKit 2 Transaction JWS>"}`
  - Android 본문 `{"platform":"android","productId":"mutter.ticket.1","purchaseToken":"…"}`
  - `200 {"granted": true|false, "tickets": <지급 후 잔액>}` — `granted=false`는 "이미 지급된 영수증"이며 성공이다(앱은 이때도 트랜잭션을 finish/consume 한다).
  - 오류: `401 unauthorized` · `403 not_tester` · `400 invalid_receipt` · `400 unknown_product` · `501 store_mode_unavailable` · `501 android_verify_unconfigured`. 본문은 `{"error":"<코드>"}`.
- 환경변수: `PURCHASE_MODE`(이번엔 `test`만 구현. 그 외 값·미설정은 `501 store_mode_unavailable` — 실수로 검증 없이 열리지 않게 기본이 닫힘), `PLAY_SERVICE_ACCOUNT_JSON`(Android용, 없으면 `501 android_verify_unconfigured`).
- 테스트 모드 규칙:
  - 호출자가 `purchase_testers`에 없으면 `403 not_tester`. **이 관문이 테스트 모드의 안전장치다** — 서명을 검증하지 않으므로 테스터 외에는 절대 지급하지 않는다.
  - iOS: JWS 페이로드를 디코드만 한다(서명 체인 검증 없음). `bundleId == 'com.efreedom.mutter'`, `environment ∈ {'Xcode','Sandbox'}`(`Production`이면 `invalid_receipt`), `productId`가 상품표에 있어야 한다. 거래 키: `environment == 'Xcode'`이면 `xcode:<userId>:<transactionId>:<purchaseDate>`(Xcode 테스트 결제의 거래 번호는 작은 순번이고 초기화하면 재사용된다 — 그대로 쓰면 나중 구매가 "이미 지급됨"으로 처리된다), `Sandbox`이면 `transactionId` 그대로.
  - Android: 서비스 계정으로 Google Play Developer API `purchases.products.get`(패키지 `com.efreedom.mutter`)을 불러 `purchaseState == 0`을 확인한다. 거래 ID는 `orderId`, 없으면 `purchaseToken`. `environment`는 `purchaseType == 0`이면 `'PlayTest'`, 아니면 `'Play'`.
  - 상품표 `{'mutter.ticket.1': 1, 'mutter.ticket.5': 5}`는 `handler.ts`의 상수 하나.
- 배포 플래그: `--no-verify-jwt`.

- [ ] **Step 1: `handler.ts` 작성.** `createHandler(deps)` 형태로 외부 호출(사용자 확인, 테스터 조회, Play API, credit, 잔액)을 주입받는다(`letter-photo-urls/handler.ts`와 같은 구조).
- [ ] **Step 2: `index.ts` 배선.** `deno check supabase/functions/verify-purchase/index.ts` 통과.
- [ ] **Step 3: Commit.** `git commit -m "feat: 편지권 구매 검증 함수 — 테스트 모드(테스터 한정)"`
- [ ] **Step 4(반영 후 검증, Task 7에서 실행):** A. 비테스터 JWT → 403 `not_tester`. B. 테스터 JWT + 손으로 만든 JWS(`environment:"Xcode"`, `productId:"mutter.ticket.5"`, 새 `transactionId`) → `granted:true`, 잔액 +5; 같은 요청 재전송 → `granted:false`, 잔액 불변. C. `environment:"Production"` → 400. D. 모르는 상품 → 400 `unknown_product`. E. `PURCHASE_MODE` 미설정 상태 → 501. F. 같은 `transactionId`·다른 `purchaseDate`의 Xcode JWS → `granted:true`(재사용된 번호도 지급). G. Android 본문 + `PLAY_SERVICE_ACCOUNT_JSON` 미설정 → 501 `android_verify_unconfigured`; 설정된 뒤 엉터리 `purchaseToken` → 400 `invalid_receipt`. Android 실구매 검증은 Play Console 상품 등록(사용자 작업) 뒤 Android 계획의 A5에서 한다.

### Task 7: 반영 · 운영 검증 · 계약 문서

**Files:**
- Modify: `/Users/choesuhun/Desktop/Code/Mutter/.claude/skills/mutter-networking/SKILL.md`(오류 매핑 표·RPC 목록), `/Users/choesuhun/Desktop/Code/Mutter/docs/specs/module-architecture.md`(RPC 매핑)

**Interfaces:**
- Produces: 클라이언트 계획 3개가 참조할 계약 요약 — 이 계획의 각 Task "Produces"와 같아야 한다.

- [ ] **Step 0: 계약 문서 갱신(반영 요청 전).** `mutter-networking`의 오류 매핑 표에 `LOGIN_REQUIRED`·`LETTER_LOCKED:<ISO>`·`LETTER_GONE`·`NO_TICKET`과 새 RPC·Edge Function(`duplicate-letter`·`verify-purchase`의 요청/응답/오류), 새 푸시 타입(`letter_lock_soon`·`letter_locked`, data에 `letter_id`)을 추가한다(프로젝트 규칙: 서버 계약이 바뀌면 코드보다 먼저 표를 갱신). 클라이언트 작업 I1·A1·W1은 이 문서를 보고 시작한다. Mutter 저장소에 커밋: `docs: 영구 편지권 서버 계약 — 오류 코드·RPC 매핑`.
- [ ] **Step 1: 전체 예행.** `0036~0039` + `pre.sql` + `check_1.sql`·`check_2.sql`·`check_3.sql`·`check_5.sql` + `final.sql`을 이어 붙여 한 번에 돌린다(각 검사는 스스로 되돌리므로 서로 영향을 주지 않는다). 기대: `RESULT: task1[A=ok … E=ok] task2[A=ok … G=ok] task3[A=ok … H=ok] task5[A=ok … E=ok]`.
- [ ] **Step 2: 사용자에게 반영 요청하고 멈춘다.** 실행할 명령을 그대로 준다:
  ```
  cd ../letter-app && supabase db push
  supabase functions deploy letter-photo-urls --no-verify-jwt
  supabase functions deploy purge-deleted-letters --no-verify-jwt
  supabase functions deploy duplicate-letter --no-verify-jwt
  supabase functions deploy verify-purchase --no-verify-jwt
  supabase secrets set PURCHASE_MODE=test
  ```
- [ ] **Step 3: 반영 후 회귀 확인(스위치 꺼짐).** 운영에서: 기존 편지 링크를 익명으로 열어 본문이 오고(`curl`로 `rpc/get_letter_by_token`), `letter_access` 행 수 = `letters_all` 행 수, `is_metered` 전부 false, `cron.job`에 `notify-letter-locks` 1건. 웹 운영 사이트에서 편지 한 통이 그대로 열리는지 브라우저로 본다.
- [ ] **Step 4: Task 4 Step 4, Task 6 Step 4 실행.** 테스터 계정은 사용자에게 받아 `purchase_testers`에 넣는다(되돌림 블록이 아니라 실제 행 — 사용자 확인 후).
- [ ] **Step 5: 배포된 앱 확인.** 새 푸시 타입(`letter_lock_soon`·`letter_locked`)을 모르는 현재 배포본이 알림을 받아도 죽지 않는지 iOS·Android 푸시 처리 코드를 읽어 확인한다(스위치가 꺼져 있고 테스터 편지만 대상이라 일반 사용자에게는 나가지 않는다).
- [ ] **Step 6: push.** letter-app `git push origin main`은 **운영 반영(Step 2)이 끝난 뒤에만** 한다(Vercel 자동 배포). 이 계획은 웹 소스를 바꾸지 않으므로 화면 변화는 없다.

---

## 이 계획 밖 (다음 계획)

- iOS·Android·웹 클라이언트(잠김 화면, 로그인 봉투, 상태 표시, 편지권 화면, StoreKit/Play Billing 테스트 구매).
- 실판매 모드 검증(App Store 서명 체인/Server API, 환불 알림), 스위치 켜기(`paid_from`, `require_login`).
- **실판매 전환 때 테스트 편지권 정리**: 테스트 모드는 서명을 검증하지 않으므로 테스터가 가진 잔액은 실판매 전에 무효화한다(`environment in ('Xcode','Sandbox','PlayTest')`인 구매분을 상쇄하는 원장 행).

## 감수하기로 한 것 (사용자 확인 필요)

- **영구 편지도 내용을 고칠 수 있다.** 소유자는 기존 규칙(`0002:42-48`)대로 자기 편지의 제목·본문을 언제든 수정한다. 편지권 1장(또는 기존 영구 편지 1통)으로 내용만 바꿔 계속 다시 보내는 것이 가능하다. 편집을 막으면 배포된 앱의 수정 기능이 깨지므로 이번에는 그대로 둔다.

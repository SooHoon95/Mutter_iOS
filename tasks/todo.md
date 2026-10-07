# tasks/todo.md

## 현재 작업 — 마케팅 자동화: 주간 루프 + 리드/실무 에이전트 (2026-10-05)

플랜: `~/.claude/plans/mossy-wiggling-perlis.md`. 수집은 스크립트, 판단은 에이전트. Tier 2(발행·스토어 변경)는 승인 게이트. 스케줄은 로컬 launchd(월 09:00 KST).

- [x] P0 `.agents/product-marketing.md` 사실 수정(CC0 삭제·버전·신규 기능·순위·채널 결론) + `auto:begin/end` 블록
- [x] P1 수집 스크립트 4종 + 설정 — 실제 iTunes 데이터로 실행(16 키워드·경쟁 2·리뷰 0·시즌 한글날 D-4). 발견: `음악 편지` 1위 vs `음악편지` 미노출(토크나이저)
- [x] P2 에이전트 `mutter-aso-analyst`·`mutter-copywriter` 신규, `mutter-marketer` 리드 개편(모드·Agent 도구·충돌 규칙·신선도 게이트), `video-director` 규칙 인라인, `/marketing-loop`·`/marketing-approve`, fastlane `promo_text` 레인
- [x] P3 `weekly.sh` 통합 — 1회차 rc=0(14분): 리포트·ASO 분석·큐 4건(promo 98자·threads 2·reel 1)·금지어 0·state 갱신. 2회차 rc=0: 큐 중복 0, 위임 스킵, runs 2. (1차 시도는 `--allowedTools` 가변 인자가 프롬프트를 삼켜 실패 → stdin으로 수정, 메모리 기록)
- [x] P4 `eval.sh` 5케이스 기준선 — 5/5 통과(1번은 첫 실행에서 자가 점검 메모 줄을 금지어로 잡은 오탐 → 검사 수정 후 통과). 함정 케이스(CC0)에서 "전제가 사실이 아닙니다"로 거절 확인
- [x] P5 launchd 등록 — 두 가지 함정 해결: ① launchd 직접 실행은 macOS TCC로 `~/Desktop` 저장소 접근 불가 → `open -g -a Terminal ~/Library/Application Support/Mutter/weekly.command` 경유(Terminal은 Desktop 권한 보유, `-g`로 포커스 탈취 방지) ② oh-my-zsh 업데이트 프롬프트가 입력 첫 글자를 삼킴 → `.zshrc`에 `zstyle :omz:update mode reminder`(omz 로드 전). kickstart 2회 연속 성공, 킬 스위치 즉시 종료, 창 자동 닫힘
- [ ] P6 (선택, 보류) Supabase 집계 RPC — 키를 서버에 심으려면 service role 또는 SQL 에디터 수동 1회가 필요해 이번 세션에서 검증 불가. 리뷰·순위·시즌만으로 루프는 완결. 후속: `app_secrets` 테이블 + `get_marketing_metrics(p_key)` + `metrics_pull.py`
- [x] critic 독립 리뷰 — ACCEPT-WITH-RESERVATIONS: Major 1(`runs` 카운터 LLM 의존 → weekly.sh로 이관) · Minor 7(gitignore·2/29·handled 정리·reviews.jsonl 존재·스냅샷 회전·plist 주석·rating None) · 보완(API 간격 1초·재시도 1회·(e) 문구) 전부 반영 → 커밋

### 2026-10-07 웹 배포
- [x] Supabase `db push`: 0032(android app_config 행, min 0.1.0 — 강제 없음) · 0033(`get_letter_preview`). anon 호출 HTTP 200 `{"sealed":true}` 확인
- [x] letter-app e3bbe60 push → Vercel 배포. 크롤러 UA `/l/:token` → OG 카드(봉인 이미지), 일반 UA → SPA, 사이트 제목 "뮤터 - 음악 편지", 봉투 이미지 200
- [ ] 실제 편지 링크로 카카오 공유 디버거 확인(테마 봉투) — 사용자

## 이전 작업 — 양 플랫폼 심사 제출 + 웹 배포 대기 (2026-09-16)

사용자 지시: "안드·iOS 배포되면 웹도 배포하자, 둘 다 심사 올려". 웹(e3bbe60)은 두 앱 출시 후 push.

- [x] iOS: `submit` 레인에 version/build/notes 옵션 추가 → `fastlane submit version:1.0.4 build:8 notes:…` — **18:11 심사 제출 완료**(1.0.4 버전 생성·ko 릴리스 노트·precheck 통과·빌드 8 선택, 승인 후 수동 출시)
- [x] Android: versionCode 4 / 1.2.0 버전업 커밋(59908a2) → `bundleRelease`+`assembleRelease` BUILD SUCCESSFUL → badging `versionCode=4 versionName=1.2.0` → AAB `app/build/outputs/bundle/release/app-release.aab`(16.5MB). Play API 자격증명 없음 → 콘솔 수동 업로드·제출. 에뮬레이터 R8 스모크 ✔(설치 성공·프로세스 생존·FATAL 0·MainActivity 렌더)
- [ ] 웹: 보류. 두 앱 출시 확인 후 `git push`(Vercel) + `supabase db push`(0033) + 카카오 디버거 확인
- [x] 리뷰 섹션 기록

### 리뷰 (2026-09-16, 심사 제출)

- iOS 1.0.4(8): 18:11 심사 제출 완료. 릴리스 노트 ko 포함, precheck 통과, 승인 후 수동 출시(ASC에서 "출시" 버튼). Fastfile `submit`이 version/build/notes를 받게 됨(97e1181).
- Android 1.2.0(vc4): AAB `Mutter_android/app/build/outputs/bundle/release/app-release.aab`, R8 APK 에뮬레이터 스모크 통과. Play Console 업로드·릴리스 노트·제출은 사용자(자격증명 없음). 저장소에 git remote 없음.
- 웹 e3bbe60: 두 앱 출시 확인 후 `git push` + `supabase db push`(0033) + 카카오 디버거 확인 — 보류 중.

## 이전 작업 — 1주차 루프: 웹(letter-app)·Android(Mutter_android) 구현 + TestFlight (2026-09-16)

사용자가 두 저장소 접근을 열어 이 세션에서 직접 구현. 스펙: `marketing/plans/2026-09-16-week1-loop-spec.md`. 웹은 Vercel(live) + Vite SPA → 크롤러 UA 조건부 rewrite로 Edge Function 분기.

- [x] TestFlight: 1.0.3 트레인 마감(90186) → 1.0.4 버전업 커밋(7d055e3) → `fastlane beta` 재실행 → **1.0.4 빌드 8 업로드 성공**
- [x] TestFlight 미노출 원인: 빌드 8은 VALID·규정준수 OK·READY_FOR_BETA_TESTING인데 내부 그룹 `내부테스팅` 테스터 0명 → `tf_add_tester`로 dkehskeh@gmail.com 추가(17:51) · 레인 커밋 1958c4f · lessons.md 기록
- [x] 웹 L1: `index.html` 기본 OG · `supabase/migrations` `get_letter_preview` RPC(본문 없이 template_id·sealed) · `api/letter-preview.ts` Edge Function · `vercel.json` UA 조건 rewrite · `scripts/gen-og-envelopes.mjs`(Playwright) → `public/og/*.png` 8장
- [x] 웹 L3: `src/lib/storeLinks.ts`(ct/referrer) · `src/lib/campaign.ts`(utm→ct) · `src/lib/analytics.ts`(no-op track) · `src/components/StoreButtons.tsx`(Download에서 추출) · `src/features/viewer/LetterEndCta.tsx` 3단 + 워드마크 · LetterView 통합
- [x] 웹 랜딩: Landing 히어로 한 줄 A + 스토어 버튼(utm→ct) · ConnectStorePrompt `ct=connect_invite`
- [x] 웹 검증: typecheck ✔ · lint 0 에러 · vitest 307/307(신규 21: ogPreview 9·campaign 4·storeLinks 3·LetterEndCta 5) · build ✔ · OG PNG 9장 생성(1200×630)
- [x] Android L2: `domain/LetterShareMessage.kt` + `:domain` junit 테스트 · `uicomponent/component/ShareSheet.kt`(ACTION_SEND) · Compose `issuedLink: DeliveryLink?` + SendSheet 공유 1순위 · Delivery `lastIssuedLink` + 행 공유
- [x] Android 검증: `JAVA_HOME=openjdk@17 ./gradlew :domain:test assembleDebug` — BUILD SUCCESSFUL, 5/5
- [x] critic 독립 리뷰 — Android(Critical 0 / Major 1 수용 / Minor m1·m2·m4 반영) → **Android 3a25505** · 웹(Critical 1 og:image 절대 URL / Major 1 44px / Minor m1·m3·m4·m6 반영, m2 스펙 명시) → **웹 e3bbe60**
- [x] 리뷰 섹션 기록

### 리뷰 (2026-09-16, 다중 저장소)

- TestFlight: 1.0.4 빌드 8 업로드(15:14) → 처리 VALID·규정준수 OK였으나 내부 그룹 테스터 0명 → `tf_add_tester`로 계정 소유자 추가(17:51). Fastfile에 `tf_status`·`tf_add_tester` 신설(1958c4f).
- Android(3a25505): 공유 시트 + 동봉 문구, `:domain` junit 5/5, assembleDebug 통과. Connections 초대 공유도 `shareText`로 통합. 후속: 좁은 화면(320dp)에서 기존 링크 행 3버튼 확인.
- 웹(e3bbe60): OG(Edge Function + `get_letter_preview` RPC + 봉투 9장) · 마지막 장 CTA 3단 · 캠페인 링크 · 랜딩 한 줄 A. vitest 308/308.
- **배포 필요(사용자)**: 세 저장소 `git push` · Supabase `supabase db push`(0033) · Vercel 배포 후 카카오 공유 디버거로 `/l/<token>` 카드 확인 · Vercel env `VITE_ASC_PROVIDER_ID`(선택).
- 미결(사용자): 커스텀 도메인 · OG 닉네임 노출 정책 · 브랜드 액센트 색 · 웹 애널리틱스 도구(2~3주차).

## 이전 작업 — 1주차 루프: iOS 공유 시트·동봉 문구 + 웹·Android 실행 스펙 (2026-09-16)

플랜: `~/.claude/plans/mossy-wiggling-perlis.md`. 채널 전략 1주차(L1·L2·L3) 중 iOS L2만 이 세션에서 구현, 웹·Android는 각 저장소 세션용 자급형 스펙(`marketing/plans/2026-09-16-week1-loop-spec.md`).

- [x] `UIComponent/Sources/Share/LetterShareMessage.swift` (순수 헬퍼, L10n 조합)
- [x] Localizable.strings ko·en: `send.share`, `share.letter.body/password/revealAt`
- [x] Compose: `issuedLink: DeliveryLink?` + `issuedLinkURL`, SendSheet CTA 3단(공유·복사·완료)
- [x] Delivery: `lastIssuedLink: DeliveryLink?`, issuedLink/existingLinks 행에 ShareLink 아이콘
- [x] `UIComponent/Tests/LetterShareMessageTests.swift` 5케이스
- [x] `tuist generate` → `tuist build Mutter`(Build Succeeded) → `tuist test UIComponent`(6/6, 신규 5) → `/arch-check`(신규 위반 0 — 발견 항목은 기존 Auth 콜백·UIKit import·SendSheet `Method.allCases`)
- [x] 스펙 문서 `marketing/plans/2026-09-16-week1-loop-spec.md` (§0 공통 문구·스토어 URL·토큰표 / §1 웹 OG / §2 웹 CTA 3단 / §3 랜딩 / §4 이벤트 / §5 Android ACTION_SEND / §6 수용 기준)
- [x] `critic` 독립 리뷰 — Critical 0 / Major 1(스펙: iMessage는 서버 크롤러 없음) / Minor 7 → 8건 전부 반영(접근성 라벨, `pt` 순서, `%1$s` 각주, RPC 실명 `get_letter_by_token`, save_to_inbox 확인 필요, 암호 유무 문구, todo 카운트) → 재빌드 Build Succeeded
- [x] 커밋 2개 — c4fc890(feat 공유 시트) · 746bbea(docs 채널 전략+1주차 스펙)
- [x] 리뷰 섹션 기록

### 리뷰 (2026-09-16)

- iOS L2 완료: `LetterShareMessage`(UIComponent, Foundation만 import, 값 인자만) + ko/en 문자열 4개 + Compose `issuedLink: DeliveryLink?`/`issuedLinkURL` + SendSheet CTA 3단(공유 ShareLink → 복사 secondary → 완료 ghost) + Delivery `lastIssuedLink` + 발급/기존 링크 행 ShareLink 아이콘(접근성 라벨 포함). ShareLink item은 String(URL 타입이면 동봉 문구가 빠짐).
- 검증: `tuist generate`(L10n 심볼 생성 확인) · `tuist build Mutter` Build Succeeded(2회) · `tuist test UIComponent` 6/6(신규 5) · `/arch-check` 신규 위반 0.
- 웹·Android는 저장소 접근 불가(하네스가 cwd 밖 차단, 샌드박스 해제로도 불가) → 사용자 선택으로 자급형 스펙 `marketing/plans/2026-09-16-week1-loop-spec.md` 작성. 각 저장소 세션에서 `/add-dir /Users/choesuhun/Desktop/Code/Mutter` 후 §1~§5 실행.
- 미해결(사용자): 커스텀 도메인 · Android applicationId 확인 · App Store `pt` · OG 닉네임 노출 정책 · 웹 호스팅(Vercel/Netlify)·SSR 여부 · 웹 애널리틱스 도구 · 브랜드 액센트 색.
- 수동 확인 권장: 시뮬레이터에서 편지 저장 → 보내기 시트 → 링크 발급 → 공유하기 → 메시지 앱에 3줄+빈 줄+URL 순서, 암호 ON 시 암호 줄 포함. 전달 관리 화면에서 예약공개 발급 → "…에 열려요" 포함.

## 이전 작업 — 마케팅 에이전트 + 영상 프롬프팅 에이전트 구축 (2026-09-16)

플랜: `~/.claude/plans/mossy-wiggling-perlis.md`. 서드파티 스킬은 전역(-g) 선별 설치, 에이전트는 프로젝트 `.claude/agents/`, 공유 컨텍스트는 `.agents/product-marketing.md`(marketingskills 정본 경로), 산출물은 `marketing/`.

- [x] 사전 준비: `brew install ffmpeg` (Hyperframes 렌더) — ffmpeg 9.0.1
- [x] 전역 스킬 설치: marketingskills 19개 서브셋 · replicate prompt-videos · square-zero video-prompting · app-store-screenshots · aso-skills(40개 중 14개만 유지, 25개 제거 — 세션 컨텍스트 절약)
- [x] 공식 플러그인 설치: `hyperframes@claude-plugins-official`
- [x] `.agents/product-marketing.md` v1 (docs/appstore-submission.md·specs·Colors.xcassets 기반, 추정은 `[확인 필요]`)
- [x] `.claude/agents/mutter-marketer.md`
- [x] `.claude/agents/mutter-video-director.md` (skills 프리로드: prompt-videos, video-prompting)
- [x] `.claude/commands/marketing.md` · `.claude/commands/video-prompt.md`
- [x] `CLAUDE.md` 커맨드 표 2행 + 마케팅·영상 에이전트 절 · `.gitignore` marketing 렌더 산출물
- [x] 검증: 설치 확인 · 스모크 1(마케터 → `marketing/copy/2026-09-16-one-liner-subtitle.md`, copywriting+metadata-optimization, iTunes API 32건) · 스모크 2(비디오 → `marketing/video/2026-09-16-teaser-reels/` 5샷 Veo 프롬프트, AUDIO/NEGATIVE/스타일 블록 전부 포함) · 스모크 3(`hyperframes init/check` — ffmpeg·Chrome GPU 인식; Layout 1건은 빈 예제의 타임라인 부재) · 새 프로세스 `claude -p --agent` 프로브(본문 주입 ✔, `skills:` 프리로드 ✗ → 본문에 Skill 로드 가드 추가)
- [x] `critic` 독립 리뷰 — Major 2(카테고리 예외·스킬 3개 제한 stall) Minor 3 중 4건 반영, m3(`--skill` 플래그)는 `init --help`·플러그인 스킬 본문으로 존재 확인해 기각
- [x] `/commit` — 5849459(에이전트 인프라) · 3e40dc0(첫 산출물)
- [x] 리뷰 섹션 기록

### 리뷰 (2026-09-16)

- 설치: 전역 스킬 33개(marketingskills 19 · aso-skills 14 · prompt-videos · video-prompting · app-store-screenshots) + `hyperframes@claude-plugins-official` 0.8.40 + ffmpeg 9.0.1. aso-skills는 40개 중 25개 제거(세션 컨텍스트 절약).
- 신규 파일: `.claude/agents/mutter-marketer.md`, `.claude/agents/mutter-video-director.md`, `.claude/commands/{marketing,video-prompt}.md`, `.agents/product-marketing.md`(v1), `marketing/README.md`. 수정: `CLAUDE.md`(커맨드 2행 + 에이전트 절), `.gitignore`.
- 스모크 산출물은 실제 사용 가능한 1차 결과물이라 커밋에 포함(카피 3+2안, 릴스 티저 5샷).
- 확인된 한계: (1) 세션 중 설치한 플러그인 스킬(`hyperframes:*`)은 그 세션의 서브에이전트에 안 보임 → 새 세션 필요. (2) frontmatter `skills:` 프리로드가 `--agent` 경로에서 미적용(2.1.271) → 에이전트 본문 가드로 보완. (3) 백그라운드 Explore 보고 릴레이 2회 실패 → 직접 읽기로 전환(기존 메모리 규칙 재확인).
- 사용자 결정 대기: 브랜드 액센트(토큰명 Gold, 실값 모브 핑크 `#C77BAE`) · 부제 교체 여부(마케터 추천 A안) · `고백편지` 순위 표기(문서 3위 vs 이번 검증 1위) · 커스텀 도메인 `mutter.app` 상태.

## 이전 작업 — 양 플랫폼 스토어 업데이트 업로드

사전 확인: iOS 라이브 1.0.2(iTunes lookup) → 1.0.3 필요 · Android Play 게시됨(HEAD vc=1, 워킹트리 vc=2 미커밋) → vc=3 안전.
iOS fastlane release 레인 + .env.default(ASC 키, gitignore) + homebrew fastlane. Android는 Play API 자격증명 없음 → AAB 빌드 후 콘솔 업로드.

- [x] iOS: MarketingVersion 1.0.2→1.0.3, 스와이프 삭제+버전업 커밋 (dd38b02, 0d138cb)
- [x] iOS: `fastlane authcheck` AUTH OK → `fastlane release` — **1.0.3(빌드 7) ASC 업로드 성공** ("Successfully uploaded package")
- [x] Android: WIP 주제별 커밋 5건(OAuth 픽스·FCM 푸시+R8·정책 화면·docs·스와이프 삭제) + 버전업(dbc4e12, vc3/1.1.0)
- [x] Android: `:app:bundleRelease`+`assembleRelease` BUILD SUCCESSFUL — AAB 16M, badging `versionCode=3 versionName=1.1.0` 확인
- [x] Android: 릴리스(R8) APK 에뮬레이터 스모크 — FATAL 0, 프로세스 생존, 로그인 화면 정상 렌더(스크린샷)
- [x] Play Console 업로드는 수동 필요(Play API 자격증명·Chrome 연동 없음) — AAB 경로+절차 전달
- [x] 릴리스 노트 초안 작성(아래 최종 보고)

### 남은 일 (사용자)
- ASC: 1.0.3 버전 생성 → What's New 입력 → 빌드 7 선택 → 심사 제출 (또는 `fastlane submit`)
- Play Console: app-release.aab 업로드 + 릴리스 노트 + **데이터 보안 설문에 '기기 ID(FCM 푸시 토큰)' 추가**(푸시 신규 탑재)

## 이전 작업 — 받은편지함 스와이프 삭제 (iOS + Android)

백엔드 변경 불필요: `inbox` 테이블 RLS `inbox_self_rw`(for all)가 본인 행 DELETE 허용,
`letters` 직접 delete 전례(iOS/Android 모두)와 동일 패턴으로 `from("inbox").delete().eq("letter_id", …)`.

### iOS (Mutter)
- [x] Domain: `InboxRepositorable`·`InboxUsecasable`에 `remove(letterId:)` 추가, `InboxUsecase` 구현
- [x] Infrastructure: `InboxRepository.remove` — `from("inbox").delete().eq("letter_id")`
- [x] Feature/Inbox: `InboxModelData.delete(_:)` — 낙관적 제거 + 실패 시 롤백
- [x] `InboxView`: 목록 분기를 `List` + `.swipeActions`(trailing, full swipe)로 전환 — 카드 스타일 유지
- [x] 빌드 검증 (`mise exec -- tuist build Mutter` → ✔ Success, exit 0)

### Android (Mutter_android)
- [x] domain: `InboxRepository.remove` + `InboxUseCase.remove`
- [x] data: `InboxRepositoryImpl.remove` — `postgrest.from("inbox").delete { eq("letter_id") }`
- [x] feature/inbox: `InboxViewModel.delete` (낙관적 제거+롤백) + `SwipeToDismissBox`(EndToStart, Danger 배경+trash 아이콘)
- [x] 빌드 검증 (JDK17 gradlew assembleDebug → BUILD SUCCESSFUL, exit 0)

### 문서
- [x] `docs/specs/module-architecture.md` 테이블 직접 접근 목록에 `inbox`(delete) 반영

### 리뷰 (받은편지함 스와이프 삭제)
- 변경: iOS 6파일(Domain 3·Infra 1·Feature 2) + Android 5파일(domain 2·data 1·feature 2) + 설계문서 1줄.
- 백엔드 무변경 — `inbox` RLS `inbox_self_rw`(for all)로 본인 행 delete, `letters` 직접 delete 전례와 동일 패턴.
- UI: iOS `List`+`.swipeActions`(trailing, full swipe, 삭제 라벨) / Android `SwipeToDismissBox`(EndToStart, Danger 배경+trash, `animateItem`).
- 독립 리뷰(code-reviewer) 결과 Major 1건 — 전체 스냅샷 롤백이 연속 삭제 레이스에서 다른 항목까지 부활시킴 → 항목 단위 롤백(제거 항목+인덱스만 캡처)으로 양쪽 수정.
- 검증: iOS `mise exec -- tuist build Mutter` ✔ Success·exit 0, Android `gradlew assembleDebug` BUILD SUCCESSFUL·exit 0 (레이스 수정 후 재빌드 포함).

## 이전 작업 — 무계정 수신자: 가입하면 받은 편지/연결이 이어지게 (pending 경로 복귀)

핵심 근본: 웹 로그인이 코드/가입 시 `/set-nickname`→홈으로 가 원래 경로(`state.from`)를 버림.
이걸 고치면 연결하기·편지저장 둘 다 "링크 열다 가입 → 그 링크로 복귀"가 완성된다.

### 웹 (letter-app)
- [ ] `Login.tsx handleVerifyCode`: `/set-nickname`으로 갈 때 `state.from` 전달
- [ ] `SetNickname.tsx`: 저장 후 `from`(있으면)으로 복귀, 없으면 `/welcome`
- [ ] `SaveToInboxButton.tsx`: 비로그인 수신자에게 "가입하고 받은 편지함에 저장" CTA → `/login`(from=현재 편지 링크). 로그인 복귀 시 서버가 열람 자동저장(0022)
- [ ] typecheck + 전체 테스트

### 앱 (Mutter) — pending 편지 토큰 소비 (phase 2)
- [ ] 미인증 뷰어에 "가입하고 보관" CTA (Viewer 피처에 옵션 콜백)
- [ ] `MainView`: 로그인 완료 시 pending 편지 토큰을 인증 뷰어로 열어 자동저장(pendingConnectToken 패턴)
- [ ] `tuist build`

## 리뷰(직전 작업: 연결 N:N 전환)
- DB 0027 + 앱/웹 N:N 전환 완료. 앱 `tuist build` OK, 웹 242/242. 배포는 `supabase db push`(0027) 필요.
- 보안: GoogleService-Info.plist 히스토리에서 filter-branch로 제거(로컬 완료), force-push는 사용자 실행 대기.

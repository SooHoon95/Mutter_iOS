# tasks/todo.md

## 현재 작업 — 마케팅 에이전트 + 영상 프롬프팅 에이전트 구축 (2026-09-16)

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
- [ ] `/commit`
- [ ] 리뷰 섹션 기록

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

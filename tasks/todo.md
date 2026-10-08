# tasks/todo.md

> 끝난 작업은 `tasks/archive/`로 옮긴다(`mutter-harness-ops`). 2026-09 이전 작업은 `tasks/archive/todo-2026-09.md`.

## 현재 작업 — 하네스 afin-ios 구조 정합 (iOS·Android) (2026-10-08)

- [x] afin-ios 하네스 구조 조사(CLAUDE.md 원칙 7절·`.claude/CLAUDE.md` OMC·`<프로젝트>-*` 통합 스킬·harness-ops·release-audit·tasks/archive)
- [x] Mutter 스킬 10개 → 8개(`mutter-*` + omc-reference)로 통합, 실제 코드와 다른 사실 교정
- [x] Mutter CLAUDE.md afin 구조로 재작성(마케팅 에이전트 절 유지), 커맨드 참조 갱신, `/release-audit` 이식
- [x] tasks/ 정리(todo·lessons 아카이브)
- [x] Mutter_android 하네스 신규 구축(CLAUDE.md·스킬·커맨드·tasks)
- [x] 정적 검증(frontmatter·dangling 참조) + 런타임 검증(`claude -p` 스킬 노출·트리거) + 빌드 명령 실행 확인

### 리뷰
- 실제 코드와 달랐던 기존 스킬 사실 교정: `.alert(error:)`(존재 안 함 → `errorMessage` + `MutterError.userMessage`), usecase 컨테이너 등록(실제는 호출부 생성자 주입), `AppRoute/AuthRoute` 중심 설명(실제 `FeatureRoute`, Feature View는 콜백), `.mutterTitle()`(실제 `.fonts(...)`), 맨 `tuist`(실제 `mise exec -- tuist`), `/new-ios-screen` 템플릿.
- 정적: 스킬 8개 name=디렉터리, dangling 0(남은 경고는 `.claude/agents` 에이전트명·OMC 플러그인 커맨드 — 의도된 것).
- `claude -p` init: 프로젝트 스킬 7개·커맨드 13개 로드. 트리거 4건(네트워킹 2·SwiftUI·CI/CD) 모두 기대 스킬 로드. afin-ios와 동일하게 SKILL.md를 직접 읽는다.
- 빌드: `mise exec -- tuist generate --no-open` 1회 실패 후 재시도 통과(문서화한 간헐 오류와 일치, 원인 로그는 덮어써져 미확인) → `tuist build Mutter` Build Succeeded. 마케팅 라우팅 훅 exit 2 차단 정상.
- 미반영: Codex 사본(`AGENTS.md`·미추적 `.agents/skills/ios-*`)은 옛 스킬 이름 그대로.

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
- [x] 실제 편지 링크로 테마 봉투 카드·뷰어 확인 — 사용자 확인 "제대로 된다"(2026-10-07)

## 현재 작업 — 2026-10-07 주간 마케팅 루프
- [x] 제품 사실·신선도·수집 데이터·행동 조건 확인
- [x] 블로그 키워드 플랜 위임 → 카피라이터에게 Threads 2편·블로그 1편 통합 위임
- [x] 월간 AI 검색 점검·리포트·허용된 state 필드 갱신
- [x] 초안·리포트·state 검증 및 결과 기록

### 리뷰 — 2026-10-07 주간 마케팅 루프
- 생성: 리포트 1·웹 키워드 플랜 1·승인 대기 Threads 2·블로그 1. 시즌 초안 중복 생성 없음.
- 검증: 큐 status=draft·대안/추천·기능 출처 확인, Threads 각 안 500자 이내, 리포트 파일 참조 존재 확인. state 비교 결과 handled·cooldowns만 변경. 순위 하락·경쟁 해시 변화·리뷰 조건 미충족 확인.
- 제한: 2주 순위 이력 부족, 검색 결과 관찰은 AI 답변 추천율 측정이 아님. 블로그는 사람의 사례·사진 보강 후 승인. 발행·스토어 변경·커밋 없음.

## 현재 작업 — 2026-10-07 콘텐츠 마케팅 운영안
- [x] 컨텍스트·신선도·기존 큐·루프 조건 확인
- [x] 주 3시간 예산·4주 캘린더·측정 및 루프 통합 작성
- [x] 카피라이터 1주차 큐 4편 및 영상 핸드오프 브리프 작성
- [x] 날짜·예산·큐 상태·제품 사실·참조 검증

### 리뷰 — 콘텐츠 마케팅 운영안
- 계획 1·1주차 승인 큐 4·영상 브리프 1 작성. 릴스 각각 16초로 통일, 제작과 발행 시간 중복 제거.
- 검증: 큐 draft/대안 2개·Threads 각 안 500자 이내, 주간 예산 165/175/180분, 블로그 14일 간격과 월 2편 연결 확인.
- 기존 자동 루프와 수동 요청·미구현 계측 구분. 발행·스토어 변경·커밋 없음. 렌더 제작은 별도 핸드오프.

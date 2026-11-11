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

## 현재 작업 — 자동발행 외부 설정 점검 (2026-10-10)

범위: 기존 승인 후 자동발행 계획의 Meta·Supabase·랜딩 준비. 게시·스케줄 활성화·코드 구현은 별도 확인 후 진행.
- [x] 저장소 자동화와 환경변수 설정 상태 확인(값 출력 없이)
- [x] Meta 사용 사례·필요 권한 8개 준비. 사용자 지정 전용 계정 mu_sic_letter로 두 테스터 등록·초대 수락·토큰 발급 완료. Threads/Instagram /me 읽기 호출로 계정 검증
- [x] Supabase marketing-media 공개 버킷 생성·Public 상태 확인. service_role 프로젝트·역할 확인 후 로컬 및 Vault 저장. 버킷 읽기 API HTTP 200·public=true 검증
- [x] 비로그인 랜딩·App Store/Google Play 설치 링크·로그인 진입 확인. LANDING_URL에 상시 Instagram 프로필 UTM 저장
- [x] 남은 클립·발행 구현 단계와 검증 결과 기록
- [ ] [blocked] 원본 클립 6개 없음. 사용자 제공/녹화 필요. 실제 설치·로그인·작성 전체 동선은 미검증
- [x] 카드 렌더/승인 예약/토큰 갱신 스크립트와 Mac 설치 스크립트는 아래 후속 구현에서 완료. 영상 렌더와 실제 Mac 등록·발행은 별도 보류

### 중간 검증 — 외부 설정
- Threads API 사용 사례 기등록. 토큰 생성기 'No testers available'. Instagram 메시지 권한 일괄 추가는 사용하지 않고 필요한 4개만 선택.
- .env.marketing 14개 설정값 저장: 기존 12개 + Instagram 전용 IG_APP_ID·IG_APP_SECRET. 파일 권한 600·gitignore 확인, 시크릿/토큰은 출력 없이 저장·Vault 보관. 실제 게시·스케줄 활성화 없음.
- 일반 계정에서 공개 비즈니스 계정으로 전환은 사용자 명시 승인 후 진행. 카테고리 제품/서비스, 연락처 사용 안 함. Threads와 Instagram OAuth에서 불필요한 답글 관리·DM 권한 제외.
- Mac pmset: AC sleep=0, 배터리 sleep=1. 예약 시 전원 연결 권장, 수동 잠자기·덮개 닫음·전원 종료까지 보장하지 않음.
- 공개 랜딩 설치 링크: iOS id6790086549, Android com.efreedom.mutter. 로그인 화면 진입 정상. 실제 설치·로그인·작성은 검증하지 않음.

## 현재 작업 — 승인 후 소셜 예약 발행 구현 (2026-10-10)

사용자 '하던거 계속 해'로 Threads 글+Instagram 이미지 카드 구현을 이어감. 기존 초안 생성은 재사용하고 실제 테스트 게시 전 확인.
- [x] 기존 승인 큐 계약·공식 API 확인
- [x] 승인 내용·시간·이미지 해시를 고정한 JSON 작업 및 실행 상태 분리
- [x] 한글 카드 렌더·공개 미디어 업로드·토큰 만료 검사/갱신·두 채널 발행 구현
- [x] 실패/모호한 게시 결과는 수동 확인 상태로 격리, 중복·밀린 게시 폭주 방지
- [x] 단위 테스트·읽기 API·dry-run·독립 리뷰
- [x] /marketing-approve 연결 및 Mac launchd 설치 방법·생성 plist/wrapper 문법 검증
- [x] 실제 LaunchAgent 등록/Terminal 진입점 확인(2026-10-11). 사용자가 실제 Terminal에서 설치 후 launchctl print로 등록·300초 간격·20:30 타이머 확인. 중지 마커 유지한 1회 kickstart: exit 0, 로컬 로그 disabled. 자동 발행 활성화는 여전히 별도 승인 필요
- [ ] [blocked] 원본 클립 6개 없는 영상은 사용자 녹화/제공 필요. 실제 업로드·컨테이너·발행은 별도 명시 승인 전까지 미실행

### 리뷰 — 승인 후 소셜 예약 발행 구현
- 생성 루프: Threads 2 + Instagram 카드 1 기본, 클립/영상 검수 전 릴스 대신 카드. 주차·브리프·슬롯 기준 중복 제어. .claude 원본 수정 후 Codex 사본 생성.
- 실행: SocialAPI/승인 스냅샷/실행 원장/한글 카드/토큰 갱신/명시 승인 CLI/Mac 설치 스크립트. 기본 dry-run, CLI 대상 @mu_sic_letter만 허용. PUBLISH_DISABLED 현재 존재, 승인 job 0개.
- 검증: unittest 87개 통과, Python compile·zsh syntax·git diff --check 통과. 한글 명조 JPEG 실제 렌더 1080×1350 RGB/125,513 bytes 시각 확인. 임시 디렉터리에서 생성 plist/Terminal wrapper 문법 검증(실제 등록 아님).
- 읽기 API: Threads /me id=28831850349833395, Instagram /me user_id=17841426222007655, 둘 다 username=mu_sic_letter. 토큰 값/서비스키 출력 없음. 무승인 dry-run [] 및 disabled --live 네트워크 없는 종료 확인.
- 독립 리뷰: 별도 에이전트 2패스. HIGH 2(미확정 게시 후 다른 작업 허용, 재설치 pause 시점), MEDIUM 4(pause intent 경쟁, 큐 표시 쓰기 실패, 초안 중복 범위, 테스트 누락), LOW 2(env fsync, 오류 창 누적) 모두 코드/회귀 테스트 반영. 추가 MEDIUM 복구 문서도 old uncertain을 사용자 대조 후 cancelled/published로 수동 확정하도록 보완.
- 한계: 모의 API 테스트는 실제 게시 성공/개발 모드 publishing 권한을 증명하지 않음. 실제 업로드/게시/토큰 갱신 API·앱 전체 설치/로그인/작성은 미검증. Mac 예약은 2026-10-11 실제 등록·중지 상태 진입점 검사 완료. 커밋/실게시/발행 활성화 없음. CLI/Vault 토큰 갱신은 분리돼 env가 최신 정본.

## 현재 작업 — 소셜 첫 주 승인 프리뷰 (2026-10-11)

사용자 '엉 계속해': 게시물/시간 검수·승인 단계 진행. 실제 게시/발행 활성화 승인이 아님.
- [x] 과거 한글날 콘텐츠 제외, 상시 Threads 2편과 카드 1편 사실·미래 일정 검수
- [x] 기존 릴스 첫 줄 콘텐츠를 별도 Instagram 카드 초안으로 전환, 로컬 이미지·프리뷰 해시 생성
- [ ] 전체 본문/이미지/@mu_sic_letter/시각 표시 후 명시 승인 대기. PUBLISH_DISABLED 유지

### 검증 — 첫 주 프리뷰
- 제안: Instagram 카드 10/12 20:30, Threads 10/13·10/17 20:30 KST. 기존 미래 Threads 추천안 그대로, 릴스는 별도 카드로 재사용하고 영상 게시 승인은 아님.
- 카드 시각 확인: JPEG 1080×1350 RGB, 명조 한글/여백/문장 누락 없음. 캡션 91자·해시태그 4개, Threads 330/363자. 계정 mu_sic_letter·미래 시각·프리뷰 SHA 생성 확인.
- 좁은 독립 카피 검수: 기능 근거·가상 예시·금지어·글자수·미래 날짜 통과. 컨텍스트 이후 새 기능 커밋 c3d630b는 확인했으나 이번 카피에 신규 기능/순위/평점 주장 없음.
- 이미지 저장: /Users/choesuhun/Downloads/aside/mutter-instagram-card-2026-10-12.jpg 및 세션 artifacts 사본. 공개 업로드/승인 job 등록/발행 활성화/실제 게시 없음.

## 현재 작업 — 15초 모션 릴스 제작·발행 경로 (2026-10-11)

사용자 '엉 그렇게': 원본 녹화 없이 15초 모션 릴스 시안 및 릴스 자동발행 지원 구현. 실제 게시·발행 활성화는 미승인.
- [x] 공식 Instagram Login Reels 계약·렌더링 도구 확인
- [x] 세로 1080×1920/15초 모션 MP4 실제 렌더. native FFmpeg/Terminal 실패를 독립 브라우저 WebCodecs+Mediabunny 경로로 해결. 실제 450frame·AAC 무음 MP4 생성, 사용자 Terminal 실행 불필요
- [x] 릴스 승인 스냅샷·고정 MP4 업로드·컨테이너·발행 경로 추가, 기존 안전장치 유지
- [x] 오프라인 테스트·실제 MP4 전체 디코드/MP4 물리 구조/SHA·native 플레이어 중간/마지막 장면 검증·독립 리뷰·승인 job 0·실제 MP4 승인 프리뷰 생성
- [ ] 완성 MP4·캡션·대상·미래 시각 표시 후 사용자 승인 대기. 이미지 카드 제안은 보류, PUBLISH_DISABLED 유지

### 리뷰 — 모션 릴스 구현
- 로컬 render_reel: 종이·명조·모브 핑크·페이드/미세 모션, 고정 5장면/15초/30fps/H264/AAC 무음/+faststart. 실제 앱 UI/라이선스 음원 재현 없음. 현재 고정 문구이므로 매주 새 콘텐츠 자동 생성으로 과장하지 않는다.
- API: upload_video <=45MiB, 불변 SHA 객체/충돌 바이트 비교, create_reel(REELS/video_url/caption/share_to_feed=true), 동일 Instagram status/publish. 이미지/Threads 유지, 둘 다 같은 Instagram 하루 한도·uncertain 전체 채널 보류 적용.
- 검증: 155개 실행, 154 PASS/네이티브 인코더 1 SKIP. Python compile/zsh syntax/git diff --check 통과. 별도 독립 리뷰 MEDIUM 2(해시 전에 초과 크기 읽기, probe 외부 프로토콜), LOW 1(helper 자식 누수) 수정·재검토 완료. SHA는 streaming cap, copy는limit+1; MOV demuxer/file,pipe 제한; helper subprocess 제거.
- 실제 모션 디자인 미리보기 GIF(PIL): 540×960·120frame·14.4초(15초 MP4와 다른 샘플 미리보기), /Users/choesuhun/Downloads/aside/mutter-motion-first-line-preview-2026-10-11.gif 및 session artifacts. 5장면 한글/안전 여백 시각 확인. GIF는 Instagram 게시 asset이 아님.
- 로컬 Terminal 전용 render-motion-reel.command 준비: 네이티브 smoke·전체 MP4·450frame probe·승인 프리뷰만 작성, 게시 API 없음. 사용자 Terminal 실행 후 render-status/metadata/실파일을 2분 간격 최대1시간 확인하고 결과 전달하는 루틴 등록.
- 후속 해결: 실제 MP4 4,457,200bytes(SHA d22352031129d39b9ef8d46ad92ce83737db6d607c41f408f5762bd1561a0458) 생성. 새 Mediabunny 입력에서 450프레임/707 AAC 샘플 전체 디코드; 영상 트랙15초, AAC 패딩 포함 파일15.083초. reel_validation.py의 bounded MP4/SPS/AAC/샘플테이블로 1080×1920/30fps/8bit420/progressive/faststart 실제 물리 검증. SHA 결합 trusted same-user 브라우저 decode cache를 native fallback 앞에 연결. 새 경로 독립 리뷰 APPROVE/CRITICAL·HIGH·MEDIUM 없음. 170개 실행169PASS/native1SKIP.
- 사용자 출력: /Users/choesuhun/Downloads/aside/mutter-motion-reel-2026-10-12.mp4 및 session artifacts. 실제 플레이어 5초·14초 seek/장면 확인. Native 실제 인코더는 여전히 미사용이며 브라우저 독립 경로가 실제 산출물·검증을 제공한다.
- 사용자 교정: 인코더 한 경로 실패를 전체 작업 중단으로 취급해 수동 명령을 넘긴 오류를 lessons.md에 기록하고 작업 재개로 교정. 이전 Terminal 대기 루틴은 해결됐으므로 paused.
- 여전히 미검증/미실행: 실제 영상 공개 업로드·Meta 컨테이너/게시. 사용자 최종 영상 승인 미수신, 승인 job0·PUBLISH_DISABLED 유지·커밋 없음.

## 현재 작업 — 2026-10-12 주간 마케팅 루프
- [x] 제품 신선도·수집 데이터·행동 조건 확인
- [x] 경쟁 버전 변화 분석과 주간 소셜 3편 위임
- [x] 리포트·허용 state 필드 갱신
- [x] 초안·상태 보존·파일 참조 검증

### 리뷰 — 2026-10-12 주간 마케팅 루프
- 생성: 경쟁 분석 1·승인 대기 Threads 2·카드 텍스트 1·주간 리포트 1.
- 검증: 독립 ASO 에이전트 리포트 대조 오류 없음; 큐 draft/슬롯/길이/금지어·기능 출처 확인, 파일 참조 존재, state 운영 필드 전부 보존. handled에 경쟁 키·사용 문장 3개 추가, cooldown 유지.
- 카드 이미지는 승인 준비 단계에서 렌더·검수 필요. 발행·스토어 변경·커밋 없음.

## 현재 작업 — 2026-10-19 주간 마케팅 루프
- [x] 제품 신선도·수집 데이터·조건 판정
- [x] ASO 통합 분석·상시 소셜 3편 위임 및 검수
- [x] 리포트·허용 state 필드 갱신 및 보존 검증

### 리뷰 — 2026-10-19 주간 마케팅 루프
- 생성: ASO 통합 분석 1·상시 승인 대기 소셜 3·주간 리포트 1. 두 실무 에이전트 각 1회 위임.
- 검증: 큐 상태·슬롯·대안·추천 이유·공개 본문 금지어·글자수·기능 출처 및 파일 참조 확인. state 운영 필드 전부 보존, handled·cooldowns만 갱신.
- 메타데이터 유지, 카드 실제 이미지 미생성. 발행·스토어 변경·커밋 없음.

## 현재 작업 — 2026-10-26 주간 마케팅 루프
- [x] 신선도·수집 데이터·행동 조건 확인
- [x] 경쟁 분석·시즌 블로그 키워드 플랜 위임
- [x] 시즌 초안 4편·블로그·인앱 이벤트 통합 위임
- [x] 리포트·state 허용 필드 갱신 및 검증

### 리뷰 — 2026-10-26 주간 마케팅 루프
- 생성: ASO 분석·블로그 키워드 플랜 각1, 시즌 승인 대기6편, 카드 PNG1, 주간 리포트1. 실무 에이전트 각1회 위임.
- 검증: ASO 분석가 독립 카피검수 문제0, 큐 draft·슬롯·대안·추천 이유·기능근거·금지어·길이 확인. 블로그3250자, 프로모션87자, Threads247/242자, 이벤트 모든안30/50/120 이내. 카드1080×1350 한글·잘림·본문일치 시각확인. 리포트 파일참조 존재 확인.
- state는 handled에 경쟁키·실제사용CL1문장, cooldown에 시즌60일만 추가. 전후 JSON 비교로 runs·last_run·consecutive_failures 등 나머지 전부 보존 확인.
- 인앱 이벤트는 시즌한정 경험·딥링크 미확인으로 등록 보류. 블로그 실제사례·사진 보강 및 발행은 사람 승인. 발행·스토어 변경·발송·커밋 없음.

## 현재 작업 — 2026-11-02 주간 마케팅 루프
- [x] 제품 신선도·입력 날짜·행동 조건 검증(verified_commit 이후 대상 커밋 0)
- [x] 수능 시즌 초안 5건 카피라이터 통합 위임·검수
- [x] 월간 AI 검색 4질문 점검·리포트 작성
- [x] state 허용 필드만 갱신·산출물 검증

### 리뷰 — 2026-11-02 주간 마케팅 루프
- 수능 큐 5건(draft)·리포트 1건 생성. 빼빼로데이·블로그·월간 ASO·평점 요청 조건별 중복/쿨다운 확인.
- 리드 별도 검수: 제품 주장 출처·카드 4섹션·대안 B/C·ID·글자수·리포트 파일 링크 확인. 이벤트 적격성은 사람 검토로 명시.
- state 실행 전 사본과 비교: handled/cooldowns만 변경, 수능 60일(2027-01-01)·11월 AI 검색 완료 기록. runs/last_run은 유지. 웹 검색 관찰과 AI 추천율 구분. 발행·스토어 변경·커밋 없음.

## 현재 작업 — 2026-11-09 주간 마케팅 루프
- [x] 제품 신선도·입력·행동 조건 확인(대상 후속 커밋 0)
- [x] 경쟁 분석·시즌 블로그 키워드 플랜 통합 위임
- [x] 상시 소셜 3편·블로그 1편 통합 위임 및 검수
- [x] 리포트·state 허용 필드 갱신 및 검증

### 리뷰 — 2026-11-09 주간 마케팅 루프
- 생성: ASO 분석·웹 키워드 플랜 각1, 승인 대기 큐4·카드 PNG1, 주간 리포트1. 실무 에이전트 각1회 위임.
- 검증: 리드 별도 카피 검수·제품 근거 대조·큐 draft/ID/길이/금지어 및 리포트 파일 링크 확인. Threads 각234자·블로그3237자, 카드1080×1350 시각 확인(카피라이터).
- state 전후 비교: handled에 경쟁2키·CL1키만 추가, cooldown 및 runs/last_run/consecutive_failures 등 보존. 발행·스토어 변경·발송·커밋 없음.

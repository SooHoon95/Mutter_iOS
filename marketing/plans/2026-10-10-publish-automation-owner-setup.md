# 자동발행 세팅 — 사용자 할 일 (2026-10-10)

결정: 승인 후 예약 자동발행 · 채널 Threads + Instagram(릴스·카드) · 소재는 문구 카드 + 템플릿 영상.
값은 모두 저장소 루트 `.env.marketing`(gitignore, 빈 템플릿 생성됨)에 넣는다. 채팅에 붙이지 않는다.

## 1. Instagram 계정 (10분)
- [ ] 뮤터 전용 인스타 계정을 **프로페셔널(크리에이터 또는 비즈니스)**로 전환 — 설정 → 계정 유형 및 도구
- [ ] 프로필 소개·링크 작성 (링크는 5번에서 정한 `LANDING_URL`)
- 페이스북 페이지 연결은 필요 없다(Instagram 로그인 방식 API 사용)

## 2. Threads 계정 (2분)
- [ ] 같은 인스타 계정으로 Threads 가입, 프로필 공개

## 3. Meta 개발자 앱 (20분)
- [ ] developers.facebook.com → 내 앱 → 앱 만들기 (유형: 비즈니스/기타)
- [ ] 사용 사례 **"Threads API 액세스"** 추가
  - 권한: `threads_basic`, `threads_content_publish`, `threads_manage_insights`, `threads_read_replies`
  - 앱 역할 → **Threads 테스터**에 본인 Threads 계정 추가 → Threads 앱 설정 → 계정 → 웹사이트 권한 → 초대 수락
  - 사용 사례 설정의 토큰 생성기로 사용자 토큰 발급 → `THREADS_ACCESS_TOKEN`, 사용자 ID → `THREADS_USER_ID`
  - Threads 앱 ID·시크릿 → `THREADS_APP_ID`, `THREADS_APP_SECRET`
- [ ] 사용 사례 **"Instagram API (Instagram 로그인)"** 추가
  - 권한: `instagram_business_basic`, `instagram_business_content_publish`, `instagram_business_manage_insights`, `instagram_business_manage_comments`
  - 앱 역할 → **Instagram 테스터**에 1번 계정 추가 → 인스타 웹 설정 → 앱 및 웹사이트 → 테스터 초대 수락
  - "API 설정 → 액세스 토큰 생성"에서 계정 연결 → 토큰 `IG_ACCESS_TOKEN`, 계정 ID `IG_USER_ID`
- [ ] 앱 ID·시크릿 → `META_APP_ID`, `META_APP_SECRET`
- 앱은 **개발 모드 그대로** 둔다. 본인 계정(역할 보유)에만 게시하므로 앱 검수 불필요.
- 단기 토큰을 넣어도 된다 — 첫 실행 때 스크립트가 60일 장기 토큰으로 바꾸고 이후 자동 갱신한다.

## 4. Supabase 미디어 버킷 (5분)
인스타는 영상·이미지를 공개 URL로만 받는다.
- [ ] Supabase 대시보드 → Storage → New bucket `marketing-media`, **Public** 체크
- [ ] Project Settings → API → URL → `SUPABASE_URL`, service_role 키 → `SUPABASE_SERVICE_ROLE_KEY`
  (로컬 업로드 스크립트만 쓴다. 앱·웹에는 절대 넣지 않는다)

## 5. 랜딩 링크 확인 (10분)
- [ ] 비로그인 상태로 `https://letter-app-nine-kohl.vercel.app` 열어서 소개 → 설치/작성 동선이 막힘없는지 직접 확인
- [ ] 프로필에 걸 URL 확정 → `LANDING_URL`
  (예: `...?utm_source=instagram&utm_medium=organic_social&utm_campaign=2026_pepero_content&utm_content=profile`)

## 6. 앱 화면 녹화 클립 (30분, 1회)
템플릿 영상이 재사용할 원본. 소리 끄고, 세로, 실제 개인 편지·실명 노출 없게.
저장 위치: `marketing/assets/clips/` (파일명 그대로)
- [ ] `write.mov` — 편지 본문 입력하는 장면 (5~8초)
- [ ] `theme.mov` — 테마(편지지) 고르는 장면
- [ ] `music.mov` — 음악 한 곡 선택 장면
- [ ] `preview.mov` — 완성 편지 미리보기 스크롤
- [ ] `web-receive.mov` — 브라우저에서 링크로 편지 여는 장면(앱 미설치 상태)
- [ ] `schedule.mov` — 예약 공개 날짜 선택 장면

## 7. Mac 운영 (확인만)
- [ ] 발행 시각(20:30 KST)에 Mac이 켜져 있고 잠자기 아님 — 시스템 설정 → 배터리/에너지에서 전원 연결 시 잠자기 방지
  (꺼져 있으면 다음 실행 시 밀린 예약분을 발행한다)

## 다 되면
"세팅 끝"이라고 알려주면 제가:
1. `.env.marketing` 키로 토큰 검증·장기 토큰 교환 (게시 없이 읽기 호출만)
2. 카드/영상 렌더 파이프라인, 예약 발행 스크립트, launchd 등록
3. `/marketing-approve`를 "승인 → 예약 등록"으로 변경
4. 테스트 게시 1건은 사용자 확인 후 실행

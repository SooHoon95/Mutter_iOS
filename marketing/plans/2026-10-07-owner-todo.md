# 사용자 할 일 목록 (2026-10-07 기준)

제가 대신할 수 없는 작업(계정·결제·스토어 콘솔·결정)만 모았다. 끝나면 체크하고 알려주면 이어서 자동화를 붙인다.

## 1. 급한 것 — 이번 주

| | 할 일 | 소요 | 마감 | 방법 | 끝나면 제가 하는 일 |
|---|---|---|---|---|---|
| [ ] | 한글날 프로모션 텍스트 승인 | 1분 | **10/8까지**(한글날 10/9) | `marketing/queue/2026-10-05-promo_text-hangul-day.md` 확인 → `/marketing-approve 2026-10-05-promo_text-hangul-day` | fastlane `promo_text`로 App Store에 반영 |
| [ ] | 한글날 스레드 2편·릴스 캡션 게시 | 10분 | 10/9 | `marketing/queue/2026-10-05-threads-hangul-day-1.md`, `-2.md`, `reel_caption-hangul-day.md` 본문 복사 → 직접 게시 → `/marketing-approve <id>`로 published 기록 | 큐 상태 갱신 |
| [ ] | Android 1.2.0 Play 제출 | 15분 | 가능한 빨리 | Play Console → 프로덕션 → 새 버전 → `Mutter_android/app/build/outputs/bundle/release/app-release.aab` 업로드 → 출시 노트 → 검토 제출 | 출시 후 컨텍스트 파일 버전 확인 |

## 2. 계정 연결 — 자동화를 여는 작업

| | 할 일 | 소요 | 방법 | 끝나면 제가 하는 일 |
|---|---|---|---|---|
| [ ] | 네이버 서치어드바이저 등록 | 5분 | searchadvisor.naver.com → 사이트 등록(웹 도메인) → HTML 메타 태그 소유 확인 코드 받기 → 저에게 전달 | 메타 태그 `index.html`에 넣고 배포, `sitemap.xml` 제출 안내 |
| [ ] | 네이버 검색광고 계정 생성 | 10분 | searchad.naver.com 가입(광고비 충전 불필요) → 도구 → API 사용 관리 → API 키·시크릿·고객 ID 발급 → `.env.marketing`에 저장 | 키워드 도구(월간 검색량) 수집을 주간 루프에 연결 |
| [ ] | 인스타그램 프로페셔널 계정 + Meta 개발자 앱 | 20분 | 인스타 계정을 비즈니스/크리에이터로 전환 → 페이스북 페이지 연결 → developers.facebook.com 앱 생성 → Instagram Graph API 추가 → 장기 액세스 토큰 발급 → `.env.marketing`에 저장 | 게시물 성과 수집, 댓글 답글 초안, (승인 시) 발행 |
| [ ] | 스레드 API 연결 | 10분 | 같은 Meta 앱에 Threads API 추가 → 토큰 발급 → `.env.marketing` | 스레드 성과 수집·발행 |

`.env.marketing`은 gitignore 대상이라 커밋되지 않는다. 키 값은 채팅에 붙이지 말고 파일에 직접 넣는다.

## 3. 결정 — 답만 주면 된다

| | 질문 | 선택지 | 제 권장 |
|---|---|---|---|
| [ ] | 주간 루프 모델을 Sonnet으로 바꿀까? | 유지(Opus) / Sonnet | Sonnet. 월 상한 8.6만~11.2만 원 → 1.7만~2.4만 원. 회귀 테스트 5건 통과 확인 후 전환 |
| [ ] | 추가 사용량(extra usage) 월 상한 | 금액 지정 | 3만 원. 루프가 폭주해도 이 이상 안 나간다 |
| [ ] | 유료 광고 예산 | 0원 / Apple Search Ads 월 N원 | 0원으로 시작. 리뷰가 생기고 평점 요청 기능이 들어간 뒤 검토 |
| [ ] | 참여 이벤트(경품) 1회 | 진행 / 보류 | 웹 `/test` 오픈 시점에 1회(약 4.5만 원) |
| [ ] | `XCConfigs/Module.xcconfig`의 `DEVELOPMENT_TEAM` | 비워 둠 / `4QCSG92KD9` 채움 | 비워 둠. 프레임워크 서명이 꺼져 있어 영향 없음 |

## 4. 확인만 하면 되는 것

| | 할 일 | 언제 |
|---|---|---|
| [ ] | 첫 자동 실행 결과 확인 — `marketing/reports/2026-10-12-weekly.md`에 네이버 블로그 초안·AI 검색 점검이 나왔는지 | 10/12(월) 09:00 이후 |
| [ ] | 그날 Mac이 켜져 있는지(꺼져 있으면 다음 부팅 때 실행) | 10/12 |
| [ ] | 매주 월요일 큐 초안 검토 → `/marketing-approve` | 매주 |

## 사용자 작업 없이 제가 바로 할 수 있는 것 (지시만 주면 시작)

- 웹 참여형 테스트 `/test`
- Supabase 제품 지표 RPC(발송·열람·가입 주간 집계)
- 카드뉴스 이미지 템플릿 3종
- 앱 안 평점 요청 기능(두 번째 편지 열람 뒤) — 리뷰 0건 해소용, 광고 전에 먼저 권함

# 1주차 루프 실행 스펙 — 웹(letter-app) · Android(Mutter_android) · iOS(완료)

> 출처: `marketing/plans/2026-09-16-channel-strategy.md` §3(제품 내장 루프) 1주차 항목 L1·L2·L3.
> 이 문서는 **각 저장소 세션이 이 파일만 읽고 구현할 수 있게** 쓴 자급형 스펙이다.
> Claude Code 세션은 작업 디렉터리 밖 파일을 읽지 못한다. 다른 저장소에서 열 때는 프롬프트에
> `/add-dir /Users/choesuhun/Desktop/Code/Mutter` 를 먼저 입력하거나, 필요한 절을 붙여 넣는다.
> `[확인 필요]`는 구현자가 저장소에서 확인해 채울 값이다.

| 플랫폼 | 항목 | 상태 |
|---|---|---|
| iOS (Mutter) | L2 공유 시트 + 동봉 문구 | 완료 — 이 문서 §5-iOS 참고 구현 |
| Android (Mutter_android) | L2 공유 시트 + 동봉 문구 | 미착수 — §5 |
| 웹 (letter-app) | L1 OG 태그·봉투 이미지 / L3 뷰어 마지막 장 CTA·스토어 링크 / 랜딩 한 줄 A | 미착수 — §1·§2·§3·§4 |

---

## §0. 공통 (세 플랫폼 동일)

### 0-1. 동봉 문구 (공유 시트에 링크와 함께 들어가는 텍스트) — 정본

발신자 1인칭, 브랜드명 없음(미리보기 카드가 브랜드를 맡는다), 느낌표·이모지 0. 줄 구성은 고정이고, 조건 줄은 해당할 때만 넣는다. URL은 **마지막 줄에 단독**(메신저가 미리보기를 붙이는 조건).

```
노래 한 곡을 담아 편지를 썼어요.
열면 음악이 함께 흘러요. 앱 없이 바로 열 수 있어요.
암호는 따로 알려줄게요.              ← 링크에 암호가 걸린 경우만
<날짜 시각>에 열려요.                ← 예약공개이고 그 시각이 아직 미래인 경우만
                                    ← 빈 줄
https://<도메인>/l/<token>
```

| 키(제안) | ko | en |
|---|---|---|
| `share_letter_body` | `노래 한 곡을 담아 편지를 썼어요.\n열면 음악이 함께 흘러요. 앱 없이 바로 열 수 있어요.` | `I wrote you a letter with one song in it.\nThe music plays when you open it. No app needed.` |
| `share_letter_password` | `암호는 따로 알려줄게요.` | `I'll send you the password separately.` |
| `share_letter_reveal_at` | `%1$s에 열려요.` | `It opens at %1$s.` |
| `send_share` (버튼) | `공유하기` | `Share` |

- 자리표시자 `%1$s`는 Android(`strings.xml`) 규약이다. iOS는 `%@`(구현 완료), 웹은 프레임워크 보간을 쓴다.
- 날짜 포맷: 기기 로케일의 "월 일 + 시:분" 축약형(iOS `formatted(date: .abbreviated, time: .shortened)`, Android `DateFormat.getDateTimeInstance(MEDIUM, SHORT)` 또는 `DateTimeFormatter.ofLocalizedDateTime(MEDIUM, SHORT)`).
- 암호 값 자체는 절대 넣지 않는다.
- 복사 버튼은 유지한다(문구가 부담스러운 사용자용). 공유가 1순위, 복사가 2순위.

### 0-2. 스토어 링크

| 스토어 | 기본 URL | 캠페인 파라미터 |
|---|---|---|
| App Store | `https://apps.apple.com/kr/app/id6790086549` | `?pt=<PROVIDER_ID>&ct=<token>&mt=8` (`pt`는 App Store Connect > 앱 분석 > 캠페인 생성 화면에 표시되는 값 `[확인 필요]`. 순서는 Apple 문서 표기) |
| Google Play | `https://play.google.com/store/apps/details?id=<pkg>` `[확인 필요: Mutter_android의 applicationId — com.efreedom.mutter로 추정]` | `&referrer=utm_source%3D<source>%26utm_medium%3D<medium>%26utm_campaign%3D<token>` (URL 인코딩 필수) |

### 0-3. 캠페인 토큰 (ct = utm_campaign, 동일 값)

| 접점 | `ct` / `utm_campaign` | `utm_source` | `utm_medium` |
|---|---|---|---|
| 뷰어 CTA 답장 | `viewer_reply` | viewer | cta |
| 뷰어 CTA 보관 | `viewer_save` | viewer | cta |
| 뷰어 CTA 나도 보내기 | `viewer_send` | viewer | cta |
| 연결 초대 웹 폴백 | `connect_invite` | viewer | connect |
| 인스타 프로필 | `ig_bio` | instagram | bio |
| 인스타 릴스 캡션/스토리 | `ig_reel` | instagram | reel |
| 스레드 | `threads` | threads | post |
| 유튜브 쇼츠 | `yt_shorts` | youtube | shorts |
| 틱톡 | `tiktok` | tiktok | video |
| 네이버 블로그 | `naver_blog` | naver | blog |
| 디스콰이엇 | `disquiet` | disquiet | post |
| 랜딩 직접 | `landing` | direct | landing |

### 0-4. 톤 규칙

존댓말("~해요"), 느낌표·이모지 0, "감동·추억·혁신" 금지, 감정을 지시하지 않고 장면을 보여준다. 확정 카피는 `.agents/product-marketing.md` Customer Language 절과 `marketing/copy/2026-09-16-one-liner-subtitle.md`(한 줄 소개 A·B·C).

- 한 줄 A: `노래 한 곡을 담은 편지. 받는 사람이 여는 순간, 그 음악이 함께 흐릅니다.`
- 한 줄 C: `편지에 노래 한 곡을 담아 링크로 보내요. 받는 사람은 앱을 깔지 않아도 열 수 있어요.`

### 0-5. 브랜드·테마 색 (iOS 실측 토큰)

| 토큰 | 값 |
|---|---|
| Ivory(배경) | `#FFFDF2` |
| Ink(텍스트) | `#221D14` |
| 액센트(토큰명 Gold) | `#C77BAE` — `[확인 필요: 브랜드 액센트를 골드로 갈지 이 모브 핑크로 갈지 미결. 결정 전엔 이 값 사용]` |
| GoldDeep / GoldSoft | `#8E4E7E` / `#F7E8F1` |

| 테마 id | Bg | Fg | Accent |
|---|---|---|---|
| classic-serif | `#FAF8F3` | `#2C2416` | `#8B6914` |
| modern-minimal | `#FFFFFF` | `#111111` | `#0066CC` |
| warm-craft | `#F5EDE0` | `#3B2A1A` | `#C0550A` |
| night-sky | `#0D1B2A` | `#E8DFC8` | `#C8A24A` |
| spring-day | `#FFF7F8` | `#2D1A1F` | `#D4587A` |
| vintage-typewriter | `#F8F4EC` | `#1C1C1C` | `#444033` |
| pure-space | `#F9F9F9` | `#222222` | `#222222` |

---

## §1. 웹 L1 — 링크 미리보기(OG) + 봉투 이미지

### 1-1. 요구사항

`/l/:token` 링크를 카카오톡·인스타 DM·iMessage·슬랙에 붙였을 때 아래 카드가 뜬다.

| 태그 | 값 | 규칙 |
|---|---|---|
| `og:title` | `○○님이 보낸 음악 편지` | 발신 닉네임을 공개해도 되는 경우. 닉네임이 없거나 공개 정책이 미정이면 `음악 편지가 도착했어요` `[확인 필요: 닉네임 노출 정책]` |
| `og:description` | `받는 사람이 여는 순간, 그 음악이 함께 흐릅니다. 설치 없이 열려요.` | 고정 |
| `og:image` | 테마별 봉투 이미지 7장 중 편지의 `templateId`에 맞는 1장. 잠금(암호)·예약공개 링크는 "봉인" 이미지 1장 공용 | 1200×630 PNG/JPG, 정적 파일 |
| `og:site_name` | `뮤터` | |
| `og:type` | `website` | |
| `og:url` | 요청 URL | |
| `twitter:card` | `summary_large_image` | |

**절대 노출 금지**: 편지 제목, 본문, 예약 시각, 암호 값. 봉인 이미지는 잠금·예약·무효 토큰이 모두 같은 이미지라 "보호된 링크"라는 사실만 간접 노출되고 그 이유(암호인지 예약인지, 존재하는 링크인지)는 구분되지 않는다 — 이 정도는 수용한다.

### 1-2. 봉투 이미지 8장 스펙 (`/public/og/` 또는 CDN)

- 크기 1200×630. 파일명 `envelope-<templateId>.png` 7장 + `envelope-sealed.png` 1장.
- 구성: 테마 Bg 전체 배경 → 중앙에 테마 Fg/Accent로 그린 접힌 편지 실루엣(또는 편지지 카드) → 우하단 소형 워드마크 "뮤터"(Ink 또는 테마 Fg, 높이 24~28px 상당). **텍스트는 워드마크 외 없음**(카드 제목·설명이 텍스트를 맡는다).
- 봉인 이미지: Ivory `#FFFDF2` 배경 + 봉투 실루엣 + 액센트 색 봉인 원형.
- 제작은 SVG 템플릿 1개에 테마 색 3개를 주입해 8장 렌더(스크립트 권장, 수작업 금지). 카톡 캐시를 고려해 파일명에 버전 접미사 또는 쿼리(`?v=1`)를 둔다.

### 1-3. 구현 방식 — SPA 주의

카카오톡·페이스북·슬랙 크롤러는 **JavaScript를 실행하지 않는다.** React SPA의 `index.html`에 박힌 정적 OG는 모든 편지에 같은 카드만 보여준다. `/l/:token`은 서버/엣지에서 토큰별 OG를 넣어야 한다.

구현자가 저장소의 현재 호스팅을 확인하고 하나를 택한다 `[확인 필요: Vercel(현재 URL이 *.vercel.app) vs Netlify(docs/universal-links.md에 netlify.toml 언급)]`:

- **Vercel**: `vercel.json`의 rewrite로 `/l/:token`을 Edge/Serverless Function으로 보내고, 함수는 (a) 크롤러 UA(`kakaotalk-scrap`, `facebookexternalhit`, `Twitterbot`, `Slackbot`, `Discordbot`, `LinkedInBot`, `WhatsApp`, `TelegramBot`) 이면 OG 메타만 담은 최소 HTML을 200으로 응답하고, (b) 그 외에는 SPA `index.html`을 그대로 응답(또는 `x-vercel-rewrite`로 정적 파일 반환).
  - **iMessage 주의**: iMessage는 서버 크롤러가 없다. 보내는 기기가 일반 WebKit UA로 페이지를 받아 `<head>`의 OG를 읽으므로, UA 분기 방식(SPA)에서는 iMessage 미리보기가 편지별 카드가 아니라 `index.html`의 정적 OG로 나온다. 카카오톡이 1차 목표라 수용하되, SSR로 가면 함께 해소된다. `Applebot`은 Apple 검색(Siri·Spotlight) 크롤러라 iMessage와 무관하다.
- **Netlify**: Edge Function 동일 로직, 또는 prerendering 옵션.
- 프레임워크가 SSR(Next/Remix 등)이면 페이지 `head`에서 직접 렌더한다.

OG용 데이터 조회는 **기존 공개 RPC(`get_letter_by_token` — iOS Infrastructure가 호출하는 이름, 웹도 같은 Supabase)**의 응답에서 `templateId`·잠금 여부·예약 여부·발신 닉네임만 쓴다. 본문은 함수 밖으로 내보내지 않는다. 토큰이 무효(revoked/없음)면 봉인 이미지 + `음악 편지가 도착했어요`로 응답(존재 여부를 크롤러에 흘리지 않음).

### 1-4. 수용 기준

- [ ] 카카오톡 채팅에 `/l/<token>` 붙이기 → 제목·설명·해당 테마 봉투 이미지 카드 표시(캐시 초기화: https://developers.kakao.com/tool/debugger/sharing).
- [ ] 암호 링크·예약 링크는 봉인 이미지 카드. 카드에서 두 경우가 구분되지 않는다.
- [ ] 일반 브라우저로 열면 기존 뷰어와 완전히 동일하게 동작(리그레션 0).
- [ ] 무효 토큰도 200 + 봉인 카드(크롤러 기준). 브라우저는 기존 "편지를 찾을 수 없어요" 유지.
- [ ] `curl -A "kakaotalk-scrap" https://<도메인>/l/<token> | grep og:image` 로 테마별 파일명 확인.

---

## §2. 웹 L3 — 뷰어 마지막 장 CTA 3단 + 스토어 링크

### 2-1. 배치 원칙

- 편지 서명 아래 **화면 한 뼘(≈ 100vh의 20~25%) 여백 뒤**에 놓는다. 읽는 중에는 보이지 않고 끝까지 스크롤하면 나타난다.
- 읽는 화면(본문·음악)에는 CTA·배너·스티키 바 **0개**. 탭 닫힘 감지 팝업 금지.
- 게이트 화면("편지가 도착했어요 / 편지 열기 / 설치 없이 바로 열려요")은 유지하고 워드마크만 작게 추가(구별 자산 첫 노출).

### 2-2. 3단 CTA

| 순위 | 형태 | 문구 | 부제 | 링크 |
|---|---|---|---|---|
| 1 | 버튼(액센트 배경, 흰 글자) | `노래 한 곡으로 답장하기` | — | 스토어(OS 감지) `ct=viewer_reply` / Play `utm_campaign=viewer_reply`. (앱 설치 시 딥링크 `?action=reply`는 L6 — 이번 범위 밖. 지금은 스토어만) |
| 2 | 텍스트 버튼(밑줄 없음, Ink) | `이 편지, 받은편지함에 두기` | `보낸 사람이 링크를 끄면 다시 열 수 없어요. 받은편지함에 두면 언제든 다시 들을 수 있어요.` | 로그인 상태면 기존 `save_to_inbox` 흐름 `[확인 필요: 웹 뷰어에 받은편지함 저장이 이미 구현돼 있는지. 없으면 이번 주는 상태 무관하게 스토어 `ct=viewer_save`로 통일하고 웹 저장 흐름은 2주차 이후로 이관]`. 미설치·비로그인이면 스토어 `ct=viewer_save` |
| 3 | 작은 링크(Ink 70%) | `나도 누군가에게 노래 한 곡 보내기` | 한 줄 C: `편지에 노래 한 곡을 담아 링크로 보내요. 받는 사람은 앱을 깔지 않아도 열 수 있어요.` **시즌 슬롯**: 이 부제는 설정값 1개로 교체 가능해야 한다(추석: `추석, 멀리 있는 누군가에게도 노래 한 곡을 보내 보세요.`) | 스토어 `ct=viewer_send` |

- 세 개 아래에 워드마크 + `뮤터 · 음악 편지` 한 줄(링크: 랜딩 루트 `?utm_source=viewer&utm_medium=footer`).
- 순서·문구·부제는 위 표를 그대로 쓴다(마케팅 카운슬 결론). 임의 변경 금지, 변경은 이 문서를 먼저 고친다.

### 2-3. OS 감지 → 스토어 분기

```
iOS (iPhone|iPad|iPod)           → App Store URL + ?pt=<PROVIDER_ID>&ct=<token>&mt=8
Android                          → Play URL + &referrer=utm_source%3Dviewer%26utm_medium%3Dcta%26utm_campaign%3D<token>
그 외(데스크톱)                   → 스토어 버튼 대신 QR 1개(랜딩 루트 URL + utm_source=viewer&utm_medium=qr) + "휴대폰에서 이어 하기"
```

클릭 시 `store_redirect{os, ct}` 이벤트(§4)를 먼저 기록하고 이동한다.

### 2-4. 수용 기준

- [ ] 편지를 끝까지 스크롤하기 전에는 CTA가 뷰포트에 들어오지 않는다(본문 짧은 편지도 여백 규칙 적용).
- [ ] iOS Safari → 1순위 탭 → App Store 앱의 뮤터 페이지. Android Chrome → Play 뮤터 페이지. 데스크톱 → QR.
- [ ] 3순위 부제가 환경변수/설정 1개로 교체된다.
- [ ] 로그인 사용자 2순위 → 기존 받은편지함 저장 동작 그대로.
- [ ] 라이트하우스 접근성: 버튼 대비 AA, 터치 타깃 44px.

---

## §3. 웹 랜딩(루트) + 연결 초대 폴백

- 루트(`/`) 히어로 첫 문장 = 한 줄 A. 아래 OS별 스토어 버튼 2개(App Store·Google Play). `utm_source`가 있으면 스토어 링크의 `ct`/`utm_campaign`을 §0-3 표로 매핑해 넘긴다(`instagram`+`bio`→`ig_bio`, `instagram`+`reel`→`ig_reel`, `threads`→`threads`, `youtube`→`yt_shorts`, `tiktok`→`tiktok`, `naver`→`naver_blog`, `disquiet`→`disquiet`, 없음→`landing`).
- `/connect/:token` 웹 폴백(앱 미설치로 웹에 떨어진 경우): 기존 안내 아래 스토어 버튼(`ct=connect_invite`) + 한 줄 C `[확인 필요: 현재 페이지 내용]`.
- 수용 기준: `/?utm_source=instagram&utm_medium=reel` 로 들어와 iOS 버튼을 누르면 App Store URL에 `ct=ig_reel`이 붙는다.

---

## §4. 웹 이벤트 6개 (훅 자리만 — 도구 연결은 2~3주차 L4)

쿠키리스 도구(Vercel Analytics / Plausible / Umami 중 택 1 `[확인 필요]`) 기준. 지금은 **이름을 고정한 단일 `track(name, props)` 함수**를 만들고 호출 자리만 심는다. 도구 미연결 시 no-op.

| 이벤트 | 시점 | props |
|---|---|---|
| `viewer_gate_open` | "편지 열기" 탭 | `theme` |
| `letter_end_reached` | 마지막 장 CTA 영역이 뷰포트에 진입 | `theme` |
| `cta_reply_click` / `cta_save_click` / `cta_send_click` | 각 CTA 탭 | — |
| `store_redirect` | 스토어로 이동 직전 | `os`(`ios`/`android`), `ct` |

---

## §5. Android L2 — 공유 시트 + 동봉 문구

### 5-1. 요구사항

- 링크가 발급되는 두 화면(Compose의 보내기 시트, Delivery/전달 링크 관리 화면)과 **기존 발급 링크 목록 행**에 `공유하기`를 추가한다. `링크 복사`는 유지(2순위).
- 공유 내용 = §0-1 문구 + 마지막 줄 URL. `Intent.ACTION_SEND`, `type = "text/plain"`, `EXTRA_TEXT`에 전체 문자열, `Intent.createChooser(intent, null)`. `EXTRA_SUBJECT`는 넣지 않는다(카톡은 무시, 메일은 제목에 문구가 들어가 어색).
- 문구 조립은 순수 함수 하나로: `LetterShareMessage.text(url, hasPassword, revealAt: Instant?, now = Clock.System.now())` — Compose 시트와 Delivery 화면이 공유. iOS 참고 구현은 `Mutter/Projects/UIComponent/Sources/Share/LetterShareMessage.swift`(같은 줄 구성·같은 조건).
- 발급 응답의 `DeliveryLink`(hasPassword, revealAt)를 상태에 보관해야 문구를 만들 수 있다. iOS는 `issuedLink: String` → `issuedLink: DeliveryLink`로 바꿨다(URL은 파생).
- 문자열 리소스 `values/strings.xml`(ko) + `values-en/strings.xml`(§0-1 표의 키·원문 그대로. `%1$s` 자리표시자).
- 버튼 UI: 기존 프라이머리 버튼 컴포넌트 재사용, 아이콘은 iOS와 동일하게 공유 아이콘(Android 표준 `share` 벡터 또는 기존 아이콘 세트의 share). 순서: **공유하기(프라이머리) → 링크 복사(세컨더리) → 완료**.

### 5-2. 수용 기준

- [ ] 링크 발급 후 `공유하기` → 시스템 공유 시트 → 카카오톡 선택 → 대화창에 문구 3줄 + 빈 줄 + URL 순서로 들어간다.
- [ ] 암호 ON 발급 → "암호는 따로 알려줄게요." 줄 포함, 암호 값 미포함.
- [ ] 예약공개 발급 → "<날짜 시각>에 열려요." 줄이 기기 로케일 포맷으로 포함. 예약 시각이 과거면 줄 없음.
- [ ] 기존 링크 목록 행에서도 공유 가능, 무효화된 링크 행에는 공유 없음.
- [ ] `./gradlew assembleDebug` 성공(JDK 17 — Mutter_android 빌드 규약), 단위 테스트 4케이스(기본/암호/예약/과거예약) 통과.

### 5-3. iOS 참고 구현 (완료, 커밋 기준)

| 파일 | 변경 |
|---|---|
| `Projects/UIComponent/Sources/Share/LetterShareMessage.swift` | 순수 헬퍼(신규) |
| `Projects/UIComponent/Resources/{ko,en}.lproj/Localizable.strings` | `send.share`, `share.letter.body/password/revealAt` |
| `Projects/Feature/Compose/.../ComposeModelData.swift` | `issuedLink: DeliveryLink?` + `issuedLinkURL` |
| `Projects/Feature/Compose/.../SendSheet.swift` | CTA 3단: `ShareLink`(공유) → 복사(secondary) → 완료(ghost) |
| `Projects/Feature/Delivery/.../DeliveryModelData.swift` | `lastIssuedLink: DeliveryLink?` |
| `Projects/Feature/Delivery/.../DeliveryView.swift` | 발급 링크 행·기존 링크 행에 `ShareLink` 아이콘 |
| `Projects/UIComponent/Tests/LetterShareMessageTests.swift` | 5케이스 |

---

## §6. 확인 필요 항목 (구현 전 사용자 답변 또는 저장소 확인)

1. 커스텀 도메인 — 미정. 결정 전까지 `<도메인>` = `letter-app-nine-kohl.vercel.app`. 결정되면 `Mutter/Projects/AppFoundation/Sources/Define/AppLink.swift`의 `baseURL`, Android 상응 상수, 웹 OG `og:url`, AASA를 함께 바꾼다.
2. Android `applicationId` — `com.efreedom.mutter` 추정. `app/build.gradle.kts`에서 확인.
3. App Store 캠페인 `pt`(provider id) — App Store Connect > 앱 분석 > 캠페인 링크 생성 시 표시.
4. OG `og:title`의 닉네임 노출 정책 — 공개 RPC가 닉네임을 이미 반환하는지, 발신자가 익명을 원할 수 있는지.
5. 웹 호스팅(Vercel vs Netlify)과 프레임워크(SPA vs SSR) — §1-3 분기.
6. 웹 애널리틱스 도구 — §4. 현재 도구 유무.
7. 브랜드 액센트 색 — §0-5. 봉투 이미지 제작 전 필요.

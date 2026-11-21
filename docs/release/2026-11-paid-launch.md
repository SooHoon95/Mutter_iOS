# 편지권 출시 — 심사 제출까지 실행 순서

편지권(소모성 인앱결제)과 7일 편지·새 소식 안내를 담은 iOS·Android **2.0.0**을 심사에 올리기까지 할 일.
환불 정책: 편지권은 구매 후 환불하지 않는다(약관 제7조, 결제 화면 안내). 스토어가 자체로 환불한 건만 서버가 회수한다(0043).
코드는 세 저장소 `develop`에 있다. 서버 계약: `docs/specs/permanent-letter-contract.md`.
**사람이 직접 하는 일**에는 ☐를 붙였다(콘솔·운영 쓰기). 나머지는 코드에 이미 반영됐다.

## 1. 정할 것

- ☐ **가격**: 지금 앱 시험 설정과 새 소식 5장 그림은 `편지권 1장 ₩1,100`, `5장 ₩4,400`. 다르게 정하면 새 소식 5장 그림을 다시 찍는다.
- ☐ **출시 시각**: 심사 승인 뒤 유료 스위치를 켜는 시각(아래 6).

## 2. App Store Connect

- ☐ **유료 앱 계약**(계약·세금·은행)이 "활성"인지 — 아니면 인앱결제 상품을 팔 수 없다.
- ☐ **인앱 구입 2개** — 유형 *소모품*
  | 제품 ID | 참조 이름 | 표시 이름(ko) | 설명(ko) |
  |---|---|---|---|
  | `mutter.ticket.1` | Ticket 1 | 편지권 1장 | 편지 한 통을 기간 제한 없이 간직해요 |
  | `mutter.ticket.5` | Ticket 5 | 편지권 5장 | 편지 다섯 통을 기간 제한 없이 간직해요 |
  - 심사용 스크린샷: 결제 안내 시트 캡처(시뮬레이터에서 찍은 것을 쓴다 — 경로는 작업 보고 참고).
  - 처음 내는 인앱 구입은 **앱 버전과 함께** 제출해야 한다: 2.0.0 버전 페이지 "인앱 구입 및 구독"에서 두 상품을 추가.
- ☐ **App Store 서버 알림**(앱 → App 정보): 운영·샌드박스 URL 모두
  `https://aqotppfdrbxhthlqwwhp.supabase.co/functions/v1/apple-notifications`, 버전 2.
  설정 뒤 "테스트 알림 보내기"가 있으면 눌러 함수 로그에 `"type":"TEST"`가 찍히는지 본다.
- ☐ **앱 개인정보**(App Privacy): 추가·확인할 항목 — 구매 내역(구매), 사진(사용자 콘텐츠), 기타 사용자 콘텐츠(편지 본문), 이메일 주소, 사용자 ID.
  모두 "사용자와 연결됨", "추적 아님", 목적 "앱 기능". 앱의 `PrivacyInfo.xcprivacy`와 맞춘다.
  iOS 앱은 Firebase Crashlytics·Analytics도 쓴다 — 충돌 데이터·성능 데이터·제품 상호작용(목적 "분석")도 신고한다.
  아카이브 뒤 Xcode Organizer → Generate Privacy Report로 SDK 매니페스트까지 합친 목록을 보고 빠진 것이 없는지 맞춘다.
- ☐ **개인정보 처리방침 URL**: `https://letter-app-nine-kohl.vercel.app/legal/privacy`(웹 `main` 배포 뒤 새 내용이 보인다 — 아래 5).
- ☐ **이용약관(EULA)**: 앱 정보의 「사용권 계약」은 Apple 표준 EULA 그대로 두거나, 맞춤 약관으로 `https://letter-app-nine-kohl.vercel.app/legal/terms`를 안내한다(웹 `main` 배포 뒤 열림). 앱 설명 끝에 약관·처리방침 주소를 적어 두면 좋다.
- ☐ **심사 메모**(아래 7)와 **데모 계정**(아래 4).

## 3. Google Play Console

- ☐ **결제 프로필**(판매자 계정)이 연결돼 있는지.
- ☐ **인앱 상품 2개**(일회성, 활성): `mutter.ticket.1`, `mutter.ticket.5` — 이름·설명은 위 표와 같게. 가격은 App Store와 맞춘다.
- ☐ **라이선스 테스터**: 설정 → 라이선스 테스트에 시험 계정 Gmail 추가(돈이 나가지 않는 시험 결제).
- ☐ **서비스 계정**: Google Cloud에서 서비스 계정을 만들고 JSON 키 발급 → Play Console "사용자 및 권한"에 그 이메일 초대,
  앱 권한 "재무 데이터 보기"(구매·환불 조회) 부여. 키 내용은 운영 비밀값 `PLAY_SERVICE_ACCOUNT_JSON`으로(아래 4). 키 파일은 저장소에 넣지 않는다.
- ☐ **데이터 보안** 양식: 구매 내역(금융 정보), 사진, 기타 사용자 콘텐츠, 이메일, 사용자 ID — 수집, 앱 기능, 암호화 전송, 삭제 요청 가능.
  계정 삭제 웹 주소: 웹 마이페이지(로그인 → 마이페이지 → 계정 삭제).
- ☐ **개인정보 처리방침 URL**: 위와 같다.

## 4. 운영 서버 반영 (letter-app)

> 2026-11-16 반영 완료: 비밀값 2개(PURCHASE_MODE=live, PLAY_SERVICE_ACCOUNT_JSON), 마이그레이션 0041~0043, 함수 6개. 반영 전 운영 DB 백업을 받았다. 남은 것은 3번 데모 계정.

1. ☐ 비밀값: `supabase secrets set PURCHASE_MODE=live`, `supabase secrets set PLAY_SERVICE_ACCOUNT_JSON="$(cat <키>.json)"`
2. ☐ `scripts/release-paid.sh`로 반영할 것을 확인 → `scripts/release-paid.sh --apply`
   - 마이그레이션 0041(계정 단위 삭제·보낼 때 차감)·0042(삭제 안내 푸시)·0043(환불)
   - 함수 6개 배포
3. ☐ **심사용 데모 계정**: Supabase 대시보드 → Authentication → Add user(이메일·비밀번호, Auto Confirm) 후 SQL 편집기에서
   ```sql
   -- 이메일을 바꿔서 실행
   with u as (select id from auth.users where email = 'appreview@<도메인>')
   insert into purchase_testers (user_id, note) select id, 'app review' from u on conflict do nothing;
   update profiles set nickname = '심사' where id = (select id from auth.users where email = 'appreview@<도메인>') and nickname is null;
   ```
   테스터라서 유료 스위치가 꺼져 있어도 편지권 기능이 보인다(시험 결제 지급은 테스터와 무관). 편지권은 0장으로 둔다(결제 시트가 바로 뜨게).
   새로 만든 계정은 가입 선물 2장을 받으므로(0046) 데모 계정은 그 줄을 지운다:
   ```sql
   delete from ticket_ledger where reason = 'welcome'
    and user_id = (select id from auth.users where email = 'appreview@<도메인>');
   ```
   데모 계정에 받은 편지 하나·보낸 편지 하나가 있으면 심사관이 7일 편지 화면을 보기 쉽다(선택).

### 반영 뒤 확인

- ☐ `supabase migration list --linked`에 0043까지.
- ☐ 데모 계정으로 iOS TestFlight 빌드 로그인 → 편지권 1장 Sandbox 구매 → 잔액 1, `ticket_purchases`에 `environment = Sandbox` 한 행.
- ☐ 같은 계정으로 Android 내부 테스트 트랙 빌드 → 라이선스 테스터 결제 → 잔액 증가, `environment = PlayTest`.
- ☐ 시험 결제(Sandbox·PlayTest)는 테스터가 아니어도 지급된다(심사관이 다른 계정으로 사도 들어오게). 테스터 명단은 유료 스위치 전 편지권 화면 노출에만 쓴다.

## 5. 웹 (letter-app `main`)

- ☐ 로컬에서 처리방침·새 소식 띠·삭제 안내를 확인한 뒤 `develop` → `main` 머지(= Vercel 운영 배포). 서버 반영(4) 뒤에 한다.

## 6. 심사 승인 뒤 — 유료 스위치

```sql
update monetization_config set paid_from = now() where id;   -- 이 순간부터 새 편지가 7일 규칙을 따르고 모든 계정에 편지권이 보인다
```
- 켜기 전 보낸 편지는 계속 기간 제한 없이 열린다.
- 앱 업데이트를 받은 사람은 다음에 앱을 열 때 새 소식 안내를 한 번 본다.

## 7. 심사 메모 (App Store·Play 공통)

```
데모 계정: <이메일> / <비밀번호> — 로그인 화면에서 이메일·비밀번호로 로그인하세요.

이 버전에는 "편지권"(소모성 인앱 구입 mutter.ticket.1, mutter.ticket.5)이 추가되었습니다.
무료로 보낸 편지는 받는 사람이 처음 연 날부터 7일 동안 열리고, 편지권을 쓰면 기간 제한 없이 간직됩니다.

확인 경로: 홈 → 새 편지 쓰기 → (내용 입력) 저장하고 보내기 → "어떻게 보낼까요?"에서 "영구 편지" → "영구 편지로 보내기" → 결제 시트.
데모 계정은 편지권이 0장이라 결제 시트가 바로 나타납니다. 구매하면 편지권이 지급되고, 링크를 만들거나 보낼 때 1장이 사용됩니다.
프로필 → 편지권에서 잔액과 내역을 볼 수 있습니다.

이 기능은 승인 후 서버 설정으로 전체 사용자에게 켜집니다. 그 전에는 데모 계정에서만 보입니다.
```

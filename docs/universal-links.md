# Universal Links (초대·전달 링크를 앱으로 열기)

`/l/:token`(전달 링크·편지 수신)과 `/connect/:token`(초대 링크·1:1 연결)을 **탭하면 웹이 아니라 Mutter 앱으로** 열리게 하는 iOS 네이티브 방식. **3rd-party 솔루션(Firebase Dynamic Links·Branch 등) 불필요.**

> Firebase Dynamic Links는 2025년 종료됨. Universal Links가 유일한 1st-party 정답이다.

## 동작 원리

1. 앱이 `applinks:<도메인>` 을 entitlement 로 선언한다.
2. 그 도메인이 `https://<도메인>/.well-known/apple-app-site-association`(AASA) JSON 을 서빙한다.
3. iOS가 설치 시 AASA를 받아, 해당 도메인 링크를 탭하면 **Safari 대신 앱**으로 전달한다.
4. 앱은 URL을 `Deeplink.swift`(`Projects/AppFoundation/Sources/Define/Deeplink.swift`)에서 이미 파싱한다 — `/l/` → `.letter(token:)`, `/connect/` → `.connect(token:)`.

**앱 미설치 시:** Universal Link는 자동으로 웹으로 폴백된다 → "앱 있으면 앱, 없으면 웹"이 공짜로 성립(무설치 수신 원칙 유지). 커스텀 스킴(`mutter://`)은 이 폴백이 없어 채택하지 않는다.

## 전제 조건 (유료 계정 필요)

- **유료 Apple Developer 계정** — Associated Domains capability는 무료 개인팀에서 프로비저닝 불가.
- **실제 HTTPS 도메인** — 현재 웹은 `window.location.origin` 기반. Netlify 배포 도메인(또는 커스텀 도메인)을 확정해야 한다.

## 활성화 체크리스트 (계정 생성 후 = 내일)

1. **Team ID 확인** — Apple Developer 계정의 Team ID (예: `AB12CD34EF`).
2. **AASA 파일 채우기** — `letter-app/public/.well-known/apple-app-site-association` 의
   `"TEAMID.com.efreedom.mutter"` 에서 `TEAMID` 를 실제 Team ID로 교체.
   (content-type 헤더는 `letter-app/netlify.toml` 에 이미 추가됨.)
3. **웹 배포** — letter-app 을 배포하고 `https://<도메인>/.well-known/apple-app-site-association`
   가 `application/json` 으로 200 응답하는지 확인.
   검증: `curl -I https://<도메인>/.well-known/apple-app-site-association`
4. **entitlement 켜기** — `Mutter/Entitlements/App.entitlements` 의 주석 처리된
   `com.apple.developer.associated-domains` 블록을 활성화하고 `<도메인>` 을 실제 도메인으로 교체.
5. **App ID capability** — Apple Developer 포털의 App ID(`com.efreedom.mutter`)에서
   Associated Domains capability 를 켠다.
6. **빌드·재설치** — `mise exec -- tuist generate --no-open && mise exec -- tuist build Mutter`.
   AASA는 앱 설치/업데이트 시점에 캐시되므로 **앱을 지우고 다시 설치**해야 반영된다.
7. **테스트** — 기기/시뮬레이터에서 `https://<도메인>/connect/<토큰>` 링크(메모앱·메시지 등에서)를
   탭 → 앱의 연결 수락 화면이 뜨는지 확인. `/l/<토큰>` → 편지 뷰어.

## AASA 파일 형식 (참고)

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.efreedom.mutter"],
        "components": [
          { "/": "/l/*", "comment": "delivery link - open letter in Mutter app" },
          { "/": "/connect/*", "comment": "invite link - 1:1 connection in Mutter app" }
        ]
      }
    ]
  }
}
```

- 파일명은 **확장자 없이** `apple-app-site-association`, content-type `application/json`.
- Netlify: `public/` 는 빌드 시 `dist/` 로 복사되고, 정적 파일은 SPA 리라이트보다 우선 서빙된다.
- 서명(.pkcs7) 불필요 — content-type만 맞으면 됨(iOS 9+).

## 현재 상태 (2026-07-02)

- ✅ 앱의 URL 파싱(`Deeplink.swift`) — `/l/`·`/connect/` 둘 다 준비됨.
- ✅ AASA 템플릿 파일 생성됨(TEAMID placeholder) + netlify content-type 헤더 추가됨.
- ✅ entitlement 템플릿(주석) 준비됨.
- ⏳ 유료 계정·도메인 확정 후 위 체크리스트 1~7 실행하면 활성화(스위치만 켜면 됨).

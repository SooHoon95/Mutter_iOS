---
description: iOS 릴리즈 배포 전 전수 검토 에이전트 — 정적 분석 + 시뮬/실기기 런타임 검사 후 심각도 랭킹 HTML 리포트
argument-hint: "[diff|full] [static|runtime|both]  (기본: diff both)"
---

# Release Audit (iOS) — 배포 전 전수 검토 에이전트

Mutter iOS(SwiftUI, Clean + Micro-Feature, Tuist, Supabase)의 **릴리즈 전 리스크를 전수 검토**한다.
정적 분석과 시뮬레이터/실기기 런타임 검사를 병렬로 돌리고, 결과를 하나의 심각도 랭킹 HTML 리포트로 합친다.

## 인자
- 1번째 = 검사 대상: `diff`(기본, 직전 버전업 커밋..HEAD — `git log --grep=버전업 -1 --format=%H`) | `full`(전체)
- 2번째 = 모드: `both`(기본) | `static` | `runtime`

## 실행 절차

### 0. 자기발견 (필수 — 이후 단계가 여기에 의존)
아래를 탐색해 사용자에게 한 줄로 보고한 뒤 진행. 못 찾으면 "미확인"으로 남기고 계속.
```
find . -maxdepth 3 \( -name "*.xcworkspace" -o -name "*.xcodeproj" \) -not -path "*/Pods/*"
cat .mise.toml 2>/dev/null                     # tuist 핀 버전
grep -rn "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" XCConfigs 2>/dev/null | head
```

### 1. 정적 게이트 (순차, 실패해도 계속)
> 빌드는 Tuist 프로젝트 생성이 선행된다. 툴체인이 없으면 이 단계만 건너뛰고 정적/런타임은 계속.
```
mise install                                                  # .mise.toml의 tuist 설치
# Mutter: generate는 순환 의존 간헐 오류가 있으니 실패 시 재시도(`mutter-conventions`)
mise x -- tuist install && mise x -- tuist generate --no-open # SPM + 프로젝트 생성
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -workspace Mutter.xcworkspace -scheme Mutter -destination 'generic/platform=iOS' build    # 컴파일
xcodebuild -workspace Mutter.xcworkspace -scheme Mutter analyze                                       # 정적 분석기
```
`tuist generate` 실패(누락 Tests 디렉토리, `Sensitive.xcconfig` 부재 등)는 그 자체가 빌드 게이트 finding으로 리포트한다.

### 2. 정적 분석 — 아래 클러스터를 **병렬 Agent**로 fan-out (결론만 회수, `파일:라인/severity/근거/배포차단`)

**C1. 테스트·디버그 코드 잔존**
- `\bprint\(`, `debugPrint\(`, `NSLog\(`, `dump\(` (os.Logger 미경유), `#if DEBUG` 밖 디버그 기능
- 하드코딩 테스트 계정/토큰/플레이스홀더 URL(예: `naver.com`), `// (TODO|FIXME)`, Mock/Stub 프로덕션 잔존
- 심사/개발 전용 화면이 릴리즈에서 도달 가능한지(버전/`#if DEBUG`/서버플래그 게이팅)

**C2. 크래시 위험 (iOS 최우선)**
- force unwrap `!`(규칙상 금지), `try!`, `as!`, `fatalError(`/`preconditionFailure(`, 암묵적 언랩 `: T!`
- 배열 `[i]`/`first!`/`last!`, `URL(string:)!`, JSON 미try 디코딩
- 스레드: 백그라운드 UI 접근(`@MainActor`/`DispatchQueue.main` 누락), 메인스레드 동기 네트워크/IO, 비-actor 공유 가변상태 데이터 레이스

**C3. 중복 알럿/팝업**
- `UIAlertController`/SwiftUI `.alert`/`.sheet`/`.fullScreenCover`를 이미 presenting 중 present → "attempt to present while presenting" 크래시
- 동일 이벤트 다중 트리거, 알럿 dedup/단일 present 게이트 부재

**C4. 오프라인 필터링**
- `NWPathMonitor`/Reachability 감지 및 소비처
- `WKWebView` `didFailProvisionalNavigation`/`didFail` 처리 — 오프라인 시 에러페이지 노출(버그) vs 재시도/안내(정상) vs 무피드백 빈 화면(dead-end)
- 앱의 `NetworkMonitor`(AppFoundation) 소비처, 편지 열기·음악 재생(SoundCloud 위젯·AVPlayer) 오프라인 동작

**C5. UI/UX 저해**
- WKWebView 로드 실패 시 영구 빈 화면(재시도/오버레이 부재)
- 메인스레드 블로킹, SwiftUI `body` 내 무거운 연산/Formatter 재생성
- 디자인시스템 우회(UIComponent·`Asset`·`.fonts` 대신 raw 값), 접근성(`accessibilityLabel` 누락)
- Dynamic Type/큰 글꼴/다국어 레이아웃 깨짐

**C6. Edge 케이스**
- 토큰 만료/갱신 중 중복 요청, 빈/nil 응답, 재진입·더블탭, Universal Link/딥링크 재진입
- 권한 거부, 백그라운드 복귀/상태 복원, 앱 종료 후 복원

**C7. 보안·릴리즈 위생**
- 민감정보 로그 노출, 하드코딩 API Key/시크릿
- `Info.plist` ATS 예외(`NSAllowsArbitraryLoads`), 과도한 권한 usage description
- `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` 상향, entitlements/URL scheme 오설정

### 3. 런타임 검사 (모드 both/runtime)
> iOS는 CLI 오프라인 토글이 없다. 오프라인은 실기기 Network Link Conditioner(설정 > 개발자, 100% Loss)로 토글하고, 스크립트는 상태별 캡처만.
```
scripts/release-audit/offline-probe.sh <label> online       # 온라인 캡처
#  ↳ (NLC 100% Loss 켜기)
scripts/release-audit/offline-probe.sh <label> offline      # 오프라인 캡처
#  ↳ (NLC 끄기)
scripts/release-audit/offline-probe.sh <label> recovered    # 복구 캡처
```
- `<label>_offline.png`: 에러페이지(버그) vs 빈 화면+안내 1회(정상). 알럿 2개↑ = 중복 팝업 blocker.
- `<label>_recovered.png`: 재연결 후 WKWebView reload/복구.
- `<label>_*_crash_list.txt`: 최근 크래시 리포트(`~/Library/Logs/DiagnosticReports`).

### 4. 병합 & HTML 리포트 생성
`scripts/release-audit/report-template.html`의 `{{...}}`를 치환(`SCOPE/TARGET/DATE/VERSION/VERDICT/VERDICT_CLASS/N_*/ROWS/UNVERIFIED`)해 파일로 쓰고 **Artifact 도구로 발행**(icon `audit`). 터미널엔 배포 가·부 + BLOCKER 개수 요약.
- 심각도: `BLOCKER`(크래시/빌드깨짐/중복팝업 크래시/에러페이지 노출/PII유출/디버그화면 릴리즈 도달) > `HIGH` > `MEDIUM` > `LOW`.
- 각 항목은 재현 조건 또는 근거 file:line 포함. 추측은 `{{UNVERIFIED}}`로 분리.

## 원칙
- 정적 클러스터 C1~C7은 독립 → 병렬. 런타임은 순차.
- 각 서브에이전트는 결론만 회수(파일 덤프 금지).
- diff 모드는 변경 파일 + 직접 호출부, full은 전수.

---
name: mutter-conventions
description: Mutter iOS의 프로젝트 메타·서비스 컨셉, 빌드 시스템(mise·Tuist·XCConfig·SwiftLint·SwiftGen), 에셋 카탈로그 규칙, 파일 구성(One Type Per File), 네이밍, 주석, 커밋 메시지 컨벤션, 기술 스택, 빌드 실패 트러블슈팅을 다룬다. 새 Swift 파일 작성, L10n/Asset 추가, tuist generate/build/test 실행, 빌드 에러 분석, 커밋 작업 시 참조한다.
---

# Mutter Conventions

## 프로젝트 메타

- 앱: Mutter(뮤터) · Bundle ID `com.efreedom.mutter` · iOS 18 · 팀 `4QCSG92KD9`
- 워크스페이스 `Mutter.xcworkspace`, 앱 타겟·스킴 `Mutter`
- SwiftUI only(UIKit 금지) · Clean Architecture + Micro-Feature · Combine + Swift Concurrency
- 원본 스캐폴드 Mercury(1:1 복제). 스캐폴드 잔재 이름(다른 프로젝트명)을 발견하면 그 토큰만 고치지 말고 전수 grep → 일괄 교정 → 잔재 0을 grep으로 증명한다.

## 서비스 컨셉

"연출되는 편지" — 테마 입힌 본문 1장 + 음악 1곡(자동재생) + 사진(최대 5장). 배포 중인 React+Supabase 웹앱(`letter-app`)의 네이티브 포팅. **수신자는 무설치 웹**으로 열고, 앱은 발신·제작 경험과 인앱 뷰어. 테마는 웜 아이보리 + 골드 + 명조. Android 앱(`Mutter_android`)과 기능 패리티를 유지한다.

## 빌드 시스템

툴 버전은 `.mise.toml`이 고정한다(현재 `tuist = "4.208.0"`). **Bash에서는 항상 `mise exec -- tuist ...`로 호출한다** — 비대화형 셸엔 mise shim이 없어 맨 `tuist`는 전역 구버전이 잡히고 매니페스트 디코드가 깨진다("전엔 됐는데 갑자기 DecodingError" = 버전 불일치).

| 목적 | 명령 |
|---|---|
| SPM 의존성 설치 | `mise exec -- tuist install` |
| 프로젝트 생성(파일·Asset·L10n 추가/삭제 후 필수) | `mise exec -- tuist generate --no-open` |
| 빌드 / 테스트 | `mise exec -- tuist build Mutter` / `mise exec -- tuist test` |
| 캐시 초기화 | `mise exec -- tuist clean && mise exec -- tuist generate --no-open` |

- `tuist generate`가 간헐적으로 `circular dependency`(supabase-swift와 swift-clocks가 같은 `_IssueReporting` 타겟을 다른 패키지명으로 끌어옴)를 낸다. 재시도하면 통과한다 — fastlane `generate` 레인이 10회 재시도로 흡수한다.
- Xcode 27에서 SPM 패키지 배포 타겟 에러가 나면 `.mise.toml` tuist 핀 확인 + `Tuist/.build` 삭제 후 install·generate.
- **빌드 결과는 종료코드가 아니라 출력으로 판정한다.** `| tail`/`| grep` 파이프의 종료코드는 마지막 명령 것이다. `set -o pipefail` 또는 출력에서 `Build Succeeded|BUILD FAILED|error:`를 확인한다.
- 리소스(오디오·이미지·xcassets·tracks.json) 변경 후 동작 확인을 요청할 땐 "앱 삭제 + Clean Build Folder + Run"을 명시한다. 옛 번들이 남아 "안 고쳐진 것처럼" 보인다.

### XCConfig

`XCConfigs/`: `Debug`·`Stage`·`Release`(각각 `#include "Mutter.xcconfig"`) + `MarketingVersion`·`Module`·`Sensitive`(gitignore). 환경 분기는 `SWIFT_ACTIVE_COMPILATION_CONDITIONS` → `#if DEBUG`/`#if STAGE`. 경로는 `Tuist/ProjectDescriptionHelpers` 헬퍼가 참조하므로 파일명 변경 시 헬퍼도 고친다. `Sensitive.xcconfig`가 없으면 구글 로그인 버튼이 크래시한다(`GOOGLE_REVERSED_CLIENT_ID` 미정의).

### SwiftLint

pre-build 단계에서 자동 실행(`Tools/swiftlint`). 빌드가 곧 린트.

### 에셋·문자열 (SwiftGen)

- 색·이미지는 `UIComponent/Resources/Assets/`의 카탈로그 2개 — `Colors.xcassets` → `Asset.Colors.*`, `Images.xcassets` → `Asset.Images.*`. 코드 hex 확장을 만들지 않는다. 디자인 토큰은 UIComponent 소관.
- 새 colorset/imageset은 **카탈로그 루트에 직접** 둔다. 카탈로그 안에 provides-namespace 래퍼 폴더를 두면 `Asset.Colors.Colors.*` 이중 중첩이 생겨 기존 접근자가 전부 깨진다. 재생성 후 `grep -r 'Colors.Colors\|Images.Images'` 0건 + 빌드로 확인.
- 테마색은 `<테마><역할>`(예: `SpringDayBg`)로 평탄하게 → `Asset.Colors.springDayBg`.
- 문자열은 `Localizable.strings` → `L10n.*`. 추가 후 `tuist generate`.

## 팀 작업 규칙

1. **One Type Per File.** 그 파일에서만 쓰는 enum/protocol은 같은 파일 허용.
2. View는 UseCase·ModelData를 거쳐서만 로직을 수행한다(`mutter-architecture`).
3. Feature 간 직접 의존 금지 — Router 또는 Domain 경유.
4. 외부 의존성(네트워크·저장소)은 Infrastructure에서만.
5. UI는 UIComponent 디자인 시스템을 쓴다.
6. async/await. Completion Handler를 새로 쓰지 않는다. `@MainActor`는 UI 업데이트가 필요한 곳에만.
7. 분류 enum은 `Type` 접미사. `CaseIterable + allCases`보다 명시적 배열. Domain에 같은 enum이 있으면 재활용.
8. 다중 파일 일괄 치환은 `grep -rl 패턴 Projects --include='*.swift' | xargs perl -pi -e 's/…/…/g'`. zsh에서 `while read -d ''` 루프는 조용히 0건 처리된다. 치환 후 grep으로 잔존 0과 과치환을 확인한다.

## 주석

"왜"를 쓴다. "무엇"은 코드로. 복잡한 비즈니스 규칙은 private 코드에도 허용. 주석 처리된 dead code는 커밋하지 않는다. 처음 도입하는 API는 `mutter-learning-comments` 예외.

## 커밋 메시지

```
feat · fix · style · refactor · test · docs · build · chore · ci · WIP
{타입}(선택 scope): {한국어 요약} — {부연}
```

- 목적이 다른 변경은 묻지 않고 커밋을 나눈다.
- staging 파일을 개별 지정(`git add -A`/`.` 금지)하고 커밋 전에 재확인한다. `Sensitive.xcconfig`·`*.p8`·`GoogleService-Info.plist`는 절대 포함하지 않는다.
- `feat:` 커밋 뒤에는 `.agents/product-marketing.md` Proof Points에 출처와 함께 기능을 추가한다.

## 기술 스택

| 분류 | 기술 |
|---|---|
| UI | SwiftUI |
| Async | Swift Concurrency, Combine(Navigation 이벤트) |
| DI | MutterContainer(전역만) + 생성자 주입 |
| Backend | Supabase(supabase-swift) |
| Audio | AVPlayer(호스티드 CC0), WKWebView SoundCloud Widget |
| Auth | Apple, Google, Kakao, 이메일 |
| Push | Firebase Messaging |
| Build | Tuist(mise 핀), SwiftLint, SwiftGen |
| 배포 | fastlane(`mutter-ci-cd`) |

## 빌드 실패 트러블슈팅

1. `Cannot find type/... in scope` — import 또는 `Project.swift` 의존성 누락. 새 파일이면 `tuist generate`를 안 한 것.
2. `Module not found` — `tuist generate` 재실행.
3. `Package resolution failed` — `tuist install` 후 generate.
4. `XCConfig not found` — 실제 파일과 헬퍼 경로 대조.
5. `DecodingError` 매니페스트 — mise 핀과 실행 중인 tuist 버전 대조.
6. `__swift_FORCE_LOAD_$_swiftCompatibility*` 링크 실패 — 낮은 배포 타깃 SPM 산물. 미사용이면 의존 제거, 필요하면 `PackageSettings.productTypes`에서 `.staticFramework`.
7. 모듈명이 SDK 모듈명과 충돌 — `mutter-architecture` 참조.

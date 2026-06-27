---
name: ios-build-config
description: Use when running builds, regenerating the Xcode project, working with Debug/Stage/Release configs, or troubleshooting build/SwiftLint failures. Trigger on tasks like "빌드", "tuist generate", "tuist build", "tuist test", "XCConfig", "SwiftLint", "빌드 에러", "mise", "Stage 구성", "Release 빌드".
user-invocable: false
---

# 빌드 & 구성 (Tuist · XCConfig · SwiftLint)

Mutter는 Tuist로 모듈러 프로젝트를 생성하고, mise로 툴 버전을 고정한다.

## 툴 버전

`.mise.toml`이 Tuist 버전을 고정한다 (현재 `tuist = "4.182.0"`, Swift 5.9).
세션 시작·툴 불일치 시 `mise install`로 동기화한다.

## 빌드 명령

| 목적 | 명령 |
|---|---|
| 프로젝트 생성 (파일·Asset·L10n 추가/삭제 후 필수) | `tuist generate` |
| 빌드 | `tuist build` |
| 테스트 | `tuist test` |
| SPM 의존성 설치 | `tuist install` |
| 캐시 초기화 후 재생성 | `tuist clean && tuist generate` |

워크스페이스는 `Mutter.xcworkspace`, 앱 타겟은 `Mutter`.
각 Feature 모듈은 독립 `SampleApp` 타겟을 가져 전체 빌드 없이 단독 실행·테스트할 수 있다.

## 빌드 구성 (XCConfig)

구성: **Debug / Stage / Release**. 정의 위치 `XCConfigs/`.

```
XCConfigs/
├── Debug.xcconfig      # SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
├── Stage.xcconfig      # SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGE
├── Release.xcconfig    # 배포 구성
├── Mutter.xcconfig    # 공통: 서명·배포 타겟·Swift 버전
├── MarketingVersion.xcconfig
├── Module.xcconfig
└── Sensitive.xcconfig  # 민감 값 (서명 등) — 커밋 주의
```

- 각 환경 xcconfig는 `#include "Mutter.xcconfig"`로 공통 설정을 상속한다.
- 환경별 분기는 `SWIFT_ACTIVE_COMPILATION_CONDITIONS`로 한다 — 코드에서 `#if DEBUG` / `#if STAGE`.
- Supabase URL/anonKey 등 환경값은 `AppConfig`(xcconfig→Info.plist)에서 이 조건으로 분기한다 (`ios-networking` 참조).
- XCConfig 경로는 `Tuist/ProjectDescriptionHelpers`의 헬퍼가 참조한다 — 파일명 변경 시 헬퍼도 갱신.

## SwiftLint

Xcode **pre-build 단계에서 자동 실행**된다 (`Tools/swiftlint`).
- 경고는 빌드 로그에 `파일경로:라인` 형태로 노출된다.
- 별도 수동 실행은 불필요 — 빌드가 곧 린트.

## 빌드 실패 트러블슈팅 (순서대로)

1. **`Cannot find type` / `... in scope`** — import 누락 또는 타겟 의존성 누락. 해당 모듈 `Project.swift`의 의존성과 의존 방향 규칙(`ios-architecture`) 확인.
2. **`Module not found`** — Xcode 프로젝트와 Tuist 설정 불일치. `tuist generate` 재실행.
3. **`Package resolution failed`** — `tuist install` 후 `tuist generate`.
4. **`XCConfig not found`** — `XCConfigs/`에 해당 파일 존재 여부, Tuist 헬퍼의 경로와 실제 경로 비교.
5. **Tuist 버전 불일치** — `mise install` 후 재시도.
6. **Linker / 순환 의존** — `Project.swift` 의존성 순환 점검 (`ios-architecture`의 금지 방향 참조).

## 자가 점검

- 파일·Asset·L10n 추가/삭제 후 `tuist generate`를 실행했는가.
- 새 환경 분기 코드가 `Debug/Stage/Release` 세 구성 모두에서 컴파일되는가.
- `Sensitive.xcconfig` 등 민감 값 파일이 의도치 않게 staging 되지 않았는가.
- 빌드 경고(SwiftLint 포함)를 해소했는가.

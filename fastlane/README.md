fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios authcheck

```sh
[bundle exec] fastlane ios authcheck
```

App Store Connect API 키 인증 확인

### ios tf_status

```sh
[bundle exec] fastlane ios tf_status
```

TestFlight 빌드 상태 조회(processingState·usesNonExemptEncryption·베타 상태)

### ios tf_add_tester

```sh
[bundle exec] fastlane ios tf_add_tester
```

TestFlight 내부 그룹에 테스터 추가

### ios promo_text

```sh
[bundle exec] fastlane ios promo_text
```

App Store 프로모션 텍스트(ko) 갱신 — 라이브 버전, 심사 없음

### ios generate

```sh
[bundle exec] fastlane ios generate
```

Tuist로 워크스페이스/프로젝트 재생성

### ios build

```sh
[bundle exec] fastlane ios build
```

아카이브만 — 서명/빌드 점검용(업로드 없음)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

TestFlight 업로드 (내부 배포)

### ios release

```sh
[bundle exec] fastlane ios release
```

App Store 업로드. 심사 자동제출은 submit_for_review:true로.

### ios submit

```sh
[bundle exec] fastlane ios submit
```

이미 올라간 빌드를 심사 제출(재빌드 없음)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

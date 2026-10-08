---
name: mutter-ci-cd
description: Mutter iOS 배포 자동화(fastlane)를 다룬다. 트리거 — (1) TestFlight·App Store 업로드, 심사 제출, 버전업(MARKETING_VERSION), (2) fastlane 레인(generate/build/beta/release/submit/tf_status/tf_add_tester/promo_text/authcheck) 실행·수정, (3) ASC API 키·서명·아카이브 실패 디버깅, (4) 사용자가 "테플 올려줘/배포/심사 제출/버전업/TestFlight 안 보여" 라고 말하는 경우. GitHub Actions CI는 없다 — 배포는 로컬 fastlane.
---

# Mutter CI/CD (fastlane)

CI 서버는 없다. 배포는 로컬에서 `bundle exec fastlane <lane>`로 한다(`fastlane/Fastfile`).

## 레인

| 레인 | 하는 일 |
|---|---|
| `authcheck` | ASC API 키 인증만 확인 |
| `generate` | `mise exec -- tuist install` + `tuist generate --no-open`(순환 의존 간헐 오류를 10회 재시도로 흡수) |
| `build` | generate + Release 아카이브(업로드 없음, 서명 점검용) |
| `beta` | generate → 빌드번호 = TestFlight 최신+1 → 아카이브 → TestFlight 업로드 |
| `release` | beta와 같은 빌드 + App Store 업로드(심사 제출은 안 함) |
| `submit version:X build:N notes:"…"` | 재빌드 없이 처리 완료된 빌드를 심사 제출. 새 버전 첫 제출은 `notes` 필수(릴리스 노트 비면 거절) |
| `tf_status` | processingState·규정준수·내부/외부 베타 상태·그룹별 테스터 조회 |
| `tf_add_tester` | 내부 그룹에 팀 사용자 추가 |
| `promo_text` | 라이브 버전 프로모션 텍스트(ko) 갱신 — 심사 없음. 마케팅 큐 승인(`/marketing-approve`)으로만 실행 |

## 서명·인증

- 자동 서명(`CODE_SIGN_STYLE=Automatic`, 팀 `4QCSG92KD9`) + `-allowProvisioningUpdates`. match 미사용.
- 빌드번호는 Tuist 재생성에 지워지지 않도록 `xcargs CURRENT_PROJECT_VERSION=`으로 주입한다.
- ASC API 키는 env `ASC_KEY_ID`·`ASC_KEY_PATH`(+팀 키면 `ASC_ISSUER_ID`). `.p8`은 발급 시 1회만 받을 수 있으니 받자마자 안전한 곳에 백업한다. 키가 없으면 Appfile Apple ID 로그인(2FA)으로 폴백.
- `app_store_connect_api_key` 성공 ≠ 인증 성공. 실제 인증은 첫 API 호출에서 갈린다 — 의심되면 `authcheck`.

## 완료 판정 (하드 제약)

**TestFlight 배포는 `beta` 성공이 아니라 `tf_status`에서 `processing=VALID` + `internal=READY_FOR_BETA_TESTING` + 대상 그룹 테스터 ≥ 1을 확인한 뒤 "올라갔다"고 보고한다.** 사용자가 기다리는 건 업로드 로그가 아니라 폰에서 보이는 빌드다(2026-09-16: 테스터 0명 그룹이라 아무에게도 안 보였던 사고).

- 이미 출시된 버전(트레인)에는 새 빌드를 못 올린다(90186). 업로드 전에 `XCConfigs/MarketingVersion.xcconfig`가 라이브 버전보다 높은지 본다.
- fastlane 성패는 종료코드가 아니라 로그의 `fastlane.tools finished successfully` / `finished with errors`로 판정한다(파이프 종료코드 함정).

## 버전업

`MarketingVersion.xcconfig`의 `MARKETING_VERSION`만 올린다. 커밋 예: `chore: 앱 1.0.5 버전업 — <주요 기능>`. Android(`Mutter_android`)와 같은 기능이 나가면 양쪽 릴리스 노트를 맞춘다.

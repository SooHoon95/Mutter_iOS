# CLAUDE.md

Claude Code가 이 저장소에서 작업할 때 따르는 지침. 이 파일은 **대원칙과 스킬 트리거**만 담는다.
구체 규칙·예시·보일러플레이트는 모두 `.claude/skills/<name>/SKILL.md`에 있다.

---

## 프로젝트

**Mutter** — "연출되는 편지" 감성 음악 편지 iOS 앱(배포 중인 React+Supabase 웹앱의 네이티브 포팅).
편지 = 테마 입힌 본문 1장 + **음악 1곡(자동재생)**. 수신자는 무설치 웹 유지, 앱은 발신/제작 경험 + 인앱 뷰어.
SwiftUI only (UIKit 금지) · **Tuist 모듈러(Mercury 스캐폴드 1:1 복제)** · Clean Architecture + Micro-Feature · Combine + Swift Concurrency.
앱 타겟 `Mutter` · 워크스페이스 `Mutter.xcworkspace` · Bundle ID `com.efreedom.mutter` · iOS 18.
백엔드는 **Supabase 그대로 재사용**(supabase-swift, 테이블 7·RPC 17). 테마는 웜 아이보리+골드+명조. DI 컨테이너 `MutterContainer`.
모듈 분할은 `docs/specs/module-architecture.md` 참조.

빌드·구성·트러블슈팅은 `ios-build-config` 스킬을 참조한다.

---

## 대원칙

### 워크플로 오케스트레이션

1. **Plan 모드 기본** — 사소하지 않은 작업(3단계 이상 또는 아키텍처 결정)은 Plan 모드로 진입한다. 어긋나면 즉시 멈추고 재계획한다 — 그대로 밀어붙이지 않는다. Plan 모드는 빌드뿐 아니라 검증 단계에서도 쓴다. 모호함을 줄이기 위해 상세 스펙을 먼저 작성한다.
2. **서브에이전트 활용** — 메인 컨텍스트를 깨끗이 유지하도록 서브에이전트를 적극 사용한다. 리서치·탐색·병렬 분석은 서브에이전트로 위임한다. 복잡한 문제일수록 컴퓨트를 더 투입하고, 서브에이전트 하나당 한 가지 갈래에만 집중시킨다. 범위가 작으면 현재 컨텍스트에서 직접 처리하고, 여러 파일·책임으로 나뉠 때만 분산한다.
3. **자기 개선 루프** — 사용자 교정이 있을 때마다 패턴을 기록하고 같은 실수를 막을 규칙을 스스로 작성한다. 실수율이 낮아질 때까지 가차 없이 갱신한다. 세션 시작 시 누적 교훈을 먼저 검토한다. (운영은 `self-improvement` 스킬)
4. **완료 전 검증** — 동작을 증명하지 않은 작업은 절대 완료로 표시하지 않는다. 필요하면 main과 변경 결과의 동작 차이를 비교한다. "스태프 엔지니어가 승인할까?"를 스스로 묻고, 테스트 실행·로그 확인으로 정확성을 입증한다. **자가 승인 금지** — 사소하지 않은 변경은 커밋 전 별도 패스로 `code-reviewer`/`critic`(또는 `/arch-check`)로 독립 검토한다. (Codex 미사용 — 리뷰는 Claude 네이티브)
5. **우아함 추구 (균형)** — 사소하지 않은 변경에선 잠시 멈추고 "더 우아한 방법이 있나?"를 묻는다. 임시방편처럼 느껴지면 지금 아는 모든 것을 바탕으로 우아한 해법을 구현한다. 단순·명백한 수정은 건너뛴다 — 과한 엔지니어링 금지. 결과 제시 전 스스로 도전·검토한다.
6. **자율적 버그 수정** — 버그 리포트를 받으면 바로 고친다. 손잡고 안내해 달라고 하지 않는다. 로그·에러·실패 테스트를 가리키고 그것을 해결한다. 사용자의 컨텍스트 전환은 0이어야 한다.

### 핵심 원칙

- **Simplicity First** — 모든 변경을 가능한 가장 단순하게. 코드 영향 최소화.
- **Root-Cause First** — 근본 원인을 찾아 동작으로 증명한다. 임시방편 대신 근본 해결을 택한다. 시니어 개발자 기준.
- **Minimal Impact** — 변경은 꼭 필요한 곳만 건드린다. 버그를 끌어들이지 않는다.
- **긍정 지시** — 규칙·요청은 "하지 마"보다 "이렇게 한다"로 쓴다. 원하는 동작을 먼저 두고, 회피 대상은 뒤에 짧게.
- **근거 우선** — 원인을 추측으로 단정하지 않는다. 관련 파일을 먼저 읽고, 확인된 사실과 가설(확인 필요)을 구분해 보고한다.
- **Effort 정합** — 작업 복잡도에 effort를 맞춘다. 단순 조회는 낮게, 코딩·디버깅·리뷰·다중 파일은 높게(`/effort`). 결과가 얕으면 프롬프트를 덧붙이기 전에 effort부터 점검한다.

### 작업 관리 사이클

사소하지 않은 작업은 **Plan First → Verify Plan → Track Progress → Explain Changes → Document Results → Capture Lessons** 6단계를 따른다. 계획·진행·교훈은 `tasks/todo.md`·`tasks/lessons.md`로 관리하며, 포맷과 운영 규칙은 `self-improvement` 스킬이 정의한다.

---

## 스킬 트리거 인덱스

아래 트리거에 해당하면 해당 스킬을 **먼저 로드**한다. 여러 스킬이 동시에 트리거되면 모두 로드해 충돌 없이 적용한다. 상세 규칙·예시 코드·자가 점검은 각 `SKILL.md`에 있다.

| 스킬 | 로드 시점 (when-to-use) |
|---|---|
| `ios-architecture` | 새 Feature·모듈 추가, 의존 방향 정의·점검, Domain Model·UseCase 설계, Repository 구현 구조, DTO→Domain 매핑 |
| `ios-di` | `MutterContainer` 의존성 등록, `@Inject`·`@LazyInject` 선언, Repository/UseCase를 Feature에 배선, 컴포지션 루트 수정 |
| `ios-navigation` | 화면 전환, `AppRoute`/`AuthRoute` case 추가·수정, `NavigationCoordinator` 사용, `presentFullScreen`/`push`/`pop` 흐름 |
| `ios-networking` | Supabase 호출(`auth`/`from`/`rpc`), Repository 구현, DTO↔Domain 매핑, `SupabaseProvider`·세션(Keychain) 처리 |
| `ios-coding-conventions` | 새 Swift 파일·View 작성, 타입·enum 네이밍, `L10n`/`Asset` 사용, 주석 작성, 커밋 직전 |
| `ios-error-handling` | throws 가능한 비동기 호출 추가, ModelData에 에러 상태 추가, SwiftUI 에러 alert 표시, raw error를 `MutterError`로 변환 |
| `ios-swiftui-pitfalls` | 상태 보존이 필요한 SwiftUI View, `ScrollView` 인터랙션, 애니메이션, `TabView`/`NavigationStack` 흐름, SwiftUI 성능 디버깅 |
| `ios-build-config` | 빌드·테스트 실행, Xcode 프로젝트 재생성(`tuist generate`), Debug/Stage/Release XCConfig 작업, SwiftLint·빌드 실패 트러블슈팅 |
| `self-improvement` | 사소하지 않은 작업 시작, 작업 계획 작성, 진행 추적, 사용자 교정 기록, `tasks/todo.md`·`tasks/lessons.md` 운영, 세션 시작 회고 |
| `learning-comments` | 처음 도입하는 외부 프레임워크/SDK·SwiftUI 고급 API·Combine/Concurrency 패턴, 사용자가 "주석", "흐름 따라가게", "이해 안 가", "처음 써봐" 표현. 그 블록에 한해 풍부한 한국어 주석 작성 |

---

## 슬래시 커맨드 (`.claude/commands/`)

| 상황 | 커맨드 |
|---|---|
| Feature 모듈에 새 화면(View + ModelData) 추가 | `/new-ios-screen` |
| 새 Feature/Core 모듈 생성 | `/new-ios-module` |
| 파일 추가/삭제, Asset/L10n 변경 후 프로젝트 재생성 | `/tuist-gen` |
| 모듈 의존성 방향 위반 점검 | `/tuist-dep-check` |
| 빌드·에러 분석 | `/build-ios` |
| 커밋 | `/commit` |
| 아키텍처 규칙 전수 검사 | `/arch-check` |

자동 트리거: 코드 수정 후 → `/arch-check` · 파일 추가/삭제 후 → `/tuist-gen` · 빌드 에러 → `/build-ios`(의존성 문제 시 `/tuist-dep-check`) · 커밋 요청 → `/commit`.

---

## 작업 절차

1. 요청 분석 → 영향 모듈·레이어 파악 → 관련 스킬 로드 → 구현 계획.
2. Feature 신규 또는 3개 이상 모듈 변경 시 사용자 확인 후 진행.
3. 관련 파일만 선택 Read (`.build/checkouts/**`는 절대 읽지 말 것 — 외부 SPM 캐시).
4. 파일 추가/삭제 시 `tuist generate` → 빌드 검증 → 테스트 (`ios-build-config` 참조).
5. 커밋 전 자가 검증: 의존 규칙 위반 없음 확인 (각 스킬의 "자가 점검" 섹션 참조). 커밋 메시지에 Co-Authored-By 금지.

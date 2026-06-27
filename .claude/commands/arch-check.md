# arch-check

CLAUDE.md의 아키텍처 규칙에 따라 코드베이스 위반을 탐지한다.

검사 전 관련 파일(`CLAUDE.md`, 대상 `Project.swift`, 해당 소스)을 먼저 읽고, 확인된 위반과 추정 위반(가설)을 구분해 보고한다. 아래 8개 검사 항목은 상호 독립적이므로 동시에 실행 가능하다.

## 검사 항목

### 1. View 레이어 위반

**View에서 Repository 직접 호출 (팀 규칙 #4 위반)**
- `Projects/Feature/` 내에서 `Repository()`, `Repository.shared` 패턴 검색

**View에서 직접 네트워크 호출 (Architecture Principles #2 위반)**
- `Projects/Feature/*/Sources/public/` 내에서 `SupabaseProvider`, `.rpc(`, `.from(`, `URLSession` 패턴 검색

**NavigationLink 직접 사용 (Navigation & Routing 규칙 위반)**
- `Projects/Feature/` 내에서 `NavigationLink` 패턴 검색

**UIKit 사용 (프로젝트 개요: "UIKit 사용 금지")**
- `Projects/Feature/` 내에서 `import UIKit` 패턴 검색

### 2. Domain Layer 위반

**Domain에서 플랫폼 import (Architecture Principles #4 위반)**
- `Projects/Domain/` 내에서 `import SwiftUI`, `import UIKit` 패턴 검색

**Domain에서 Infrastructure 직접 접근 (Dependency Rules "금지된 의존 관계" 위반)**
- `Projects/Domain/` 내에서 `import Infrastructure`, `import Network` 패턴 검색

### 3. Feature 간 직접 의존 (팀 규칙 #5 위반)

- `Projects/Feature/` 내에서 다른 Feature 모듈 이름의 import 검색
- 자기 자신의 모듈은 제외

현재 Feature 모듈 목록:
Auth, Compose, Viewer, Delivery, Inbox, Connections, Threads, Profile, Home, Legal, MainTab

### 4. ModelData 규칙 위반

**ObservableObject + @Published 사용 (CLAUDE.md: "@Observable을 사용한다" 위반)**
- `Projects/Feature/` 내에서 `ObservableObject`, `@Published` 패턴 검색

**ModelData가 public으로 노출 (CLAUDE.md: "internal로 선언하여 Feature 모듈 외부에 노출하지 않는다" 위반)**
- `Projects/Feature/` 내에서 `public.*class.*ModelData`, `public.*struct.*ModelData` 패턴 검색

### 5. DTO 직접 노출 위반 (Data Layer Rules 위반)

**View 또는 UseCase에서 DTO 직접 사용**
- `Projects/Feature/` 내에서 `DTO` 패턴 검색
- `Projects/Domain/` 내에서 `DTO` 패턴 검색

### 6. async/await 규칙 (팀 규칙 #8 위반)

**Completion Handler 패턴 새로 작성**
- `Projects/Feature/` 내에서 `completionHandler`, `@escaping.*Void`, `completion:.*->.*Void` 패턴 검색
- 기존 콜백 패턴(onComplete 등)은 허용. 새로 작성된 네트워크/비즈니스 로직용 콜백만 위반으로 판단한다.

### 7. Enum 네이밍 및 allCases 위반 (팀 규칙 #11, #12)

**카테고리/분류 성질의 enum에 Type 접미사 누락**
- `Projects/Feature/` 내에서 카테고리/분류용 enum 정의 시 `Type` 접미사가 없는 경우 경고

**CaseIterable + allCases 사용 (팀 규칙 #12 위반)**
- `Projects/Feature/` 내에서 `.allCases` 패턴 검색

### 8. One Type Per File 위반 (팀 규칙 #1)

- 각 Swift 파일에서 `public struct`, `public class`, `public enum` 선언 수를 확인
- 2개 이상이면 경고 (단, 해당 파일에서만 사용하는 private enum/protocol은 예외)

## 출력 형식

2단계로 보고한다.

**1단계 — 발견(Findings)**: 확신이 낮거나 저심각도인 항목까지 모두 나열한다. 확인된 위반과 추정(가설)을 구분해 표기한다.

**2단계 — 필터(Prioritized)**: 1단계 결과를 심각도 라벨로 우선순위화한다. 라벨: `[CRITICAL]` / `[HIGH]` / `[MEDIUM]` / `[LOW]`.

```
[CRITICAL][FAIL] NavigationLink 직접 사용 발견:
  - Projects/Feature/Home/Sources/public/HomeView.swift:34
[MEDIUM][WARN] ModelData public 노출:
  - Projects/Feature/Auth/Sources/internal/AuthModelData.swift:5
[PASS] View에서 Repository 직접 호출 없음
```

## 수정 가이드

| 위반 | 수정 방법 | CLAUDE.md 근거 |
|------|-----------|----------------|
| View에서 Repository 직접 호출 | UseCase를 통해 간접 호출 | 팀 규칙 #4 |
| NavigationLink 직접 사용 | `coordinator.push(...)` 로 변경 | Navigation & Routing |
| UIKit 사용 | SwiftUI로 대체 | 프로젝트 개요 |
| Domain에서 SwiftUI/UIKit import | import 제거, Foundation만 허용 | Architecture Principles #4 |
| Feature → Feature 직접 의존 | Router 또는 Domain을 통해 간접 통신 | 팀 규칙 #5 |
| ModelData가 public | `internal` (접근 제한자 미명시)으로 변경 | 데이터 흐름 - ModelData |
| DTO가 View/UseCase에 노출 | Mapper(toEntity)로 Domain Model 변환 후 사용 | Data Layer Rules |
| ObservableObject 사용 | `@Observable` 매크로로 마이그레이션 | 데이터 흐름 - ModelData |
| Completion Handler 신규 작성 | async/await로 변경 | 팀 규칙 #8 |

## 전체 실행

위 8개 검사는 상호 독립적이므로 동시에 실행 가능하다. 결과를 취합해 먼저 발견 단계로 모두 보고한 뒤, 필터 단계에서 심각도별로 위반 건수를 요약 출력한다. 실제 코드 수정은 이 보고와 수정 계획 제시 후 진행한다.

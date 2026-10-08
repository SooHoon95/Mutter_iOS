---
name: ios-architecture
description: Use when adding new Features/modules, defining dependency direction, designing Domain Models or UseCases, structuring Repository implementations, or mapping DTO to Domain. Trigger on tasks like "새 Feature 추가", "UseCase 작성", "Repository 구현", "DTO 매핑", "의존 방향 점검", "모듈 추가".
user-invocable: false
---

# iOS 아키텍처 규칙

Mutter는 Clean Architecture + Micro-Feature 구조를 따른다.

## 의존 방향

```
MutterApp → 모든 Module
Feature → Domain ← Infrastructure → Network
Feature → Router, UIComponent, AppFoundation
Infrastructure, Network → AppFoundation
```

금지:
- `Feature → Feature`
- `Domain → Infrastructure | Network | UIKit | SwiftUI`
- `UIComponent → Feature | Domain`

원칙:
1. Business Logic은 Domain Layer에 위치
2. UI Layer는 State Rendering만 수행
3. Infrastructure Layer는 외부 시스템(Supabase) 담당
4. Domain Layer는 플랫폼 비의존 — **순수 Swift**
5. Feature 간 결합도 최소화

## 모듈 구조

```
Projects/
├── MutterApp/        # 앱 진입점, MainView, RootViewFactory, ViewWrapper
├── AppFoundation/    # DI(MutterContainer), MutterError, 상수
├── Network/          # SupabaseProvider(supabase-swift) — auth/from/rpc/functions
├── Router/           # NavigationCoordinator, AppRoute, ViewFactoryProtocol
├── Domain/           # Repository 프로토콜, UseCase, Domain Model
├── Infrastructure/   # Repository 구현체, DTO, Mapper
├── UIComponent/      # 공통 SwiftUI 컴포넌트, 디자인 토큰(Colors, Typography)
└── Feature/<Name>/   # Auth, Compose, Viewer, Delivery, Inbox, Connections, Threads, Profile, Home, Legal, MainTab
```

각 Feature는 독립 `SampleApp` 타겟 보유 → 앱 전체 빌드 없이 단독 실행·테스트 가능.

### Feature 내부 구조

```
Feature/Example/
├── Project.swift
├── Sources/
│   ├── public/      # 외부 공개 View, ViewFactory
│   └── internal/    # 내부 SubView, ModelData
├── Resources/
└── Tests/
```

## Domain Layer 규칙

- 순수 Swift만. UIKit/SwiftUI/Combine UI 비의존.
- Repository 프로토콜은 Domain에, 구현체는 Infrastructure에.
- 비동기는 `async`/`AnyPublisher` 프로토콜 수준까지만.
- `@MainActor`는 View/ViewModel 경계에만. Domain은 actor-agnostic.

## UseCase 규칙

UseCase = 동일 도메인의 관련 비즈니스 행동 집합.

```swift
public protocol LetterUsecasable: Sendable {
  func myLetters() async throws -> [Letter]
  func letter(id: String) async throws -> Letter?
}

public final class LetterUsecase: LetterUsecasable {
  private let repository: LetterRepositorable
  public init(repository: LetterRepositorable) { self.repository = repository }
  public func myLetters() async throws -> [Letter] {
    try await repository.myLetters()
  }
}
```

- 도메인 단위로 묶는다 (`LetterUsecase`, `DeliveryUsecase`, `AuthUsecase`).
- Repository 통해서만 데이터 처리. UseCase에서 직접 네트워크 호출 금지.
- Repository 프로토콜은 Domain Layer, 구현체는 Infrastructure Layer.
- UseCase 반환: 단발성 → `async throws`, 스트림 → `AnyPublisher<T, Error>`.

## Data Layer 규칙

DTO는 Domain Layer에 직접 노출 금지.

```
DTO → toDomain() (Mapper) → Domain Model
```

- DTO 위치: `Infrastructure/Sources/.../Model/`
- Mapper: DTO extension `func toDomain() -> DomainModel`, DTO 파일 하단에.
- View/UseCase는 Domain Model만 사용. DTO 직접 노출 금지.

## 데이터 흐름

```
View → ModelData (@Observable) → UseCase → Repository 구현체 → SupabaseProvider
                                            ↓
                             DTO → toDomain() → Domain Model 반환
```

레이어 역할:
- **View**: 사용자 액션 → ModelData 메서드 호출. ModelData 상태 구독 → UI 렌더링. 비즈니스 로직 직접 처리 금지.
- **ModelData** (`@Observable`, Feature 내부, `internal`): UseCase를 소유·호출. 로딩/에러 상태 관리. Repository 직접 접근 금지.
- **UseCase** (Domain): Repository 프로토콜에만 의존. 구현체 비의존.
- **Repository 구현체** (Infrastructure): Domain 프로토콜 구현. SupabaseProvider 호출 + DTO → Domain 변환. `@LazyInject`로 의존성 주입.
- **SupabaseProvider** (Networking): `auth` / `from(table)` / `rpc(fn, params)`. Repository 구현체만 호출.
- **Mapper** (Infrastructure): DTO extension으로 `toDomain()` 정의.

## Domain Models

```
Letter              — id, title, body, templateId, cue: MusicCue?
Track               — id, title, author, license, url, mood        // CC0 카탈로그
DeliveryLink        — token, letterId, hasPassword, expiresAt?, revoked
Profile             — id, nickname?
LetterDirectionType — sent / received
```

- 카테고리/분류 enum은 `Type` 접미사.
- 동일 enum 중복 정의 금지 — Domain 기존 정의 재활용.

## 자가 점검

- Feature → Domain ← Infrastructure 의존 위반 없음.
- Domain이 UIKit/SwiftUI/Combine UI 비의존.
- DTO가 Feature/Domain에 노출되지 않음.
- Repository 구현체에서만 SupabaseProvider 호출.
- View가 UseCase 또는 ModelData 경유로만 비즈니스 로직 처리.

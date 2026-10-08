---
name: mutter-architecture
description: Mutter iOS의 레이어 경계·모듈 의존성·Clean/Micro-Feature 구조를 다룰 때 참조한다. 새 Feature/Core 모듈 추가, 의존 방향 정의·점검, Domain Model·UseCase 설계, Repository 구현 구조, DTO→Domain 매핑, View→ModelData→UseCase→Repository→SupabaseProvider 데이터 흐름, DI(MutterContainer·@Inject·생성자 주입) 배선이 필요한 작업에서 활용한다.
---

# Mutter Architecture

Clean Architecture + Micro-Feature. 원본 스캐폴드는 **Mercury**(`~/Desktop/Code/Mercury`) — 구조·명명이 애매하면 Mercury 실제 코드를 근거로 정한다(설계문서보다 우선).

## 원칙

1. Business Logic은 Domain Layer에 둔다.
2. UI Layer는 State Rendering만 한다.
3. Infrastructure Layer가 외부 시스템(Supabase)을 담당한다.
4. Domain은 플랫폼 비의존 — **순수 Swift**(UIKit/SwiftUI/Combine UI 비의존).
5. Feature 간 결합도를 최소화한다.

## 의존 방향

```
MutterApp → 모든 Module
Feature → Domain ← Infrastructure → Network
Feature → Router, UIComponent, AppFoundation
Infrastructure, Network → AppFoundation
```

금지: `Feature → Feature` · `Domain → Infrastructure | Network | UIKit | SwiftUI` · `UIComponent → Feature | Domain`.
Feature 간 통신은 Router(`FeatureRoute`) 또는 Domain을 거친다.

## 모듈 구조

```
Projects/
├── MutterApp/        # 진입점, MainView, RootViewFactory, ViewWrapper(탭별 조립)
├── AppFoundation/    # DI(MutterContainer/@Inject/@LazyInject), MutterError, AppConfig, NetworkMonitor, Session
├── Network/          # SupabaseProvider(supabase-swift)
├── Router/           # NavigationCoordinator, AppRoute(탭)·FeatureRoute(화면), ViewProtocol
├── Domain/           # Repository 프로토콜, UseCase, Domain Model
├── Infrastructure/   # Repository 구현체, DTO, Mapper, SupabaseErrorMapper, 번들 오디오
├── AudioSync/        # LetterAudioPlayer, HostedAudioSource(AVPlayer), SoundCloudSource(WKWebView 위젯)
├── UIComponent/      # 공통 SwiftUI 컴포넌트, 디자인 토큰(Asset.Colors/Images, 폰트)
└── Feature/          # AuthFeature, Compose, Connections, Delivery, Home, Inbox, Legal, MainTab, Profile, Threads, Viewer
```

각 Feature는 독립 `SampleApp` 타겟을 가진다. Feature 내부는 `Sources/public/`(공개 View·ViewFactory) + `Sources/internal/`(ModelData·SubView) + `Resources/` + `Tests/`.

**모듈명은 링크될 SDK 모듈명과 겹치지 않게 짓는다** — supabase의 `Auth/Storage/Functions/Realtime/PostgREST`, Firebase 등. Feature `Auth`가 supabase `Auth`와 충돌해 `AuthFeature`로 바꾼 전례가 있다(단일 모듈 빌드에선 안 보이고 앱 합성 루트에서만 터진다).

## UseCase

UseCase = 같은 도메인의 관련 행동 집합(`LetterUsecase`, `DeliveryUsecase`, `InboxUsecase`…).

```swift
public protocol LetterUsecasable: Sendable {
  func myLetters() async throws -> [Letter]
}

public final class LetterUsecase: LetterUsecasable {
  private let repository: LetterRepositorable
  public init(repository: LetterRepositorable) { self.repository = repository }
  public func myLetters() async throws -> [Letter] { try await repository.myLetters() }
}
```

- Repository를 통해서만 데이터를 다룬다. UseCase가 네트워크를 직접 호출하지 않는다.
- 반환: 단발성 `async throws`, 스트림 `AnyPublisher<T, Error>`.
- `@MainActor`는 View/ModelData 경계에만. Domain은 actor-agnostic.

## Data Layer

```
DTO → toDomain() → Domain Model
```

- DTO는 `Infrastructure/Sources/.../Model/`, Mapper는 DTO 파일 하단 `toDomain()` extension.
- View/UseCase는 Domain Model만 본다.
- **영속 데이터에는 이식 가능한 값만 저장한다.** 웹에서 origin-상대로 동작하던 에셋 경로(`/audio/x.m4a`)는 cue/letter에 그대로 두고, 재생·표시 시점에 Repository/UseCase 경계에서 번들 URL로 해석한다(`CatalogRepositorable.localAudioURL(for:)`). 절대 파일 URL을 저장하면 수신자·다른 기기에서 깨진다. `URL(string:)`은 상대경로에도 nil을 안 주니 "주소 유효 = 재생 가능"으로 보지 않는다.

## 데이터 흐름

```
View → ModelData(@Observable, internal) → UseCase → Repository 구현체 → SupabaseProvider
                                                        └ DTO.toDomain() / SupabaseErrorMapper.map(error)
```

- **View**: 액션 → ModelData 호출, ModelData 상태 렌더링. 비즈니스 로직 없음.
- **ModelData**: `@MainActor @Observable final class`, Feature 내부 `internal`. UseCase를 생성자로 받아 호출. 로딩/에러 상태 관리. Repository를 모른다.
- **Repository 구현체**: Domain 프로토콜 구현, SupabaseProvider 호출, DTO 변환, 에러 정규화(`mutter-networking`).

## DI — 전역만 로케이터, 나머지는 생성자 주입

`MutterContainer`(Service Locator) + `@Inject`/`@LazyInject`는 **앱 전체가 공유하는 진짜 전역**(현재 `SessionManagable`)에만 쓴다. 등록은 `MutterApp.swift`(AppDelegate `didFinishLaunching`).

UseCase·Repository는 컨테이너에 넣지 않는다. 호출부(`RootViewFactory` 각 case, `*ViewWrapperView.init()`)에서 `XUsecase(repository: XRepository())`로 인라인 조립해 생성자로 넘긴다. Repository는 `provider: SupabaseProvider = .shared` 기본값이 있어 무인자 생성이 된다. 코디네이터 콜백 때문에 init에서 피처뷰를 못 만드는 래퍼는 usecase만 init에서 `let`으로 조립하고 body에서 뷰를 구성한다.

왜: usecase를 전역 등록하면 당장 안 쓰는 것까지 앱이 들고 있고, `@Inject`로 꺼내 쓰는 순간 그게 곧 전역 등록이다. Mercury도 로케이터엔 세션·토스트·얼럿·로딩·config만 둔다(2026-06-30 검증).

```swift
// 전역 등록
MutterContainer.shared.register(SessionManagable.self, instance: SessionManager())
@Inject private var sessionManager: SessionManagable

// 화면 조립 (ViewWrapper)
let usecase = InboxUsecase(repository: InboxRepository())
InboxView(inboxUsecase: usecase)
```

## Domain Models (대표)

`Letter`(id, title, body, templateId, cue: MusicCue?) · `Track`(CC0 카탈로그) · `DeliveryLink`(token, letterId, hasPassword, expiresAt?, revoked) · `Profile` · `InboxItem`. 분류 enum은 `Type` 접미사, Domain에 같은 의미 enum이 있으면 재활용.

전체 모듈 설계·RPC 매핑은 `docs/specs/module-architecture.md`.

## 자가 점검

- Feature → Domain ← Infrastructure 위반 없음, Feature → Feature 없음.
- Domain이 UIKit/SwiftUI/Combine UI 비의존.
- DTO가 Feature/Domain에 노출되지 않음.
- SupabaseProvider 호출이 Repository 구현체에만 있음.
- 새 UseCase를 컨테이너에 등록하지 않고 호출부 생성자 주입으로 배선했음.

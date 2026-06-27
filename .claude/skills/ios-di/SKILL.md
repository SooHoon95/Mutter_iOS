---
name: ios-di
description: Use when registering dependencies in MutterContainer, declaring @Inject or @LazyInject properties, or wiring Repository/UseCase to Features. Trigger on tasks like "MutterContainer 등록", "DI 주입", "@Inject 추가", "@LazyInject", "컴포지션 루트".
user-invocable: false
---

# DI (MutterContainer)

`MutterContainer`는 Service Locator 패턴 + 프로퍼티 래퍼.

## 등록

```swift
MutterContainer.shared.register(
  LetterUsecasable.self,
  instance: LetterUsecase(repository: LetterRepository())
)
```

등록 위치: 앱 컴포지션 루트 (`MutterApp` 진입점) 또는 Feature 진입 직전.

## 사용

```swift
@Inject var usecase: LetterUsecasable      // 즉시 resolve
@LazyInject var usecase: LetterUsecasable  // 최초 접근 시 resolve (순환 의존 방지용)
```

- ModelData·Repository 구현체 등 순환 의존 가능 지점은 `@LazyInject` 사용.
- 일반 사용처는 `@Inject` 권장.

## 자가 점검

- 등록 누락 시 런타임 크래시 → 새 UseCase/Repository 추가 시 컴포지션 루트에 register 호출 추가.
- View가 Repository 직접 호출하지 않는지 확인 — UseCase 경유로만 데이터 처리.
- Repository 구현체에서 NetworkAPI 의존성을 `@LazyInject`로 주입했는지 확인.

---
name: ios-navigation
description: Use when adding navigation between screens, modifying AppRoute/AuthRoute, working with NavigationCoordinator, or routing presentFullScreen flows. Trigger on tasks like "화면 전환", "Route 추가", "NavigationCoordinator", "presentFullScreen", "push", "pop".
user-invocable: false
---

# Navigation & Routing

`NavigationCoordinator<Route>` (Combine 기반 Coordinator 패턴).

## 핵심 규칙

- Route는 `enum`으로 정의 (예: `AppRoute`, `AuthRoute`).
- View에서 `@EnvironmentObject`로 주입받는다 — View가 직접 소유 금지.
- **`NavigationLink` 직접 사용 금지** — coordinator 경유.

## 이벤트

`push`, `pop`, `popToRoot`, `presentFullScreen`, `dismissFullScreen`

```swift
@EnvironmentObject private var coordinator: NavigationCoordinator<AppRoute>

coordinator.push(.viewer(token: "abc123"))
coordinator.presentFullScreen(.auth(.signIn))
coordinator.popToRoot()
```

## 구현 참조

`Projects/Router/Sources/`

## 자가 점검

- View에서 `NavigationLink` 직접 사용 → 위반.
- View가 NavigationCoordinator를 자체 소유 → 위반. `@EnvironmentObject`만 허용.
- Feature → Feature 직접 의존 → 위반. Router 또는 Domain 경유로만.
- 새 Route 추가 시 `AppRoute`/`AuthRoute` enum case와 `ViewFactoryProtocol` 매핑 양쪽 갱신.

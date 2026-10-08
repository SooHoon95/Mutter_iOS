---
name: ios-swiftui-pitfalls
description: Use when writing SwiftUI Views with state preservation needs, ScrollView interactions, animations, TabView/NavigationStack flows, or debugging SwiftUI performance issues. Trigger on tasks like "TabView", "NavigationStack", "ScrollView", "onTapGesture", "withAnimation", "성능", "@State", "init() 재호출".
user-invocable: false
---

# SwiftUI 주의사항

## 상태 보존

- `TabView`, `NavigationStack` 등에서 탭/화면 전환 시 `init()` 재호출.
- `@State`가 아닌 `let`/`var` 프로퍼티는 전환 시마다 초기화됨.
- 유지해야 하는 상태(필터 선택, 스크롤 위치 등)는 `@State` 선언 또는 상위 레이어에서 참조 유지.
- **상태 초기화는 `@State private var property = Value()` 형태로 한다** — `self._property = State(initialValue:)` 우회 패턴은 쓰지 않는다.

## ScrollView 내부 탭 인터랙션

- `.onTapGesture` **대신 `Button`**으로 감싼다.
- `.onTapGesture`는 DragGesture와 충돌 해소 비용이 매 뷰 발생 → 복잡한 뷰(이미지, 타이머, 그림자) 많을수록 메인스레드 블로킹.
- `Button`은 SwiftUI가 ScrollView 내부 탭을 내부 최적화.

## 애니메이션 전파

- `withAnimation`은 클로저 내 변경되는 **모든** 바인딩에 전파.
- 탭바 인디케이터처럼 특정 UI에만 적용 시 콘텐츠 교체 영역에 잔상(이전 뷰 fade-out 겹침) 발생.
- 콘텐츠 교체 영역에 `.animation(.none, value: trigger)` 명시 → 전파 차단.

## 성능 디버깅 우선순위

캐시/네트워크/스레딩보다 **뷰 구조 먼저** 점검.

순서:
1. `.onTapGesture` 사용 → `Button` 교체
2. 중첩 `LazyVStack` 검토
3. 제스처/애니메이션 충돌 검토
4. 캐시/네트워크 검토

## 자가 점검

- ScrollView 내부에 `.onTapGesture` 사용 → `Button` 교체.
- TabView/NavigationStack 자식 뷰의 `let` 프로퍼티가 매 전환 초기화되는지 확인.
- `withAnimation`이 콘텐츠 영역까지 잔상 만드는지 확인.
- 부작용을 일으키는 SwiftUI 라이프사이클 호출이 없는지 확인.

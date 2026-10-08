---
name: ios-error-handling
description: Use when adding async calls that can throw, writing ModelData with error state, presenting error alerts in SwiftUI, or converting raw errors to MutterError. Trigger on tasks like "에러 처리", "ModelData", "alert", "MutterError", "toMutterError", "catch".
user-invocable: false
---

# 에러 처리

에러를 던질 수 있는 비동기 호출이 있는 **모든** View/ModelData에 이 가이드를 적용한다.

## 체크리스트

1. ModelData에 `var error: Error?` 프로퍼티
2. 모든 catch에서 `error.toMutterError() ?? MutterError(.unknown)` 변환
3. View에 `.alert(error: $modelData.error)` modifier
4. `import AppFoundation` (`toMutterError()` 사용 위해 필수)

## 패턴

```swift
// ModelData
@Observable
final class HomeModelData {
  var error: Error?

  func load() async {
    do {
      try await usecase.fetch()
    } catch {
      self.error = error.toMutterError() ?? MutterError(.unknown)  // ✅
      // self.error = error                                        // ❌ raw error 금지
    }
  }
}

// View
struct HomeView: View {
  @Bindable var modelData: HomeModelData
  var body: some View {
    Content()
      .alert(error: $modelData.error)
  }
}
```

## 자가 점검

- catch 블록에서 raw error를 그대로 대입했는가? → `toMutterError()` 변환 필수.
- ModelData에 `error: Error?` 누락 없는지.
- View에 `.alert(error:)` modifier 누락 없는지.
- `import AppFoundation` 누락 없는지.

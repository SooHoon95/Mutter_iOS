# new-ios-screen

새 화면(View + ModelData)을 Feature 모듈에 추가한다. 규칙 근거는 `mutter-swiftui`·`mutter-architecture` 스킬.

## 입력

- **모듈명**: Feature 디렉토리 이름 (예: Compose, Viewer, Inbox)
- **화면명**: View 이름 (예: ThreadList)
- **필요한 UseCase** (선택): 의존할 UseCase 프로토콜명 (예: `LetterUsecasable`)

## 작업 절차

1. **분석** — `Projects/Feature/{모듈명}/`의 기존 View(`Sources/public/`)와 ModelData(`Sources/internal/ModelData/`)를 먼저 읽고 import·init·주입 방식을 그대로 따른다(추측하지 않는다).
2. **계획 설명** — 생성할 파일과 역할을 알린다. 3개 이상이면 확인받는다.
   - `Sources/public/{화면명}View.swift` — 공개 View
   - `Sources/internal/ModelData/{화면명}ModelData.swift` — 상태
   - (필요 시) `Sources/internal/SubViews/{서브뷰}.swift`
3. **구현** — 아래 템플릿.
4. **배선** — 이동이 필요하면 `FeatureRoute` case + `RootViewFactory` 매핑, 탭이면 `MutterApp/Sources/ViewWrapper/`에서 usecase 조립·콜백→coordinator 연결.
5. **생성·빌드** — `/tuist-gen` → `/build-ios`. 이후 `/arch-check`.

## 템플릿

### {화면명}View.swift (Sources/public/)

```swift
import SwiftUI

import Domain
import UIComponent

public struct {화면명}View: View {
  @State private var model: {화면명}ModelData
  private let onOpen: (String) -> Void

  public init({usecaseParam}: {UseCase프로토콜}, onOpen: @escaping (String) -> Void) {
    _model = State(initialValue: {화면명}ModelData({usecaseParam}: {usecaseParam}))
    self.onOpen = onOpen
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(L10n.{키}).fonts(.titleLarge).foregroundStyle(Asset.Colors.ink.color)

      if let message = model.errorMessage {
        Text(message).fonts(.caption).foregroundStyle(Asset.Colors.danger.color)
      }
    }
    .task { await model.load() }
  }
}
```

### {화면명}ModelData.swift (Sources/internal/ModelData/)

```swift
import Foundation

import AppFoundation
import Domain

@MainActor
@Observable
final class {화면명}ModelData {
  var isLoading = false
  var errorMessage: String?

  private let {usecaseParam}: {UseCase프로토콜}

  init({usecaseParam}: {UseCase프로토콜}) {
    self.{usecaseParam} = {usecaseParam}
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      // try await {usecaseParam}.…
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.{에러키}
    }
  }
}
```

### 배선 (MutterApp/Sources/ViewWrapper/)

```swift
struct {화면명}ViewWrapperView: View {
  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  private let {usecaseParam}: {UseCase프로토콜}

  init() { self.{usecaseParam} = {UseCase}(repository: {Repository}()) }   // 컨테이너 등록 금지

  var body: some View {
    {화면명}View({usecaseParam}: {usecaseParam}, onOpen: { coordinator.push(.viewer(.token($0, password: nil))) })
  }
}
```

## 완료 체크리스트

- [ ] View에 비즈니스 로직 없음, ModelData가 `@MainActor @Observable`·`internal`
- [ ] 사용자 액션 실패가 `errorMessage`로 드러남(무음 실패 없음), `MutterError.userMessage` 사용
- [ ] Feature View가 coordinator 대신 콜백으로 이동을 알림, `NavigationLink` 없음
- [ ] usecase를 `MutterContainer`에 등록하지 않고 호출부에서 생성자 주입
- [ ] 문자열 `L10n`, 색·이미지 `Asset`, 폰트 `.fonts(...)` — 하드코딩 없음
- [ ] One Type Per File, 서브뷰는 `Sources/internal/SubViews/`
- [ ] 새 파일·L10n 추가 후 `tuist generate`, 빌드 통과

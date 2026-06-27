# new-ios-screen

새 화면(View + ModelData)을 Feature 모듈에 추가한다.

## 입력

- **모듈명**: Feature 디렉토리 이름 (예: Compose, Viewer, Auth)
- **화면명**: View 이름 (예: ComposeEditor, ThreadList)
- **필요한 UseCase** (선택): 의존할 UseCase 프로토콜명 (예: LetterUsecasable)

## 작업 절차 (CLAUDE.md 작업 진행 절차 준수)

### 1단계: 분석

- 대상 모듈 경로 확인: `Projects/Feature/{모듈명}/`
- 먼저 해당 모듈의 기존 View 파일(`Sources/public/`)과 ModelData 파일(`Sources/internal/`)을 읽는다
- 동일 모듈 내 기존 패턴(import 목록, init 구조, 의존성 주입 방식)을 읽은 파일에서 확인한다 (추측하지 않는다)

### 2단계: 구현 계획 설명

생성할 파일 목록과 각 파일의 역할을 사용자에게 설명한다:
- `Sources/public/{화면명}View.swift` — 외부 노출 View
- `Sources/internal/{화면명}ModelData.swift` — 내부 상태 관리
- (UseCase 주입 시) `Sources/public/ViewFactory/{화면명}ViewFactory.swift`
- (서브뷰 필요 시) `Sources/internal/SubViews/{서브뷰명}.swift`

### 3단계: 사용자 확인

파일 3개 이상 생성하는 경우 반드시 사용자 확인을 받는다.

### 4단계: 구현

아래 템플릿에 따라 파일을 생성한다.

### 5단계: 검증

CLAUDE.md "코드 작성 후" 체크리스트를 실행한다.

## 생성 템플릿

### {화면명}View.swift (Sources/public/)

```swift
import SwiftUI
import Router
import UIComponent

public struct {화면명}View: View {
  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  @State private var modelData: {화면명}ModelData

  public init() {
    self.modelData = {화면명}ModelData()
  }

  public var body: some View {
    VStack {
      // TODO: UI 구현
    }
    .alert(error: $modelData.error)
    .onAppear {
      Task { await modelData.onAppear() }
    }
  }
}
```

UseCase 의존성이 있는 경우:

```swift
public init({usecaseParam}: {UseCase프로토콜}) {
  self.modelData = {화면명}ModelData({usecaseParam}: {usecaseParam})
}
```

### {화면명}ModelData.swift (Sources/internal/)

```swift
import Foundation
import AppFoundation

@Observable
final class {화면명}ModelData {
  var isLoading: Bool = false
  var error: Error?

  init() { }

  @MainActor
  func onAppear() async {
    isLoading = true
    defer { isLoading = false }
    do {
      // TODO: UseCase 호출 (async/await)
    } catch {
      self.error = error.toMutterError() ?? MutterError(.unknown)
    }
  }
}
```

UseCase 의존성이 있는 경우:

```swift
private let {usecaseParam}: {UseCase프로토콜}

init({usecaseParam}: {UseCase프로토콜}) {
  self.{usecaseParam} = {usecaseParam}
}
```

### {화면명}ViewFactory.swift (UseCase 주입이 필요한 경우만, Sources/public/ViewFactory/)

```swift
import SwiftUI
import Router
import Domain

public struct {화면명}ViewFactory {
  private let {usecaseParam}: {UseCase프로토콜}

  public init({usecaseParam}: {UseCase프로토콜}) {
    self.{usecaseParam} = {usecaseParam}
  }
}

extension {화면명}ViewFactory: ViewFactory {
  @ViewBuilder
  public func makeView(_ route: {Route타입}) -> some View {
    {화면명}View({usecaseParam}: {usecaseParam})
  }
}
```

## 준수 규칙 (CLAUDE.md 기반)

### One Type Per File
- View, ModelData, ViewFactory는 반드시 별도 파일로 작성한다.
- 단, 해당 파일에서만 사용하는 private enum/protocol은 같은 파일에 허용한다.

### Enum 네이밍 및 사용 규칙
- 카테고리/분류 성질의 `enum`은 `Type` 접미사를 붙인다. (예: `FinanceTabType`, `MyPageMenuItemType`)
- `CaseIterable` + `allCases` 사용을 지양한다. 표시할 항목은 명시적 배열로 정의한다.

### View 작성 규칙
- View는 UI 표현에만 집중한다. Business Logic을 View 내부에 작성하지 않는다.
- View는 가능한 Stateless하게 작성한다. State는 상위에서 주입하고 이벤트는 콜백으로 전달한다.
- `NavigationLink` 직접 사용 금지 → `coordinator.push(...)` / `coordinator.presentFullScreen(...)` 사용
- coordinator는 `@EnvironmentObject`로 주입받는다. 직접 소유하지 않는다.
- 문자열 하드코딩 금지 → `L10n.*` 사용 (새 키 추가 시 `Localizable.strings` 등록 후 `tuist generate` 필요)
- 색상 → `Asset.Colors.*`, 이미지 → `Asset.Images.*`, 폰트 → `.fonts(.)` modifier
- SwiftUI만 사용한다. (UIKit은 쓰지 않는다)

### ModelData 규칙
- `@Observable`을 사용한다. `ObservableObject` + `@Published` 사용 금지.
- `internal` 접근 제한자로 선언하여 Feature 모듈 외부에 노출하지 않는다.
- UseCase를 소유하고 호출한다. Repository를 직접 알지 못한다.
- UI 업데이트 메서드에 `@MainActor`를 명시한다.
- async/await를 사용한다. Completion Handler 방식을 새로 작성하지 않는다.

### 주석 규칙
- 주석은 "왜(Why)"를 설명한다. "무엇(What)"은 코드로 표현한다.
- 주석 처리된 코드(dead code)를 남기지 않는다.

### 서브뷰
- 서브뷰는 반드시 `Sources/internal/SubViews/` 에 별도 파일로 작성한다.

## 완료 후 체크리스트

- [ ] View가 Business Logic을 직접 처리하지 않는가
- [ ] ModelData가 `@Observable`로 선언되었는가 (`ObservableObject` 사용하지 않았는가)
- [ ] ModelData가 `internal`(또는 접근 제한자 미명시)인가
- [ ] UI 업데이트 메서드에 `@MainActor` 명시했는가
- [ ] coordinator를 `@EnvironmentObject`로 주입받고 있는가
- [ ] `NavigationLink`를 직접 사용하지 않았는가
- [ ] 레이어 의존성 방향이 올바른가 (View → ModelData → UseCase)
- [ ] View에 `.alert(error: $modelData.error)` modifier가 있는가
- [ ] ModelData의 catch에서 `error.toMutterError() ?? MutterError(.unknown)`으로 변환하는가 (`self.error = error` 금지)
- [ ] ModelData에 `import AppFoundation`이 있는가
- [ ] One Type Per File 규칙을 준수했는가
- [ ] 새 화면을 `FeatureRoute` + `RootViewFactory`에 등록했는가 (필요 시)
- [ ] 새 파일 추가 후 `tuist generate` 실행 여부 확인

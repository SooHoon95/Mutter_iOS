---
name: mutter-swiftui
description: Mutter iOS에서 SwiftUI View를 작성·수정·검토할 때 참조한다. View 작성 규칙, NavigationCoordinator·AppRoute/FeatureRoute 기반 화면 전환(push/pop/presentFullScreen), ModelData 에러 상태와 화면 표시(errorMessage·MutterError.userMessage), 상태 보존(TabView/NavigationStack init 재호출), ScrollView 탭, 애니메이션 전파, .task(id:) 재로드, WKWebView/AVPlayer 같은 명령형 뷰의 정체성 고정, @Observable과 @Published 혼용 금지를 다룬다.
---

# Mutter SwiftUI

## View 작성 규칙

1. View는 UI 표현만. 비즈니스 로직은 ModelData → UseCase로.
2. 가능한 Stateless — 상태는 상위 주입, 이벤트는 콜백.
3. 서브뷰는 새 파일로 분리(One Type Per File).
4. 문자열 `L10n.*`, 색·이미지 `Asset.Colors.*.color`/`Asset.Images.*`, 폰트 `.fonts(.caption)` 같은 UIComponent modifier. 하드코딩 hex·문자열 없음.
5. ModelData는 `@MainActor @Observable final class`, `internal`. 공개 View가 init 인자(usecase)로 ModelData를 만들 때는 `_model = State(initialValue: XModelData(xUsecase: xUsecase))`.

## Navigation & Routing

`NavigationCoordinator<Route>`(Combine 이벤트 기반). Route는 enum:
- `AppRoute` — 탭(home·threads·inbox·connections·profile)
- `FeatureRoute` — 화면: `.auth(AuthRoute)`, `.compose(ComposeRoute)`, `.viewer(ViewerRoute)`, `.delivery(letterId:)`, `.connect(ConnectRoute)`, `.thread(counterpartId:)`, `.legal(LegalRoute)`

```swift
@EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>

coordinator.push(.viewer(.myLetter(letterId: id)))
coordinator.presentFullScreen(.auth(.signIn))
coordinator.pop() / popToRoot() / popTo(route) / dismissFullScreen()
```

- **Feature View는 coordinator를 모른다.** 화면 이동은 콜백(`onOpen: (String) -> Void`)으로 밖에 알리고, `MutterApp/Sources/ViewWrapper/*ViewWrapperView`가 `@EnvironmentObject` coordinator로 콜백을 route에 연결한다. coordinator를 소유하는 곳은 `MainView`(`@StateObject`)뿐.
- `NavigationLink`를 직접 쓰지 않는다 — coordinator 경유.
- 새 화면은 `FeatureRoute` case + `RootViewFactory` 매핑(+ 탭이면 ViewWrapper·`Router/Sources/ViewProtocol`)을 함께 갱신한다.

```swift
// MutterApp/Sources/ViewWrapper/InboxViewWrapperView.swift
struct InboxViewWrapperView: View, InboxViewable {
  @EnvironmentObject private var coordinator: NavigationCoordinator<FeatureRoute>
  private let inboxUsecase: InboxUsecasable
  init() { self.inboxUsecase = InboxUsecase(repository: InboxRepository()) }
  var body: some View {
    InboxView(inboxUsecase: inboxUsecase, onOpen: { coordinator.push(.viewer(.token($0, password: nil))) })
  }
}
```

## 에러 표시

Repository가 raw 에러를 `MutterError`로 정규화해 던진다(`mutter-networking`). ModelData는 사용자 문구로 바꿔 상태에 둔다.

```swift
@MainActor @Observable
final class HomeModelData {
  var errorMessage: String?

  func delete(_ id: String) async {
    errorMessage = nil
    do { try await letterUsecase.delete(id: id) }
    catch { errorMessage = (error as? MutterError)?.userMessage ?? L10n.errorDelete }
  }
}

// View
if let message = model.errorMessage {
  Text(message).fonts(.caption).foregroundStyle(Asset.Colors.danger.color)
}
```

- 실패를 삼키는 `try?`는 "빈 목록이 정상 상태"인 조회에서만 쓴다(예: Inbox 로드). 사용자가 결과를 기대하는 액션은 errorMessage로 드러낸다.
- 낙관적 업데이트는 실패 시 **그 항목만** 롤백한다(전체 스냅샷 복원은 연속 조작 중 다른 항목을 부활시킨다 — `InboxModelData.delete`).

## 상태 보존

- `TabView`/`NavigationStack` 전환 시 자식 `init()`이 재호출된다. `let`/`var` 프로퍼티는 매번 초기화되므로 유지할 상태는 `@State` 또는 상위 참조로.
- 인자 없는 상태는 `@State private var property = Value()`로 초기화한다. `State(initialValue:)`는 init 인자로 만들어야 할 때만.
- **`@Observable`과 `@Published`(ObservableObject)를 한 타입에 섞지 않는다** — 합성 저장소(`_x`)가 충돌한다. 소비처가 `.environment()`면 `@Observable`만 남긴다.

## `.task(id:)` 재로드

외부 입력(id)에 반응하는 로드를 "이전 결과가 있으면 스킵" 같은 `@State` 가드로 막지 않는다. 뷰가 재사용돼 id가 바뀌어도 이전 값이 non-nil이라 새 로드가 막혀 stale 화면이 남는다(`CachedAsyncImage` 사례). 중복 방지는 id 기반 재실행 + 캐시 계층에 맡기고, 완료 후 `Task.isCancelled`만 확인한다.

## 명령형 뷰(WKWebView·AVPlayerLayer)의 정체성

UIViewRepresentable을 computed 프로퍼티/`AnyView`로 매번 새로 만들어 조건부 마운트하면 부모 재렌더마다 재생성된다. JS 브리지 웹뷰는 재생성되면 네이티브→JS 명령이 죽은 컨텍스트로 가서 **조용히 무음**이 된다. 인스턴스에 묶인 `.id()`로 고정한다.

```swift
if let source = model.player.currentSource, let attachment = source.attachmentView {
  attachment.id(ObjectIdentifier(source))
}
```

비동기 준비가 필요한 재생 소스(SC 위젯 등)는 재생 의도(`wantsPlay`)를 준비 상태와 분리해 기억하고, READY 시 실행한다. 준비 전에 온 명령을 버리지 않는다.

## ScrollView·애니메이션·성능

- ScrollView 안 탭은 `.onTapGesture` 대신 `Button` — 제스처 충돌 해소 비용이 매 뷰에 붙어 메인스레드가 막힌다.
- `withAnimation`은 클로저 안 모든 바인딩 변경에 전파된다. 탭 인디케이터만 움직일 때 콘텐츠 영역에 잔상이 생기면 그 영역에 `.animation(.none, value: trigger)`.
- 성능 이슈는 뷰 구조부터 본다: `.onTapGesture` → 중첩 `LazyVStack` → 제스처/애니메이션 충돌 → 그다음 캐시/네트워크.

## 자가 점검

- `NavigationLink` 직접 사용 없음. Feature View는 콜백으로 이동을 알리고 coordinator는 ViewWrapper에만.
- 사용자 액션 실패가 errorMessage로 드러남(무음 실패 없음).
- 하드코딩 문자열·색 없음(L10n·Asset).
- 명령형 뷰 조건부 마운트에 안정적인 `.id()`가 있음.

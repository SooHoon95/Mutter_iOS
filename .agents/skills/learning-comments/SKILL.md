---
name: learning-comments
description: Use when introducing unfamiliar APIs, frameworks, or patterns into the codebase (AVFoundation, WKWebView+JS bridge, UIViewRepresentable, Combine 신규 패턴 등). Trigger on user phrases like "처음 써봐", "주석 달아줘", "흐름 따라가게", "이해 안 가", "공부 중", "학습용". Overrides the default "minimize comments" rule for THAT specific block of code.
user-invocable: false
---

# 학습용 주석 작성 가이드

사용자가 처음 보는 API/패턴을 도입할 때, 코드를 읽으면서 흐름을 따라갈 수 있도록 **풍부한 한국어 주석**을 단다. 일반 비즈니스 코드는 `ios-coding-conventions`의 "주석 최소" 규칙을 그대로 유지하되, 이 스킬이 트리거되는 블록에만 예외 적용.

---

## 언제 적용하나

### 적용
- 처음 도입하는 **외부 프레임워크/SDK**: AVFoundation(오디오 재생), MediaPlayer(잠금화면·원격 제어), WebKit(WKWebView) 등
- 처음 사용하는 **SwiftUI 고급 API**: `UIViewRepresentable`, `EnvironmentKey`, custom `Layout`, `PreferenceKey`
- 처음 도입하는 **Combine/Concurrency 패턴**: `Subject`, `share()`, `AsyncSequence`, custom `actor`
- 평소 안 쓰던 **시스템 패턴**: JS↔Swift 브리지, `WKUserContentController` 핸들러 등록 같은 순서 의존 API
- 사용자가 직접 "주석 달아줘 / 흐름 따라가게 / 이해 안 가" 라고 말한 코드

### 적용 금지
- 이미 익숙한 패턴(@State, @Binding, 일반 ViewModel 등)
- 짧은 helper 함수, 자명한 변수
- 기존 코드의 단순 수정·리팩토링
- PR review용·changelog성 주석
- 죽은 코드 보존 주석

---

## 작성 형식

### 1. 파일 상단 헤더 박스

새 파일 가장 위에 **무엇/왜** 1~3줄 + 전체 흐름 ASCII 다이어그램.

```swift
// =============================================================================
// SoundCloudWebView
//
// SwiftUI에서 SoundCloud Widget(웹 플레이어)을 띄우기 위한 WKWebView 브리지.
// SwiftUI엔 WKWebView 전용 View가 없어 UIViewRepresentable로 감싼다.
// 위젯의 재생 이벤트(play/pause/finish)는 JS→Swift 메시지 브리지로 받는다.
//
// 전체 흐름 (라이프사이클):
//   makeUIView()      ── 1번만 호출 ── WKWebView 생성 + JS 메시지 핸들러 등록
//          │
//          ▼
//   updateUIView()    ── 부모 리렌더마다 호출 ── 트랙 URL 바뀌면 reload
//          │
//          ▼
//   dismantleUIView() ── 화면에서 제거될 때 ── 핸들러 해제(누수 방지)
// =============================================================================
```

### 2. 단계 번호 주석

순서가 중요한 설정(특히 호출 순서가 결과에 영향을 주는 API)은 `── ① ── ② ──` 표기로 명시.

```swift
// ── ① 설정 객체를 먼저 만들고, WKWebView 생성 "전에" 메시지 핸들러를 붙인다 ──
// JS가 window.webkit.messageHandlers.scBridge.postMessage(...)로 보낸 걸 받는다.
let controller = WKUserContentController()
controller.add(context.coordinator, name: "scBridge")

// ── ② 설정을 webView 구성에 넣는다 ──
let config = WKWebViewConfiguration()
config.userContentController = controller

// ── ③ 설정을 적용해 WKWebView 생성 → 위젯 로드 ──
let webView = WKWebView(frame: .zero, configuration: config)
webView.load(URLRequest(url: widgetURL))
```

### 3. 핵심 라인은 "왜"를 명시

- 자명하지 않은 순서 의존, 스레드 제약, 권한 요구 등은 한 줄 주석.
- "이거 안 하면 무슨 일이 일어나는지" 까지 적기.

```swift
// ⚠ 인라인 재생 허용 안 하면 iOS가 전체화면을 강제 → 인앱 위젯 재생 불가.
config.allowsInlineMediaPlayback = true

// ⚠ 핸들러를 떼지 않으면 controller가 coordinator를 강참조해 메모리 누수.
webView.configuration.userContentController.removeScriptMessageHandler(forName: "scBridge")
```

### 4. 콜백/델리게이트 메서드는 "누가/언제 호출"

UIKit이나 시스템이 호출하는 콜백은 호출 주체와 시점을 명시.

```swift
/// SC Widget이 JS로 postMessage 할 때마다 메인 스레드에서 호출된다.
/// (누가/언제: WebKit이, 위젯 재생 이벤트가 발생할 때.)
/// WKScriptMessageHandler 프로토콜이 강제하는 메서드.
func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { ... }
```

### 5. 타입에는 한 문장 요약

`struct`/`class`/`enum`/`protocol` 선언 위에 한 문장.

```swift
/// SC Widget이 보내는 재생 이벤트. SwiftUI 쪽에서 분기하기 좋게 enum으로.
enum SCWidgetEvent: String { case ready, play, pause, finish, unknown }
```

---

## 분량 가이드

- 짧은 라인 주석은 코드 한 줄당 1~2줄 이내.
- 헤더 박스는 길어도 무방하지만 6줄 안에 핵심이 들어와야 함.
- **주석이 코드보다 길면** OK (학습이 목적이라는 신호). 단, 자명한 줄에는 달지 않음.

---

## 우선순위 / 충돌

- 일반 컨벤션과 충돌 시: 이 스킬이 활성화된 **그 블록만** 예외.
- 같은 파일의 다른 블록(자명한 비즈니스 로직)은 `ios-coding-conventions` 그대로.
- 추후 사용자가 코드를 익히고 "주석 줄여줘"라고 하면 정리 패스를 별도로 수행.

---

## 모범 사례 (이 프로젝트의 "낯선 API" 지점 — 첫 도입 시 이 가이드 적용)

- **AudioSync `SoundCloudSource`** — UIComponent `WKWebViewContainer`(WKWebView + SC Widget JS 브리지). 순서 의존·메모리 누수 주의 지점.
- **AudioSync `HostedAudioSource`** — AVPlayer + `AVAudioSession(.playback)` + `MPNowPlayingInfoCenter`/`MPRemoteCommandCenter`(잠금화면·백그라운드 재생).

---

## 트리거 자체 점검

이 스킬을 적용해야 하는데 깜빡하는 경우를 막기 위한 self-check:

- "이 코드 패턴을 사용자가 본 적 있는가?" — 모르겠으면 적용.
- 사용자가 "주석 / 흐름 / 이해" 어휘를 1번이라도 쓰면 적용.
- 새 외부 프레임워크 import 발생 시 적용.
- 작업이 끝나면 사용자에게 "주석 분량 적절한가" 1회 확인.

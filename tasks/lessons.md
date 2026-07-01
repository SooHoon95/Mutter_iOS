# Lessons — 자기 교정 누적

사용자 교정이 발생할 때마다 최신 항목을 위로 추가한다. (`self-improvement` 스킬 규약)

### 2026-07-01 — [재발] 카탈로그 2개 회귀가 또 터짐 (claude_design 임포트가 Images.xcassets 재생성)
- 상황: 디자인 MCP로 이미지를 임포트하는 과정에서 별도 `Images.xcassets`가 다시 생성됨 → 2026-06-30 함정 ③ 그대로 재발. `Asset.Colors.Colors.gold`로 밀려 `MutterGradient.swift` 등 전부 컴파일 실패(빌드가 `Asset.Colors.gold`부터 못 찾음). 원인은 stencil 133행 `{% if catalogs.count > 1 %}`가 카탈로그명 래퍼를 켜는 것 — 근본은 "카탈로그가 2개가 됐다".
- 조치: `Images.xcassets`의 `Images/`·`Social/`를 `Colors.xcassets/`로 이동, `Images.xcassets` 삭제 → 다시 카탈로그 1개. (`Social/`엔 provides-namespace 추가.)
- **가드(에셋 임포트/디자인 반영 직후 필수)**: `find Projects/*/Resources -name '*.xcassets' -type d` 가 **정확히 1개**인지 확인. 2개 이상이면 즉시 하나로 병합(분류는 provides-namespace 하위 폴더로). 임포트 도구가 새 카탈로그를 만드는 경향이 있으니 임포트 후 항상 검사한다. → [[mutter-build-progress]]

### 2026-06-30 — Tuist 에셋 카탈로그에 이미지 추가 시 3가지 함정 (색 네임스페이스가 조용히 깨짐)
- 상황: 디자인 시스템 SVG 아이콘을 iOS에 적용하려 Images.xcassets를 추가했더니 빌드가 3번 연속 다른 이유로 깨짐. 각 함정:
  - ① **stencil availability 충돌**: `Tuist/ResourceSynthesizers/Assets.stencil`이 iOS에서 `Color`/`Image`를 SwiftUI 타입(iOS 13+)으로 typealias하면서 그 확장/프로퍼티 init엔 UIKit 시절 `@available(iOS 8/11)`를 박음 → "initializer cannot be more available than enclosing scope". 이미지가 있을 때만 풀 템플릿이 트리거돼 드러남. → stencil의 해당 `@available`를 iOS 13.0으로 수정.
  - ② **네임스페이스 폴더에 느슨한 콘텐츠 섞으면 카탈로그명 래퍼 발생**: `Colors.xcassets`가 네임스페이스 폴더(`Colors/`·`Theme/`)만 가질 땐 `Asset.Colors.ink`(폴더=최상위). 거기에 네임스페이스 아닌 `Semantic/` 폴더를 추가하니 카탈로그명 래퍼가 생겨 `Asset.Colors.Colors.ink`로 중첩 → 기존 `Asset.Colors.ink` 전부 깨짐. → 시맨틱 색을 기존 `Colors/` 폴더 안으로.
  - ③ **카탈로그 2개가 되면 SwiftGen이 파일명으로 네임스페이스**: 별도 `Images.xcassets`를 추가하니 `Colors.xcassets`도 `Asset.Colors.Colors.*`로 밀림. → 별도 카탈로그 대신 기존 `Colors.xcassets/Images/`(provides-namespace 폴더)로 통합해 **카탈로그를 1개로 유지**.
- 규칙: **Tuist 단일 모듈에선 에셋 카탈로그를 1개로 유지하고, 분류는 provides-namespace 하위 폴더로 한다(Colors/·Theme/·Images/).** 카탈로그를 새로 추가하거나 네임스페이스 폴더 옆에 느슨한 콘텐츠를 두면 기존 `Asset.X.*` 접근자가 한 단계 밀려 전부 깨진다. SwiftUI 타입을 쓰는 stencil은 `@available`를 iOS 13 이상으로. 그리고 **새 .swift 파일은 `tuist generate`로 프로젝트에 포함시킨 뒤** 빌드(안 하면 "cannot find X in scope").

### 2026-06-30 — 서비스 로케이터엔 전역만, usecase/repository는 호출부 생성자 주입 (Mercury 패턴 검증)
- 상황: `AppDependencies.registerAll()`이 usecase 11개를 전부 `MutterContainer`(서비스 로케이터)에 등록하고, RootViewFactory·탭 ViewWrapper 6개가 `@Inject`로 꺼내 썼다. 사용자 지적: "당장 안 쓰는 usecase까지 다 전역에 들고 있는 건 Mercury 방식이 아니다. Mercury는 SessionManager 같은 진짜 전역만 로케이터에 넣고 usecase는 DI(생성자 주입)로 준다."
- 검증: 실제 Mercury(`/Users/choesuhun/Desktop/Code/Mercury`) 확인 결과 정확히 그러함. 로케이터 register = 전역 cross-cutting만(SignInInformationManager=세션/토큰, Toast/Alert/Loading/Config). usecase·repository **0개**. usecase는 `RootViewFactory` 각 case와 `*ViewWrapperView.init()`에서 `XUsecase(repository: XRepository())`로 **그 자리에 인라인 조립 → 생성자 주입**.
- 교정: Mutter도 동일하게. `AppDependencies` god-object 삭제. `AppDelegate.didFinishLaunching`은 전역(`SessionManagable`)만 등록. RootViewFactory·6개 ViewWrapper의 `@Inject` 제거하고 호출부에서 usecase 인라인 생성(repo는 이미 `provider: SupabaseProvider = .shared` 기본값이라 `LetterRepository()` 무인자 가능). 코디네이터 콜백 때문에 init에서 피처뷰 전체를 못 만드는 래퍼는 **usecase만 init에서 `let`으로 조립**하고 body에서 피처뷰+코디네이터 클로저 구성. 남은 `@Inject`는 `sessionManager`(전역) 둘뿐.
- 규칙: **서비스 로케이터/DIContainer엔 앱 전체가 공유하는 진짜 전역(세션·토스트·얼럿·로딩·config)만 등록한다.** usecase/repository는 컨테이너에 넣지 말고 의존성 방향대로 호출부(Factory·ViewWrapper)에서 생성자 주입한다. `@Inject`(호출부 주입)도 결국 전역 로케이터를 찌르는 것이므로, usecase에 `@Inject`를 쓰면 그게 곧 "전역 등록"이다 — 둘은 한 몸. 클론 프로젝트의 DI 방식은 **원본(Mercury) 실제 코드**로 확인해 맞춘다(추정 금지).

### 2026-06-29 — 다중 파일 일괄 치환 루프는 zsh `read -d ''`로 짜지 말 것 — 조용히 0건 처리
- 상황: `MutterColor.X`→`Asset.Colors.X.color`를 24개 파일에 일괄 치환하려고 `grep -rlZ ... | while IFS= read -r -d '' f; do perl -pi -e ... "$f"; done`을 돌렸다. 에러 없이 끝났지만 **치환이 하나도 안 됐다**(직후 grep으로 잔존 전부 확인). 원인: Claude Bash가 zsh로 초기화돼 `read -r -d ''`의 빈-구분자 시맨틱이 bash와 달라 루프 본문이 안 돌았다. "exit 0 + 무변경"이라 성공으로 오인하기 쉬움.
- 교정: `grep -rl "패턴" Projects --include="*.swift" | xargs perl -pi -e 's/.../.../g'`로 전환(파일명 공백 없음 확인). 치환 직후 **반드시 `grep`으로 잔존=0 검증**.
- 규칙: **이 저장소(zsh Bash)에서 다중 파일 일괄 치환은 `while read -d ''` 루프 대신 `grep -rl | xargs perl -pi -e`를 쓴다.** 균일 토큰 치환은 파일별 Read+Edit보다 스크립트가 빠르고 정확하되, 실행 후 grep으로 잔존 0과 의도치 않은 과치환(예: 복합값 `goldGradient`)을 동시에 확인한다. "에러 없음"을 "치환됨"으로 단정 금지.

### 2026-06-29 — 리소스 추가/수정 후엔 Clean Build Folder 안 하면 "안 고쳐진 것처럼" 보인다
- 상황: 번들 음원·웹뷰 fix·SC 레이스 fix를 차례로 넣었는데 사용자가 계속 "안 된다"고 함. 원인은 코드가 아니라 **빌드 캐시** — Xcode가 옛 산출물(리소스 번들 포함)을 재사용해 내 변경이 앱에 반영 안 됨. 사용자가 캐시를 날리자 그제서야 모든 fix가 한꺼번에 적용돼 동작. 디버깅이 "되는데/안 되는데"로 흔들려 시간 낭비.
- 교정: 리소스(오디오·이미지·xcassets·tracks.json 등) 추가/변경 시 **반드시 `Clean Build Folder`(⇧⌘K) 후 Run**. 무음/무반응이 코드 수정 후에도 지속되면 "런타임 버그"로 단정 말고 **"옛 빌드를 돌리고 있나?"를 먼저 의심**.
- 규칙: **리소스 번들에 영향 주는 변경 후 사용자에게 검증을 요청할 땐, 항상 "앱 삭제 + Clean Build Folder + Run"을 명시**한다. 내가 시뮬레이터를 직접 못 돌릴 땐 진단 로그(os.Logger category)를 심어 사용자 콘솔로 실패 지점을 받되, 먼저 클린 빌드부터 확인시킨다(stale 빌드면 로그조차 옛 코드 것).

### 2026-06-29 — SoundCloud Widget은 READY 전에 play()가 오면 무음 — 소스가 재생의도(wantsPlay)를 기억해 READY 시 자동재생
- 상황: SC가 미리보기에서 무음. 로그 순서가 `SC play() ready=false` → (웹뷰 로드) → `SC READY 수신` → `tryLoad 성공`. 즉 위젯 준비 **전에** `play()`가 호출돼 `window.scPlay` 미정의로 no-op 됐고, READY 후엔 아무도 재생을 재요청 안 해 영영 무음. (READY 자체는 정상 수신 = 위젯 로드는 성공.)
- 교정: `SoundCloudSource`에 `wantsPlay` 플래그 — `play()`는 항상 의도를 기록하고 `isReady`면 즉시 JS, 아니면 보류. READY 핸들러에서 `wantsPlay`면 그 때 재생. `pause()`는 `wantsPlay=false`. 추가로 Compose `previewAudio`를 toggle→명시적 play/pause + `isPreparingPreview` 가드(준비 중 중복 탭에 의한 소스 중복 로드·toggle→pause 자기무효화 방지).
- 규칙: **비동기 준비(WKWebView/위젯/원격 로드)가 필요한 재생 소스는 "재생 의도"를 준비 상태와 분리해 보관하고, 준비 완료 시 의도를 실행한다.** 준비 전에 온 제어 명령을 버리지 말 것. 호출부도 await-준비-후-재생 흐름에서 중복 진입을 가드한다.

### 2026-06-29 — SwiftUI에서 숨김 WKWebView(오디오)를 마운트할 땐 `.id(ObjectIdentifier(source))`로 고정
- 상황: SoundCloud 트랙이 미리보기에서 무음(호스티드 CC0 패드는 정상). 숨김 WKWebView를 `if let attachment = source.attachmentView { attachment }`로 마운트하는데, `attachmentView`가 매 접근마다 `AnyView(MutterWebView(...))`를 새로 생성. 부모 뷰가 재렌더(isPlaying/isReady 변화 등)되면 SwiftUI가 WKWebView를 재생성 → 위젯 JS 컨텍스트(`window.scPlay`)가 날아가 `play()`가 no-op → 무음(또는 READY 후 webview 교체로 제어 단절).
- 교정: `if let source = model.player.currentSource, let attachment = source.attachmentView { attachment.id(ObjectIdentifier(source)) }`. 소스 인스턴스 ID로 뷰 정체성을 고정 → 소스가 바뀔 때만 webview 교체, 재렌더엔 유지. (WebView 설정 자체는 정상: `allowsInlineMediaPlayback=true` + `mediaTypesRequiringUserActionForPlayback=[]`. 1×1 숨김 webview 오디오 throttling은 다음 의심 후보.)
- 규칙: **명령형 상태(WKWebView·AVPlayerLayer 등)를 담은 UIViewRepresentable을 computed 프로퍼티/AnyView로 매번 새로 만들어 조건부 마운트할 땐, 인스턴스에 묶인 안정적 `.id()`를 줘서 재렌더 시 재생성을 막는다.** 특히 JS 브리지로 제어하는 웹뷰는 재생성되면 네이티브→JS 명령이 죽은 컨텍스트로 가 조용히 실패한다. 무음/무반응이면 "뷰가 재생성되고 있나?"를 먼저 의심.

### 2026-06-29 — 웹 상대 에셋경로(`/audio/x.m4a`)는 iOS에서 무음 — 번들 포함 + 재생시점 해석 필요
- 상황: 기본 제공 CC0 음악이 iOS에서 안 들림. 원인: 카탈로그(`tracks.json`)의 `url`이 웹용 상대경로 `/audio/pixabay-calm-001.m4a`. 웹은 origin에 붙어 재생되지만, iOS `AVPlayer`는 스킴·호스트 없는 상대경로를 못 푼다. 게다가 `.m4a` 파일이 **웹 `public/audio`에만 있고 iOS 번들엔 미포함**이었다. `URL(string:"/audio/..")`는 nil이 아니라 통과해버려(상대 URL) 에러 없이 **조용히 무음** → 재생 실패가 안 보였다.
- 교정: ① 6개 `.m4a`를 `Projects/Infrastructure/Resources/audio/`에 번들(Tuist `Resources/**` 글로빙 → `Infrastructure_Infrastructure.bundle/`에 flat 포함, 빌드 산출물에서 확인). ② cue `ref`는 **이식가능 상대경로 그대로 유지**(웹·수신자·크로스기기 호환)하고, **재생 시점에만** `CatalogRepositorable.localAudioURL(for:)`(기본 nil + Infra 구현)로 번들 파일 URL 해석. `AudioUsecase.resolvePlayback`의 hosted 분기에서 로컬 우선·없으면 원격 폴백.
- 규칙: **웹→iOS 포팅 시, 웹에서 origin-상대로 동작하던 에셋경로(오디오·이미지)는 iOS 앱 번들에 실제 파일을 포함하고 재생/표시 시점에 번들 URL로 해석한다.** 절대 파일 URL을 영속 데이터(cue/letter)에 저장하지 말 것(기기·번들 경로가 달라 수신자/크로스기기에서 깨진다) — 영속값은 이식가능 상대경로로, 해석은 플랫폼별 경계(Repository/Usecase)에서. `URL(string:)`이 상대경로에 대해 nil을 안 주므로 "주소 유효=재생 가능"으로 착각 금지.

### 2026-06-29 — 비대화형 셸의 `tuist`는 mise 핀 버전이 아니라 전역(4.20.0)이 잡혀 그래프 디코드가 깨진다
- 상황: 세션 초반엔 통과하던 `tuist generate`/`build`가 갑자기 `DecodingError.keyNotFound: Key 'name' not found ... Path: targets[3].settings[0]`로 실패. 매니페스트·소스는 안 건드렸는데도 그래프 로딩 자체가 깨짐. 원인: 활성 `tuist`=**4.20.0**(homebrew 전역)인데 프로젝트 `.mise.toml` 핀=**4.118.0**. 구버전(4.20) 디코더가 신버전(4.118) `Settings`/`Configuration` 스키마(`name` 키)를 못 읽음. Claude의 Bash는 비대화형이라 mise shim이 PATH에 없어 전역 바이너리가 잡힘(대화형 셸에선 mise 활성화돼 4.118이 잡혀 통과했던 것).
- 교정: tuist를 **항상 `mise exec -- tuist ...`로** 호출(핀 버전 강제). `mise which tuist`로 핀 경로 확인(`~/.local/share/mise/installs/tuist/4.118.0/tuist`).
- 규칙: **이 저장소에서 tuist/xcodegen 등 mise로 핀된 툴은 Bash에서 반드시 `mise exec -- <tool>` 접두사로 실행한다.** 맨 `tuist`는 전역(4.20.0)이라 매니페스트 디코드가 깨진다. "전엔 됐는데 갑자기 디코드 에러" = 버전 불일치 의심 → `tuist version` vs `.mise.toml` 핀을 먼저 대조.

### 2026-06-28 — Feature 모듈명이 의존 SDK 모듈명과 충돌하면 합성 루트에서 깨진다
- 상황: feature 모듈 `Auth`가 supabase-swift의 `Auth` 모듈과 동명. 개별 빌드는 OK(Auth feature는 supabase 미링크)지만, **MutterApp이 둘 다 링크**하자 `import Auth`가 supabase Auth로 해석돼 `cannot find 'AuthViewFactory' in scope`.
- 교정: feature를 `AuthFeature`로 rename(디렉터리 `git mv` + Project.swift name + `.feature(target:)` 의존 + `import` 전부). `.featurePath(target)=Projects/Feature/<target>`라 디렉터리명=타깃명 일치 필요.
- 규칙: **모듈/타깃 이름은 링크될 모든 외부 SDK 모듈명과 겹치지 않게 짓는다**(supabase: Auth/Storage/Functions/Realtime/PostgREST, Firebase 등). 충돌은 단일 모듈 빌드에선 안 보이고 **합성 루트(앱)에서만** 터진다 — 앱 빌드까지 가야 발견된다.

### 2026-06-28 — Swift 호환성 심볼 링크 에러(swiftCompatibility56/Concurrency)는 의존 정리/정적링크로
- 상황: 전체 앱 링크에서 `Undefined symbols: __swift_FORCE_LOAD_$_swiftCompatibilityConcurrency` 실패. 출처는 `GTMAppAuth`(GoogleSignIn 전이 의존) — 낮은 배포타깃으로 컴파일돼 compat 셰임을 강제로드하는데 앱 링크에서 못 찾음. (앞서 동일 증상이 동적 FirebaseCore에서도 났고 `.staticFramework`로 해결.)
- 교정: GoogleSignIn/Kakao는 **코드에서 미사용**(소셜 보류)이라 MutterApp deps에서 **제거**(미사용 의존이 깨진 링크를 끌고 들어옴). Firebase는 `Tuist/Package.swift`에서 `.staticFramework`로 둠.
- 규칙: **`__swift_FORCE_LOAD_$_swiftCompatibility*` 링크 실패 = 어떤 SPM 산물이 낮은 배포타깃으로 compat 셰임을 강제로드하는 것.** 해당 산물이 미사용이면 의존에서 제거하고, 필요하면 `PackageSettings.productTypes`에서 `.staticFramework`로(또는 배포타깃 상향). 재도입 시(예: 네이티브 Google 로그인) 같은 처리 필요.

### 2026-06-28 — `tuist build | tail`은 빌드 실패를 가린다 (파이프 종료코드)
- 상황: `mise exec -- tuist build X 2>&1 | tail -12`를 `run_in_background`로 돌렸더니 완료 알림이 "exit code 0"이라 그린으로 오인할 뻔했다. 실제로는 `tail`의 종료코드(0)였고 tuist는 error 65로 실패(FirebaseCore Ld 링커 에러)였다.
- 교정: 출력 **내용**을 `grep -E 'Build Succeeded|BUILD FAILED|error:'`로 확인하거나, `set -o pipefail`을 켜고 `> file 2>&1; echo "exit=$?"`로 tuist의 진짜 종료코드를 잡는다.
- 규칙: **빌드/테스트를 파이프(`| tail`/`| grep`)로 넘길 땐 종료코드를 신뢰하지 않는다.** `set -o pipefail`을 쓰거나 산출물 텍스트에서 성공/실패 토큰을 직접 확인한다. 백그라운드 작업의 "exit 0"도 파이프 끝 명령의 코드일 수 있다.

### 2026-06-28 — `.task(id:)` 재로드를 `@State` 가드로 막지 말 것 (셀프리뷰 발견)
- 상황: `CachedAsyncImage`에서 `.task(id: url)` 안의 `load()`에 `if uiImage != nil { return }` 가드를 뒀다. 빌드는 그린이지만, 뷰가 재사용되어 `url`이 바뀌면 `uiImage`는 아직 이전 이미지(non-nil)라 가드가 새 url 로드를 막아 **stale 이미지**가 남는다(리스트 셀 재활용·아바타 교체).
- 교정: 가드 제거. `.task(id:)`가 이미 id별 1회 실행·취소를 보장하므로, 로드는 매 id마다 수행하고 `Task.isCancelled`만 확인한다(메모리 캐시 히트면 즉시).
- 규칙: **`.task(id:)`/`.onChange`로 외부 입력에 반응하는 뷰에서, 재실행을 "이전 결과가 있으면 스킵"하는 `@State` 가드로 억제하지 않는다.** 중복 방지는 id 기반 재실행 + 캐시 계층에 맡기고, 비동기 완료 후엔 `Task.isCancelled`로 취소를 확인해 stale 커밋을 막는다. 컴파일 그린 ≠ 동작 정확 — 뷰 재사용 시나리오를 항상 점검한다.

### 2026-06-27 — 색·리소스는 Asset 카탈로그 + SwiftGen(`Asset.Colors`)로, hex 확장 금지
- 상황: AppFoundation에 `Color(hex:)` 확장을 만들어 색을 직접 다루려 했다.
- 교정: "Asset 카탈로그에 디자인 시스템으로 만들고 `Asset.Colors.x.color`(Tuist SwiftGen 생성)로 써라. 모르면 Mercury 봐라."
- 규칙: **색/이미지 리소스는 `Resources/Assets/*.xcassets`(colorset) + `swiftgen.yml`(Tools/swiftgen)로 `Asset.Colors.*`/`Asset.Images.*` 타입세이프 접근자를 생성해 쓴다.** 코드 hex 확장 금지. 디자인 토큰은 **UIComponent** 소관(AppFoundation 아님). 표준 패턴 = Mercury `Projects/UIComponent/Resources/Assets/` + `swiftgen.yml`.

### 2026-06-27 — 클론 식별자는 "원본 스캐폴드"를 보고 정한다 (설계문서만 믿지 말 것)
- 상황: 에러 타입을 `module-architecture.md`(설계 SSOT)가 `AppError`(제네릭)로 적어 그대로 따랐는데, DI 컨테이너는 `MutterContainer`(브랜드명)라 명명 규칙이 어긋났다.
- 교정: 사용자가 "Mercury 보고 정하라" → 원본 Mercury는 `MercuryError`·`MercuryContainer`로 **전부 프로젝트명 브랜딩**. 따라서 Mutter는 `MutterError`가 정합 → `AppError`→`MutterError` 전수 플립.
- 규칙: **1:1 클론 프로젝트의 식별자 명명은 원본 스캐폴드(Mercury)의 실제 코드를 근거로 정한다.** 파생 설계문서가 제네릭명을 써도, 원본이 브랜드명이면 클론도 브랜드명으로 맞춘다. 설계문서 ≠ 최종 근거.

### 2026-06-27 — 스캐폴드 클론의 잔재 이름은 "전수" 교정한다
- 상황: 하네스가 여러 템플릿(TheReader/Aluminum/AFin) 클론이라 식별자 잔재가 많았는데, 1차 교정에서 사용자가 콕 집은 `ReaderContainer` 토큰만 바꾸고 끝냈다. `AluminumApp`·`AFinApp`·`AFinError`·`BookSearch*`·`thereader.io`·`ISBNScanner`(Scan 피처) 등이 남아 사용자가 "왜 계속 다른 프로젝트 이름을 쓰냐"고 두 번 교정했다.
- 교정: "이건 The Reader 프로젝트가 아니다 — Mutter에 맞게 전부 수정하라."
- 규칙: **스캐폴드/클론을 다룰 때, 사용자가 이름 하나를 지적하면 그 토큰만 고치지 말고 "모든 템플릿 출처"를 grep으로 전수 매핑한 뒤 일괄 교정한다.** 기준은 원본 스캐폴드(Mercury) + SSOT(`docs/specs/module-architecture.md`·CLAUDE.md 사실)이며, 추정 이름 대신 정본 식별자(MutterContainer/MutterError/SupabaseProvider…)에 맞춘다. 교정 후 `잔재=0`을 grep으로 증명한다.

### 2026-06-27 — gitignore된 하네스 파일은 재귀 grep이 건너뛴다
- 상황: 재귀 `grep`(rg alias)이 `.gitignore`를 존중해 `CLAUDE.md`·`.claude/**`(전부 gitignore 대상)를 스캔에서 누락 → 잔재를 못 찾을 뻔했다.
- 교정: 직접 파일 지정 / `rg -uu`로 무시 규칙을 끄고서야 잡혔다.
- 규칙: **하네스 문서(gitignore 대상)를 검색·검증할 땐 항상 `rg -uu`(또는 `--no-ignore`)를 쓴다.** 일반 재귀 grep의 "0건"을 무결로 신뢰하지 않는다.

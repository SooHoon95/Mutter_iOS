# Lessons — 자기 교정 누적

사용자 교정이 발생할 때마다 최신 항목을 위로 추가한다. (`self-improvement` 스킬 규약)

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

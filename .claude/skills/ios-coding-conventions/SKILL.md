---
name: ios-coding-conventions
description: Use when creating new Swift files, writing SwiftUI Views, naming types/enums, adding comments, or preparing commits. Trigger on tasks like "새 파일", "View 작성", "L10n", "Asset", "커밋", "주석", "naming".
user-invocable: false
---

# 코딩 컨벤션

## 파일 단위

1. **One Type Per File**: 한 파일에 하나의 `struct` / `class` / `protocol` / `enum`.
2. 단, 1번 파일 내부에서만 쓰이는 Enum/Protocol은 같은 파일 허용.
3. 서브뷰는 새 파일로 분리.
4. 새 파일은 필요할 때만 생성한다.

## 네이밍

- 카테고리/분류 enum은 `Type` 접미사 (`LetterDirectionType`, `MusicSourceType`).
- `CaseIterable + allCases` 지양 — 표시 항목은 명시적 배열로 정의.
- 동일 의미의 enum이 Domain에 이미 있으면 재활용. 중복 정의 금지.

## View 작성

1. View는 UI 표현에만 집중. Business Logic을 View에 두지 않는다.
2. 상태는 UseCase 또는 ModelData에서 받는다.
3. 가능한 Stateless — State는 상위 주입, 이벤트는 콜백 전달.
4. **`NavigationLink` 직접 사용 금지** — coordinator 경유 (`ios-navigation` 참조).
5. 문자열은 `L10n.*` (SwiftGen 생성) 사용. 하드코딩·매직스트링 금지 → `Localizable.strings`에 정의.
6. 색상/이미지: `Asset.Colors.*`, `Asset.Images.*`.
7. 폰트: UIComponent의 `MutterFont` 폰트 modifier (예: `.mutterTitle()`).

## 비동기

- async/await 사용. Completion Handler 신규 작성 금지.
- `@MainActor`는 UI 업데이트가 필요한 함수/클래스에만 명시.

## 외부 의존성

- 네트워크·저장소 등 외부 의존성은 Infrastructure Layer에서만 사용.
- UI 컴포넌트는 UIComponent 모듈의 디자인 시스템 사용.

## 주석

1. "왜(Why)"를 설명. "무엇(What)"은 코드로 표현.
2. 복잡한 로직/비즈니스 규칙은 `private` 코드에도 주석 허용 (예외).
3. 주석 처리된 dead code 커밋 금지.

## 커밋

prefix: `feat · fix · style · refactor · test · docs · build · chore · ci · WIP`

체크리스트:
1. 포함되면 안 될 파일이 staging 되지 않았는가
2. 각 커밋이 단일 목적을 가지는가
3. 메시지가 변경 내용을 정확히 표현하는가
4. **Co-Authored-By 포함 금지**

## 빌드/생성

- 파일 추가/삭제, Asset/L10n 변경 시 `tuist generate` 실행.

## 자가 점검 (커밋 전)

- One Type Per File 준수.
- 의존 방향 위반 없음 (`ios-architecture` 참조).
- View가 UseCase/ModelData를 경유해 로직 처리.
- Domain이 UIKit/SwiftUI에 비의존.
- `NavigationLink` 직접 사용 없음.
- 하드코딩 문자열 없음 (L10n 사용).

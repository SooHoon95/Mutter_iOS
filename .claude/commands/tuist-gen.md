# tuist-gen

Tuist로 Xcode 프로젝트를 (재)생성한다.

새 파일 추가/삭제, Asset 추가/삭제, L10n 추가/삭제 시 반드시 실행해야 한다. (CLAUDE.md 팀 규칙 #10)

## 실행

```bash
tuist generate
```

## 성공 시

생성된 파일 경로를 출력한다:
- `Mutter.xcworkspace`
- 각 모듈의 `.xcodeproj`

## 실패 시 — 에러 유형별 대처

### 의존성 오류 (`Cannot find target`)

1. 오류 메시지에서 누락된 타겟명 추출
2. 해당 모듈의 `Project.swift` 읽기
3. `MutterApp/Project.swift`의 의존성 목록에 `.feature(target:)` 또는 `.target(name:)` 누락 여부 확인
4. CLAUDE.md의 "허용되는 의존 관계" 규칙을 준수하며 수정

### Swift Package 오류 (`Package resolution failed`)

```bash
tuist install
tuist generate
```

### 설정 파일 오류 (`XCConfig not found`)

- `XCConfigs/` 디렉토리에 `Debug.xcconfig`, `Stage.xcconfig`, `Release.xcconfig` 존재 여부 확인
- `Tuist/ProjectDescriptionHelpers/Path+Extension.swift`의 `xcconfigPath` 경로와 실제 파일 경로 비교

### Tuist 버전 불일치

```bash
mise install
tuist generate
```

## 관련 명령어

```bash
tuist build              # 빌드
tuist test               # 테스트
tuist clean && tuist generate  # 캐시 초기화 후 재생성
```

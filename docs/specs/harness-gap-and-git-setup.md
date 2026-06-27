# Spec: 하네스 갭 보강 + git 셋업 + 민감정보 분리 (DeepInterview 산출)

## 메타데이터
- 출처: DeepInterview (4 라운드), 다음 단계 = ralplan → ralph
- 유형: brownfield (Mutter Tuist 프로젝트 + 기존 하네스 존재)
- 최종 모호도: ≈ 14% (임계 20% 통과)
- 작성 맥락: heyratel "도구가 아니라 기준으로" 글의 AI 에이전트 환경을 Mutter에 적용
- 대상 리포: `~/Desktop/Code/Mutter` → 원격 `https://github.com/SooHoon95/Mutter_iOS.git`

## 목표 (Goal)
Mutter에 **이미 존재하는 하네스를 글의 4가지 기준으로 감사**하고, **빠진 부분(갭)만 보강**한다. 동시에 **로컬 Mutter를 git 리포로 만들어 Mutter_iOS 원격에 푸시**하고, **민감정보를 git에서 완전히 분리**한다. "맨바닥 구축"이 아니라 "감사 + 갭 클로징 + 셋업".

## 확정된 결정 (Decisions)
1. **범위** = 기존 하네스 감사 → 갭만 보강 + git/secrets 마무리. (풀 리빌드 아님)
2. **하네스 커밋 정책** = **표준은 커밋 / 런타임은 무시.**
   - 커밋: `CLAUDE.md`, `.claude/skills/`, `.claude/commands/` (= "기준", 글의 공유 철학).
   - 무시: `.omc/`(Ralph 런타임 상태), `agent_docs/`, 모든 비밀값.
3. **모델/리뷰 전략** = 구현 **Sonnet** · 판단 **Opus advisor** · 리뷰 게이트 **Claude(OMC `critic`/`code-reviewer`)**.
4. **Codex 전면 미사용** = 글의 `codex-opinion`·Codex 리뷰어·Codex용 `AGENTS.md` 심볼릭·`.codex/` 화이트리스트는 **빼고** Claude 네이티브로 대체. (이유: correlated-error 다양성은 포기, 단일 벤더 즉시 가용 우선 — 사용자 명시 결정)
5. **민감정보** = 실값과 예시(`Sensitive.xcconfig.example`) **둘 다 커밋 제외**. 키 스키마조차 리포 비노출. 온보딩 안내는 README 한 줄 + Notion.

## 비목표 (Non-Goals)
- 글의 `mission` 오케스트레이터·`grill-me`·`epic`·`pr`/`pr-review` 등 **신규 워크플로 스킬 작성** (ralplan/ralph/critic으로 충당).
- 교차벤더(Codex/Gemini) 리뷰 통합.
- iOS 기능 코드 구현(별도 작업).
- `Sensitive.xcconfig.example` 커밋.

## 완료 기준 (Acceptance Criteria)

### A. Git 셋업·푸시
- [ ] `git init` + `main` 브랜치, 원격 `Mutter_iOS` 연결.
- [ ] 원격 기존 커밋(`9912e86`) 검사 후 **조건부 정합**: bare-init(README/LICENSE/.gitignore류)이면 그 위에 정리 커밋(`--allow-unrelated-histories` 또는 rebase); **실코드가 있으면 멈추고 사용자에 보고**(force-push 금지).
- [ ] 첫 커밋에 **비밀값 0**: `git ls-files`에 `Sensitive.xcconfig`·`Sensitive.xcconfig.example`·`gitPAT.txt`·`fastlane/portal.json`·`fastlane/.env.default` 부재 확인.

### B. 민감정보 분리
- [ ] `.gitignore`가 `Sensitive.xcconfig*` 글롭으로 실값+예시 모두 무시.
- [ ] 소스 트리 하드코딩 키 스캔(`supabaseKey`/`apiKey`/`anonKey` 등 패턴) — 발견 시 xcconfig 경유 주입으로 이전, 경로 보고.
- [ ] Supabase URL/anon key 주입 경로가 xcconfig→Info.plist인지 확인(하드코딩 아님).
- [ ] README에 "로컬 `Sensitive.xcconfig` 생성·채우기" 안내 1줄(값·키 노출 없이).

### C. 하네스 커밋 정책 적용
- [ ] `.gitignore` 76~93줄 재작성: 표준(`CLAUDE.md`·`.claude/skills`·`.claude/commands`) **추적**, 런타임(`.omc/`·`agent_docs/`) **무시**.
- [ ] Codex 잔재 제거: `.codex/` 화이트리스트 규칙·`AGENTS.md` 항목 정리(Claude-only 반영).

### D. 하네스 갭 보강 (감사 기반, Claude로 가능한 것만)
- [ ] 참조 스킬 10개(`ios-architecture` 등)·커맨드 7개의 **실재 검증** + dangling 참조 목록화.
- [ ] 템플릿 잔재 교정: `ReaderContainer` → `MutterContainer` 등 (CLAUDE.md 본문 vs 스킬 트리거 표 불일치).
- [ ] 리뷰 게이트를 OMC `critic`/`code-reviewer`(Opus)에 연결 — `/arch-check`·커밋 전 자가검증 흐름에 명시.
- [ ] 모듈별 `CLAUDE.md`는 **필요시에만**(`Projects/` 모듈별 특화 규칙이 있을 때 분산, 없으면 생략 — 과잉 분할 금지).

### E. 검증
- [ ] `tuist generate` + 빌드 성공(하네스/gitignore 변경이 빌드 안 깸).
- [ ] 푸시 후 원격(GitHub)에서 비밀값 0 재확인.

## 노출·해소된 가정 (Assumptions)
| 가정 | 도전 | 해소 |
|---|---|---|
| "하네스를 새로 구축" | 실제로 6/20 셋업된 하네스 존재 | 감사+갭클로징으로 재정의 |
| 하네스는 로컬 전용(현 .gitignore) | 글은 커밋·공유가 철학 | 표준 커밋/런타임 무시로 절충 |
| Codex 세컨드오피니언 필요(글) | 우린 Claude-only | Codex 제거, critic으로 대체 |
| example 파일은 커밋(관행) | 키 스키마 비노출 원함 | example도 커밋 제외 |

## 기술 컨텍스트 (확인된 사실)
- 빌드: **Tuist 모듈러**(`Workspace.swift`, `Tuist/Package.swift`, `.mise.toml`, `Projects/`, `XCConfigs/`, `Entitlements/`, `InfoPlists/`, `Plugins/`, `Tools/`, `Gemfile`). Mercury 스캐폴드 1:1 복제. SwiftUI only, Clean+Micro-Feature, Combine+Concurrency, iOS 18, Bundle `com.efreedom.mutter`, DI `MutterContainer`.
- 백엔드: Supabase 재사용(supabase-swift, 테이블 7·RPC 17).
- 로컬 git: **아직 리포 아님** (`git init` 필요).
- 원격: `Mutter_iOS` main에 커밋 1개(`9912e86`) — 내용은 푸시 직전 검사.
- 기존 하네스: `CLAUDE.md`(89줄, ≤200 충족), `.claude/`, `.omc/`, `docs/`, `tasks/`.
- 기존 secrets 처리: `.gitignore`에 `Sensitive.xcconfig`·`gitPAT.txt`·fastlane 시크릿 이미 무시.

## 미검증(감사에서 확인)
- 참조된 10개 스킬 SKILL.md / 7개 커맨드 파일의 실재 여부.
- `Projects/` 모듈 구성 상세(모듈별 CLAUDE.md 필요성 판단용).

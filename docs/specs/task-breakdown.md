# Mutter iOS — Task 분할 (Task Breakdown)

> 마스터 로드맵 `app-dev-plan.md`를 **실행 단위 Task**로 쪼갠 목록.
> 각 Task = **DeepInterview → ralplan(계획) → 개발 → ralph(검증)** 1사이클.

## 실행 규칙 (사용자 지정 2026-06-27, 불변)
1. 모든 Task는 **DeepInterview → ralplan**으로 계획한다.
2. Task 완료 시 **ralph**로 검증 — **Clean Architecture·코드 컨벤션·오버엔지니어링** 적발.
3. **아키텍처 방향을 위반하는 개발 범위가 나오면 멈추고 사용자에게 질문**한다.
4. 그 외엔 멈추지 말고 끝까지 작업한다.
5. 공통 게이트(매 Task): `tuist build` 0 · `/arch-check` 0 · 관련 `tuist test` · One-Type-Per-File · 커밋 전 `code-reviewer`/`critic` 독립 패스(Codex 미사용).
6. 착수는 사용자가 "시작" 신호 후.

## 웹 패리티 보강(R5) — 설계에 추가될 계약 (T0.2에서 확정)
- **읽음확인**: 테이블 `letter_opens`(token, letter_id, first/last_opened_at, open_count) + RPC `record_letter_open(token)`(▶ 시 호출)·`get_my_letter_opens()`(발신자 롤업) → Domain `LetterOpenSummary`, Viewer가 record, Sent/Home이 표시.
- **예약공개**: `DeliveryLink.revealAt` + `issue(reveal_at)` + `get_letter_by_token` reveal 게이트(이전엔 본문/암호 없이 "이 시각에 열려요") → Delivery issue 파라미터, Viewer locked-until 상태.
- **답장**: 새 RPC 없음 — Thread/연결발송에서 "답장" 진입 → Compose에 상대 preselect.
- **이어쓰기**: 새 RPC 없음 — letter create/update + Compose가 letterId 로드, Sent "이어쓰기".
- **RPC 수 정정**: "17" → 실제 ~20 (`record_letter_open`·`get_my_letter_opens`·`disable_letter_audio` 포함).

## P0 — 프리플라이트 (코딩 전)
| Task | 산출물 | AC / 게이트 |
|---|---|---|
| **T0.1** git·secrets | `harness-gap-and-git-setup.md` 실행: git init + 원격 + 민감정보 분리 | 첫 커밋 비밀값 0, 원격 정합 |
| **T0.2** 패리티 reconcile | R5 계약을 `module-architecture.md`에 반영(읽음확인·예약공개 엔티티/RPC, 답장/이어쓰기 흐름) | 4기능이 엔티티·RPC·화면에 매핑됨 |
| **T0.3** OAuth/서명 사전조건 | Apple App ID(`com.efreedom.mutter`)·Google·Kakao·Supabase allowed id 갱신 | 콘솔 등록 확인(외부 작업) |

## Phase 1 — 공통 기반 (바텀업)
| Task | 모듈 | AC 핵심 | 의존 |
|---|---|---|---|
| **T1.1** | AppFoundation | DI register/resolve · `MutterError`+`toMutterError()` · `AppConfig`(키 주입) · Deeplink | — |
| **T1.2** | UIComponent | 토큰 = 웹 tokens.css · 컴포넌트 SampleApp 렌더 · `WKWebViewContainer` · `LetterPaperView`(7템플릿) | T1.1 |
| **T1.3** | Domain | 엔티티(+읽음확인·예약공개) · Usecasable/Repositorable 프로토콜 · 순수 Swift | T1.1, T0.2 |
| **T1.4** | Network | `SupabaseProvider`(auth/from/rpc) · Keychain 세션 | T1.1 |
| **T1.5** | Infrastructure | Repository 구현 RPC 1:1(~20) · DTO+Mapper · body↔paragraphs · Mapper 단위테스트 | T1.3, T1.4 |
| **T1.6** | Router | Coordinator·Route·Viewable·ViewFactory·Deeplink · Feature→Feature 0 | T1.1 |
| **T1.7** | AudioSync | TrackSource 3종 · LetterAudioPlayer · **무음0 폴백** | T1.2, T1.3 |

## Phase 2 — Feature (풀 패리티)
| Task | 피처 | AC 핵심 | 비고 |
|---|---|---|---|
| **T2.1** | Auth | 코드/비번 + Apple/Google/Kakao 로그인 | T0.3 필요 |
| **T2.2** | Compose(+Audio) | WYSIWYG · 템플릿 · 음악 1곡 · 저장 · **이어쓰기(letterId 로드)** | |
| **T2.3** | Viewer(+Audio) | ▶ 게이트 · LetterAudioPlayer · **읽음확인 record** · **예약공개 gate** | ⚠ **SC WKWebView 디바이스 스파이크 go/no-go (R1)** |
| **T2.4** | Delivery | 발급(암호 ON)·만료·revoke · **예약공개(reveal_at)** | |
| **T2.5** | Inbox | 받은편지 보관·다시보기 | |
| **T2.6** | Connections | 1:1 초대·수락·직접발송·해제 | |
| **T2.7** | Threads | 상대별 주고받음 + **답장 진입** | |
| **T2.8** | Profile | 닉네임·로그아웃·계정삭제(연쇄) | |
| **T2.9** | Home | 우체통·바로가기 · **읽음상태 표시** | |
| **T2.10** | Legal | 약관·takedown·`disable_letter_audio` | |
| **T2.11** | MainTab | 루트 탭(ViewFactory 배선) | 피처 마지막 |

## Phase 3 — App 통합
| Task | 산출물 | AC |
|---|---|---|
| **T3.1** | MutterApp 합성루트 | 전 Repo/UseCase/SupabaseProvider DI 등록 + ViewFactory 배선 |
| **T3.2** | AppDelegate | Firebase/APNs · `AVAudioSession` 백그라운드·잠금화면 · Universal Link 라우팅 |
| **T3.3** | 엔타이틀먼트 | Apple 로그인 · Push · Associated Domains |
| **T3.4** | e2e | 콜드 실행 → 딥링크 열람 → 음악 → 백그라운드 지속 |

## Phase 4 — 출시
| Task | 산출물 |
|---|---|
| **T4.1** 서명/구성 | 프로비저닝 · Stage/Release xcconfig |
| **T4.2** TestFlight | 내부 테스트 빌드 · 피드백 |
| **T4.3** App Store | 메타 · 스크린샷 · 심사 |

## 의존 순서 요약
P0(T0.1→T0.2→T0.3) → Phase 1(T1.1→…→T1.7) → Phase 2(T2.1→…→T2.11) → Phase 3 → Phase 4.
각 Task: 착수=DeepInterview→ralplan, 완료=ralph 검증, 아키텍처 위반 시 질문.

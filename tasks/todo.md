# tasks/todo.md

## 현재 작업 — 양 플랫폼 스토어 업데이트 업로드

사전 확인: iOS 라이브 1.0.2(iTunes lookup) → 1.0.3 필요 · Android Play 게시됨(HEAD vc=1, 워킹트리 vc=2 미커밋) → vc=3 안전.
iOS fastlane release 레인 + .env.default(ASC 키, gitignore) + homebrew fastlane. Android는 Play API 자격증명 없음 → AAB 빌드 후 콘솔 업로드.

- [ ] iOS: MarketingVersion 1.0.2→1.0.3, 스와이프 삭제+버전업 커밋
- [ ] iOS: `fastlane authcheck`로 ASC 키 확인 → `fastlane release`(빌드번호 자동 = TestFlight 최신+1)
- [ ] Android: 미커밋 WIP(FCM 푸시+R8+화면 정리) 커밋 → 스와이프 삭제 커밋 → vc3/1.1.0 버전업 커밋
- [ ] Android: `:app:bundleRelease` AAB 빌드(JDK17)
- [ ] Android: Play Console 업로드(브라우저 자동화 가능하면 시도, 아니면 AAB+절차 전달)
- [ ] 릴리스 노트(What's New) 초안 작성

## 이전 작업 — 받은편지함 스와이프 삭제 (iOS + Android)

백엔드 변경 불필요: `inbox` 테이블 RLS `inbox_self_rw`(for all)가 본인 행 DELETE 허용,
`letters` 직접 delete 전례(iOS/Android 모두)와 동일 패턴으로 `from("inbox").delete().eq("letter_id", …)`.

### iOS (Mutter)
- [x] Domain: `InboxRepositorable`·`InboxUsecasable`에 `remove(letterId:)` 추가, `InboxUsecase` 구현
- [x] Infrastructure: `InboxRepository.remove` — `from("inbox").delete().eq("letter_id")`
- [x] Feature/Inbox: `InboxModelData.delete(_:)` — 낙관적 제거 + 실패 시 롤백
- [x] `InboxView`: 목록 분기를 `List` + `.swipeActions`(trailing, full swipe)로 전환 — 카드 스타일 유지
- [x] 빌드 검증 (`mise exec -- tuist build Mutter` → ✔ Success, exit 0)

### Android (Mutter_android)
- [x] domain: `InboxRepository.remove` + `InboxUseCase.remove`
- [x] data: `InboxRepositoryImpl.remove` — `postgrest.from("inbox").delete { eq("letter_id") }`
- [x] feature/inbox: `InboxViewModel.delete` (낙관적 제거+롤백) + `SwipeToDismissBox`(EndToStart, Danger 배경+trash 아이콘)
- [x] 빌드 검증 (JDK17 gradlew assembleDebug → BUILD SUCCESSFUL, exit 0)

### 문서
- [x] `docs/specs/module-architecture.md` 테이블 직접 접근 목록에 `inbox`(delete) 반영

### 리뷰 (받은편지함 스와이프 삭제)
- 변경: iOS 6파일(Domain 3·Infra 1·Feature 2) + Android 5파일(domain 2·data 1·feature 2) + 설계문서 1줄.
- 백엔드 무변경 — `inbox` RLS `inbox_self_rw`(for all)로 본인 행 delete, `letters` 직접 delete 전례와 동일 패턴.
- UI: iOS `List`+`.swipeActions`(trailing, full swipe, 삭제 라벨) / Android `SwipeToDismissBox`(EndToStart, Danger 배경+trash, `animateItem`).
- 독립 리뷰(code-reviewer) 결과 Major 1건 — 전체 스냅샷 롤백이 연속 삭제 레이스에서 다른 항목까지 부활시킴 → 항목 단위 롤백(제거 항목+인덱스만 캡처)으로 양쪽 수정.
- 검증: iOS `mise exec -- tuist build Mutter` ✔ Success·exit 0, Android `gradlew assembleDebug` BUILD SUCCESSFUL·exit 0 (레이스 수정 후 재빌드 포함).

## 이전 작업 — 무계정 수신자: 가입하면 받은 편지/연결이 이어지게 (pending 경로 복귀)

핵심 근본: 웹 로그인이 코드/가입 시 `/set-nickname`→홈으로 가 원래 경로(`state.from`)를 버림.
이걸 고치면 연결하기·편지저장 둘 다 "링크 열다 가입 → 그 링크로 복귀"가 완성된다.

### 웹 (letter-app)
- [ ] `Login.tsx handleVerifyCode`: `/set-nickname`으로 갈 때 `state.from` 전달
- [ ] `SetNickname.tsx`: 저장 후 `from`(있으면)으로 복귀, 없으면 `/welcome`
- [ ] `SaveToInboxButton.tsx`: 비로그인 수신자에게 "가입하고 받은 편지함에 저장" CTA → `/login`(from=현재 편지 링크). 로그인 복귀 시 서버가 열람 자동저장(0022)
- [ ] typecheck + 전체 테스트

### 앱 (Mutter) — pending 편지 토큰 소비 (phase 2)
- [ ] 미인증 뷰어에 "가입하고 보관" CTA (Viewer 피처에 옵션 콜백)
- [ ] `MainView`: 로그인 완료 시 pending 편지 토큰을 인증 뷰어로 열어 자동저장(pendingConnectToken 패턴)
- [ ] `tuist build`

## 리뷰(직전 작업: 연결 N:N 전환)
- DB 0027 + 앱/웹 N:N 전환 완료. 앱 `tuist build` OK, 웹 242/242. 배포는 `supabase db push`(0027) 필요.
- 보안: GoogleService-Info.plist 히스토리에서 filter-branch로 제거(로컬 완료), force-push는 사용자 실행 대기.

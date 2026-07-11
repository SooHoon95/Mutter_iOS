# tasks/todo.md

## 현재 작업 — 무계정 수신자: 가입하면 받은 편지/연결이 이어지게 (pending 경로 복귀)

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

# tasks/todo.md

## 현재 작업 — 연결 기능 독점 1:1 → N:N(다대다) 전환

### DB (letter-app · 신규 마이그레이션 0027)
- [x] `accept_connect_invite`: 배타성 가드(`ALREADY_CONNECTED_SELF/OTHER`) 제거 → 같은 상대 중복만 `ALREADY_CONNECTED`
- [x] `disconnect_connection()` → `disconnect_connection(p_other_user uuid)` + 구 무인자 함수 DROP

### 앱 (Mutter)
- [x] `ConnectionRepositorable`/`Usecasable`/`Usecase`/`Repository`: `disconnect(otherUserId:)`
- [x] `ConnectionDTO`: `DisconnectParams(p_other_user)` 추가
- [x] `ConnectionsModelData`: `connections: [Connection]` + `disconnect(otherUserId:)`
- [x] `ConnectionsView`: 연결 리스트 카드(행별 해제) + 초대 링크 항상 노출
- [x] `tuist build Mutter` → Build Succeeded

### 웹 (letter-app)
- [x] `connections.ts`: `disconnect(otherUser)` + 에러맵 `ALREADY_CONNECTED`(SELF/OTHER 제거)
- [x] `useConnections.ts`: disconnect 파라미터화(`<void,Error,string>`)
- [x] `ConnectionList.tsx`: 단일→리스트(행별 해제, `disconnect(userId)`)
- [x] `InvitePanel.tsx`: 초대 생성 전용(연결/해제 로직 제거 — N:N이라 초대 항상 가능)
- [x] `Connect.tsx`: 1:1 차단 블록(viewer/inviterHasConnection) 제거
- [x] `connections.test.ts`: ALREADY_CONNECTED_SELF/OTHER→ALREADY_CONNECTED, disconnect 대상 인자
- [x] typecheck 0 · connections 25/25 · 전체 242/242 · lint 0

## 리뷰

**변경 요약**: 독점 1:1 배타성을 강제하던 3지점만 해제 → N:N. 스키마(connections 페어 테이블)·send_to_connection(수신자 지정)·get_my_connections(리스트)·앱 SendSheet·웹 ConnectionPicker는 이미 N:N이라 불변.
- **DB**: `0027_connections_n_to_n.sql` — accept 배타성 제거(중복 페어만 방지), disconnect에 대상 파라미터.
- **앱**: disconnect 시그니처 체인 + ConnectionsView를 단일카드→리스트, 초대 항상 노출.
- **웹**: disconnect 대상화, ConnectionList 리스트화, InvitePanel 초대전용, Connect.tsx 1:1 안내 제거.

**검증 증거**:
- 앱: `tuist build Mutter` → **Build Succeeded**.
- 웹: `tsc --noEmit` exit 0 · `vitest run` **242/242 통과**(connections 25/25) · eslint exit 0.

**미배포(사용자 액션)**: `supabase db push`(0027) 필요. 마이그레이션 미적용 상태에선 disconnect가 `p_other_user` 시그니처 불일치로 실패하므로 **배포 후 테스트**.

**남은 것(별개 이슈)**: 웹 로그인 리다이렉트 버그(이메일코드/가입 로그인이 `/connect/:token` 대신 `/set-nickname`으로 가 초대 유실) — 아직 미수정. 우회: B 먼저 로그인 후 링크 열기.

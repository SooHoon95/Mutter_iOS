# PLAN — Provider별 계정=데이터 분리 (전면)

> 목표: 로그인 방식(email·google·kakao)별로 **별도 계정 = 편지/연결 데이터 분리**. 같은 provider는 웹↔앱 통합.
> ⚠ 프로덕션 인증 다단계 재설계. 앱+웹 양쪽. 배포·계정삭제는 사용자 실행.

## 모델 (핵심)
- **email(매직코드)** = 네이티브, **실제 이메일** 계정 하나. (이메일 provider의 정본)
- **google / kakao** = **커스텀 edge + synthetic 이메일**(`<provider>_<sub>@<provider>.mutter.local`) 계정. `<provider>_identity_map(sub→user_id)`로 웹↔앱 통합. 실제 이메일은 metadata/profiles에 표시용 보관.
- → 같은 실제 이메일이라도 email / google / kakao = **3개 별도 계정**(각자 편지·연결 분리). Supabase 자동링크·유니크이메일 벽 회피.

## Phase 1 — 카카오 사일로화 (기존 edge 재사용, 리스크 최소)
- `kakao-login/index.ts`: `find_user_id_by_email` 호출 제거 → `kakao_identity_map`(sub)로만 정합.
- `createKakaoUser`: synthetic 이메일로 생성(`email_confirm:true`, metadata.real_email). `issueSession`도 synthetic 이메일 magiclink.
- 마이그레이션 0026(find_user_id_by_email): edge 호출 중단.

## Phase 2 — 구글을 커스텀 edge로 이전 (네이티브 자동링크 탈출)
- 신규 edge `google-login`: Google idToken 서버검증(JWKS, aud=iOS/웹 client id, iss google) → `google_identity_map(sub→user_id)` → 없으면 synthetic 이메일 createUser → magiclink 세션.
- **앱**: `GoogleSignInProvider`가 idToken을 네이티브 `signInWithIdToken(.google)` 대신 **`google-login` edge로** 전송(현 카카오 경로 미러 — `AuthRepository.signInSocial`의 google 케이스 교체).
- **웹**: 현 `signInWithOAuth({provider:'google'})`(리다이렉트·네이티브·자동링크) → **Google Identity Services로 idToken 취득 후 `google-login` edge 호출**로 교체.
- 신규 마이그레이션: `google_identity_map` 테이블(0023 kakao_identity_map 미러).

## Phase 3 — synthetic 이메일 파급
- auth 이메일이 synthetic이 되는 google/kakao 계정: 이메일 표시/사용 지점을 **profiles/metadata의 real_email**로 배선. (편지·연결은 user_id 기반이라 영향 적음 — 전수 확인.)

## Phase 4 — 기존 병합 계정 정리
- 현 병합 계정(dkehskeh)은 라이브 분할 위험 → **삭제 후 재로그인**으로 새 모델 재생성(사용자 실행).

## 리스크 (명시)
- 손수 구현하는 Google idToken 검증 = 보안 표면↑(JWKS·aud·iss·exp 엄격 검증 필수).
- 앱+웹 양쪽 구글 로그인 경로 교체 = 회귀 위험.
- 한 사람이 여러 계정(편지함·연결 분리) — 의도된 결과지만 UX 유의.
- 네이티브 Supabase 구글 편의 상실.

## 검증
- edge 로컬 검증, 웹 typecheck/test, 앱 tuist build.
- 실기기: google/kakao 각각 별도 계정 생성, 웹↔앱 동일 provider 통합, email 계정 별도 확인.

## 배포 (사용자 실행)
- `supabase functions deploy google-login kakao-login`, `supabase db push`(google_identity_map), 웹 재배포, 기존 테스트계정 삭제.

## 진행 방식
Phase 1(카카오)부터 구현·검증 → Phase 2(구글 edge, 앱+웹) → Phase 3 → Phase 4. 각 Phase 커밋 전 독립 리뷰.

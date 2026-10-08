---
name: mutter-networking
description: Mutter iOS에서 Supabase를 호출하는 코드를 다룰 때 참조한다. 트리거 — (1) SupabaseProvider의 auth/from/rpc/functions 호출 추가·수정, (2) Repository 구현체 작성, (3) DTO·toDomain() 매퍼 작성, (4) 서버 RPC 에러 코드를 MutterError로 정규화(SupabaseErrorMapper), (5) 세션·401 처리, AppConfig(Supabase URL/anonKey) 주입, (6) 사용자가 "RPC 붙여줘/Supabase 연동/테이블 조회" 라고 말하는 경우.
---

# Mutter Networking (Supabase)

자체 REST 서버는 없다. 모든 데이터는 **Supabase**(supabase-swift)로 접근하고, 백엔드(테이블 7·RPC 17)는 배포 중인 웹앱 `~/Desktop/Code/letter-app`과 공유한다. **서버 계약(RPC 이름·파라미터·에러 코드)은 웹 data 레이어와 동일**해야 한다 — 바꾸기 전에 웹 코드와 Android(`Mutter_android`)를 같이 본다.

## SupabaseProvider (`Projects/Network`, 모듈명 `Networking`)

- 단일 인스턴스 `SupabaseProvider.shared`. 구성된 `client: SupabaseClient`를 얇게 노출하고, Repository가 `provider.client.auth` / `.from("table")` / `.rpc("fn", params:)` / `.functions`를 직접 쓴다(PostgREST 빌더를 감싸지 않는다).
- URL·anonKey는 `AppConfig`(xcconfig → Info.plist)에서 읽는다. 하드코딩하지 않는다. 실값은 gitignore된 `Sensitive.xcconfig`.
- 세션은 SDK 기본 옵션으로 Keychain 저장 + 자동 갱신. 별도 Keychain 코드를 쓰지 않는다.

## 호출은 Repository 구현체에서만

```swift
// Projects/Infrastructure/Sources/FeatureRepository/Inbox/InboxRepository.swift
public final class InboxRepository: InboxRepositorable {
  private let provider: SupabaseProvider
  public init(provider: SupabaseProvider = .shared) { self.provider = provider }

  public func myInbox() async throws -> [InboxItem] {
    do {
      let rows: [InboxRow] = try await provider.client.rpc("get_my_inbox").execute().value
      return rows.map { $0.toDomain() }
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}
```

- 보안 정의 RPC는 `rpc(fn, params:)`로 1:1 호출. 파라미터는 `Encodable` 구조체(`TokenParam(token:)` 등). 17개 전체 매핑은 `docs/specs/module-architecture.md` §5.
- 테이블 직접 접근(`from`)은 RLS가 보호하는 `profiles`·`letters`·`inbox`·`delivery_links`로 한정.
- 서버 측 처리(계정·사진)는 Edge Function(`client.functions`) — `AuthRepository`·`LetterPhotoRepository`.
- DTO는 `Infrastructure/Sources/FeatureRepository/<도메인>/Model/`(`XRow`/`XDTO`), 매퍼는 DTO 파일 하단 `toDomain()`.

## 에러 정규화 — `SupabaseErrorMapper.map(_:)`

`Projects/Infrastructure/Sources/Support/SupabaseErrorMapper.swift`가 단일 지점이다. 모든 인증 데이터 호출은 catch에서 이걸 거쳐 `MutterError`를 던진다.

| 서버 메시지 / 조건 | MutterError |
|---|---|
| JWT 만료·무효(401) | `.unauthorized` + `SessionInvalidation.notifyUnauthorized()`(전역 신호 → 온보딩 복귀) |
| `NOT_YET_REVEALED:<ISO8601>` | `.linkNotYetRevealed(Date)` |
| `WRONG_PASSWORD` / `LINK_REVOKED` / `LINK_EXPIRED` | `.wrongPassword` / `.linkRevoked` / `.linkExpired` |
| `NOT_CONNECTED` / `INVITE_ALREADY_USED` | `.notConnected` / `.inviteAlreadyUsed` |
| `*_NOT_FOUND` | `.notFound` |
| `FORBIDDEN` / `not_authorized` | `.unauthorized`(비즈니스 403 — 세션 무효 신호는 안 쏨) |
| `URLError` | `.network` |
| 그 외 | `error.toMutterError() ?? MutterError(.unknown)` |

새 서버 에러 코드를 추가하면 `MutterErrorDefine` 케이스 + `MutterError.userMessage` 문구 + 이 매퍼를 같이 갱신하고, Android `SupabaseErrorMapper.kt`도 맞춘다. UI 표시 방식은 `mutter-swiftui`.

## 자가 점검

- Supabase 호출이 Repository 구현체에만 있다(UseCase/View 직접 호출 없음).
- catch에서 `SupabaseErrorMapper.map`을 거친다(raw 에러 전파 없음).
- URL/anonKey를 `AppConfig`로 읽는다.
- DTO가 Feature/Domain에 노출되지 않는다.
- RPC 계약 변경이면 웹·Android 영향까지 확인했다.

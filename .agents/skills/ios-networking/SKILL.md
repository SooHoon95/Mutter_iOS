---
name: ios-networking
description: Use when calling Supabase (auth/from/rpc/functions), implementing a Repository, mapping DTO↔Domain, or handling Supabase/network errors. Trigger on tasks like "Supabase 호출", "RPC", "from(table)", "Repository 구현", "DTO 매핑", "세션".
user-invocable: false
---

# Networking (Supabase)

Mutter는 자체 REST 서버가 없다. 모든 데이터는 **Supabase**(supabase-swift)로 접근한다.
진입점은 `Network` 모듈의 **`SupabaseProvider`**(단일 인스턴스, DI 주입).

## SupabaseProvider

```swift
public final class SupabaseProvider {
  private let client: SupabaseClient            // url, anonKey — AppConfig(xcconfig→Info.plist)에서 주입
  public var auth: AuthClient { client.auth }
  public func from(_ table: String) -> PostgrestQueryBuilder { client.from(table) }
  public func rpc(_ fn: String, params: [String: any Encodable]) -> PostgrestFilterBuilder { client.rpc(fn, params: params) }
  public var functions: FunctionsClient { client.functions }
}
```

- `url`/`anonKey`는 하드코딩 금지 — `AppConfig`(xcconfig→Info.plist)에서 읽는다.
- 세션은 Keychain 보관. 로깅은 Pulse 연동.

## 호출은 Repository 구현체에서만

Supabase 호출은 **Infrastructure의 Repository 구현체**에서만 한다. UseCase·View는 Domain 프로토콜만 본다.

```swift
// Infrastructure/.../FeatureRepository/Letter/LetterRepository.swift
final class LetterRepository: LetterRepositorable {
  @LazyInject private var supabase: SupabaseProvider

  func myLetters() async throws -> [Letter] {
    let dtos: [LetterDTO] = try await supabase.from("letters").select().execute().value
    return dtos.map { $0.toDomain() }                       // DTO→Domain (Mapper)
  }

  func open(token: String, password: String?) async throws -> LetterPayload {
    let dto: LetterPayloadDTO = try await supabase
      .rpc("get_letter_by_token", params: ["p_token": token, "p_password": password])
      .execute().value
    return dto.toDomain()
  }
}
```

- 보안 정의 RPC는 `rpc(fn, params)`로 1:1 호출(`issue_link`·`save_to_inbox`·`send_to_connection` 등). **RPC 17개 전체 매핑은 `docs/specs/module-architecture.md` §5 참조.**
- 테이블 직접 접근(`from`)은 RLS가 보호하는 `profiles`(upsert)·`letters`(CRUD)로 한정.
- DTO는 `Infrastructure/.../Model/`, Mapper는 DTO 파일 하단 `toDomain()` extension.

## 에러 처리

- Supabase/네트워크 에러는 catch에서 `error.toMutterError() ?? MutterError(.unknown)`로 변환해 throw.
  (에러 패턴 상세는 `ios-error-handling` 스킬 참조)
- `MutterError` 케이스: `network`·`unauthorized`·`notFound`·`rateLimited`·`wrongPassword`·`linkRevoked`·`linkExpired`·`server(String)`·`unknown`.

## 자가 점검

- Supabase 호출이 Repository 구현체로 한정됐는가(UseCase/View 직접 호출 금지).
- `url`/`anonKey`를 `AppConfig` 경유로 읽는가(하드코딩 금지).
- DTO가 Feature/Domain에 노출되지 않는가 — `toDomain()` 매퍼 경유.
- raw error를 `toMutterError()`로 변환했는가.

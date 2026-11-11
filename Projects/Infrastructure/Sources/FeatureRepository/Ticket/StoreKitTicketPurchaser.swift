import Foundation
import StoreKit

import Supabase

import AppFoundation
import Domain
import Networking

/// StoreKit 2 편지권 구매 — 구매 → `verify-purchase`로 JWS 전송 → **200을 받은 뒤에만** `finish()`.
/// 그 외 응답이면 거래를 남겨 두고(`Transaction.unfinished`) 다음 실행·로그인·편지권 화면 진입 때 다시 보낸다.
///
/// 거래 갱신(`Transaction.updates`)은 앱 수명 내내 들어야 해서(승인 대기 후 승인, 다른 기기 구매 등)
/// 앱이 공유하는 인스턴스 하나(`shared`)가 리스너를 쥔다.
///
/// 테스트 모드: Xcode StoreKit 테스트 거래는 Apple 서명이 아니라 검증이 `.unverified`로 나올 수 있다.
/// 판정은 서버 몫이므로 여기서는 검증 결과와 무관하게 JWS를 보낸다(실판매 전환 때 서버가 서명 체인을 검증).
public actor StoreKitTicketPurchaser: TicketPurchasing {
  public static let shared = StoreKitTicketPurchaser()

  private let provider: SupabaseProvider
  private let verifyFunction = "verify-purchase"
  private var products: [TicketProductType: Product] = [:]
  private var updatesTask: Task<Void, Never>?

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  /// 앱 시작 때 한 번 — 거래 갱신을 앱 수명 동안 듣는다(중복 호출은 무시).
  public func startObservingTransactions() {
    guard updatesTask == nil else { return }
    updatesTask = Task { [weak self] in
      for await update in Transaction.updates {
        // 실패하면 거래가 남아 다음 재전송 때 다시 시도된다.
        _ = try? await self?.deliver(update)
      }
    }
  }

  public func displayPrices() async throws -> [TicketProductType: String] {
    try await loadProducts().mapValues(\.displayPrice)
  }

  public func purchase(_ productType: TicketProductType) async throws -> TicketPurchaseResult {
    guard let product = try await loadProducts()[productType] else {
      throw MutterError(.purchaseUnavailable)
    }
    let result: Product.PurchaseResult
    do {
      result = try await product.purchase()
    } catch {
      throw MutterError(.unknown)
    }
    switch result {
    case .success(let verification):
      return .completed(tickets: try await deliver(verification))
    case .userCancelled:
      return .cancelled
    case .pending:
      return .pending
    @unknown default:
      return .cancelled
    }
  }

  public func resendUnfinished() async {
    for await verification in Transaction.unfinished {
      _ = try? await deliver(verification)
    }
  }

  // MARK: - Private

  private func loadProducts() async throws -> [TicketProductType: Product] {
    if !products.isEmpty { return products }
    let ids = [TicketProductType.one, .five].map(\.productId)
    let loaded: [Product]
    do {
      loaded = try await Product.products(for: ids)
    } catch {
      throw MutterError(.purchaseUnavailable)
    }
    products = Dictionary(
      loaded.compactMap { product in TicketProductType(rawValue: product.id).map { ($0, product) } },
      uniquingKeysWith: { first, _ in first }
    )
    return products
  }

  /// 서버에 JWS를 보내 지급받고, 200이면 거래를 마무리한다. 지급 후 잔액을 돌려준다.
  private func deliver(_ verification: VerificationResult<Transaction>) async throws -> Int {
    let transaction: Transaction
    switch verification {
    case .verified(let verified): transaction = verified
    case .unverified(let unverified, _): transaction = unverified
    }
    let response = try await verify(jws: verification.jwsRepresentation)
    // granted=false(이미 지급)도 200이므로 성공 — 마무리한다.
    await transaction.finish()
    return response.tickets
  }

  private func verify(jws: String) async throws -> VerifyPurchaseResponse {
    do {
      return try await provider.client.functions.invoke(
        verifyFunction,
        options: FunctionInvokeOptions(body: VerifyPurchaseRequest(platform: "ios", jws: jws))
      )
    } catch FunctionsError.httpError(let code, let data) {
      let errorCode = try? JSONDecoder().decode(VerifyPurchaseErrorBody.self, from: data).error
      // 테스트 모드: 테스터가 아닌 계정은 지급되지 않는다.
      if code == 403, errorCode == "not_tester" { throw MutterError(.purchaseUnavailable) }
      throw MutterError(.unknown)
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}

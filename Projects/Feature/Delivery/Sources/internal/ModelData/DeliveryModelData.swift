import Foundation

import AppFoundation
import Domain
import UIComponent

/// 전달 링크 발급/관리(= 보낸 편지 상세) — 암호 기본 ON, 예약공개, revoke,
/// 그리고 영구 편지권: 접근 상태·영구로 만들기·열람자·사본 보내기.
@MainActor
@Observable
final class DeliveryModelData {
  var links: [DeliveryLink] = []
  /// 암호 기본 ON(기본값이 프라이버시).
  var usePassword = true
  var password = ""
  var useReveal = false
  var revealAt = Date().addingTimeInterval(3600)
  var isLoading = false
  var errorMessage: String?
  var lastIssuedLink: DeliveryLink?

  /// 이 편지의 접근 상태. nil이면(조회 실패·배포 전) 편지권 관련 UI를 그리지 않는다.
  private(set) var accessState: LetterAccessState?
  /// 권한·잔액. nil이면 편지권 UI·사본 보내기를 숨긴다(새 서버 계약이 없는 상태).
  private(set) var entitlements: Entitlements?
  /// 열람자(처음 연 순). 조회 실패면 비어 있어 섹션을 숨긴다.
  private(set) var readers: [LetterReader] = []
  /// 간직 요청자(요청한 순). 요청이 없거나 조회 실패면 비어 있어 섹션을 숨긴다.
  private(set) var keepRequests: [LetterKeepRequest] = []
  var isMakingPermanent = false
  var isDuplicating = false
  /// 이 화면에서 "{n}일 편지로 보내기"를 골랐는지 — 화면에 머무는 동안만 기억한다.
  var choseFreeDays = false
  /// 첫 조회가 끝났는지. 끝나기 전엔 발급 폼을 그리지 않는다(선택 카드로 바뀌며 깜빡이지 않게).
  private(set) var hasLoaded = false

  private let letterId: String
  private let deliveryUsecase: DeliveryUsecasable
  private let letterAccessUsecase: LetterAccessUsecasable
  private let ticketUsecase: TicketUsecasable

  init(
    letterId: String,
    deliveryUsecase: DeliveryUsecasable,
    letterAccessUsecase: LetterAccessUsecasable,
    ticketUsecase: TicketUsecasable
  ) {
    self.letterId = letterId
    self.deliveryUsecase = deliveryUsecase
    self.letterAccessUsecase = letterAccessUsecase
    self.ticketUsecase = ticketUsecase
  }

  /// 영구 편지 표시 — 편지권 UI가 켜진 계정에서만(관리자 편지는 늘 영구).
  var showsPermanentBadge: Bool {
    accessState?.type == .permanent && (entitlements?.showsTicketUI ?? false)
  }

  /// "영구 편지로 만들기" — 편지권 UI가 켜져 있고 아직 되살릴 수 있는(열림·잠김) 편지만.
  var canMakePermanent: Bool {
    guard entitlements?.showsTicketUI == true, let type = accessState?.type else { return false }
    return type == .open || type == .locked
  }

  /// 보내기 전 선택 카드 — 아직 영구가 아닌 open 편지 + 유료 스위치 + 링크 없음 + 14일을 고르지 않음.
  /// 계약 "보내기 전 선택(보낸 사람)". 카드가 떠 있는 동안 발급 폼과 "영구 편지로 만들기" 버튼을 숨긴다.
  var showsSendChoice: Bool {
    accessState?.type == .open
      && entitlements?.paidEnabled == true
      && links.isEmpty
      && lastIssuedLink == nil
      && !choseFreeDays
  }

  /// 영구 선택 시 편지권이 있는지(관리자는 차감 없음). 없으면 편지권 화면으로 보낸다.
  var hasTicketForPermanent: Bool {
    guard let entitlements else { return false }
    return entitlements.tickets > 0 || entitlements.isAdmin
  }

  /// 무료 기간이 적용되는 편지면 링크 발급 안내의 일수(서버 설정값). 영구면 nil.
  var freeDaysNotice: Int? {
    guard accessState?.type == .open else { return nil }
    return entitlements?.freeDays
  }

  /// 사본 보내기는 새 서버 계약(duplicate-letter)이 있을 때만 — 권한 조회 성공으로 판단한다.
  var canDuplicate: Bool { entitlements != nil }

  var canIssue: Bool {
    usePassword ? !password.isEmpty : true
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    // 상태·권한·열람자는 표시용 부가 정보 — 실패하면 조용히 비워 두고 지금 화면 그대로 보인다.
    async let linksTask = deliveryUsecase.links(letterId: letterId)
    async let statesTask = letterAccessUsecase.accessStates(letterIds: [letterId])
    async let entitlementsTask = ticketUsecase.entitlements()
    async let readersTask = letterAccessUsecase.readers(letterId: letterId)
    links = (try? await linksTask) ?? []
    accessState = (try? await statesTask)?[letterId]
    entitlements = try? await entitlementsTask
    readers = (try? await readersTask) ?? []
    hasLoaded = true
    // 간직 요청은 건수가 있을 때만 받는다 — 영구가 되면 건수가 0이 되어 사라진다.
    if let count = accessState?.keepRequestCount, count > 0 {
      keepRequests = (try? await letterAccessUsecase.keepRequests(letterId: letterId)) ?? []
    } else {
      keepRequests = []
    }
  }

  /// 편지권 1장으로 영구 편지로. 잔액이 없으면 구매 UI가 있는 계정은 편지권 화면으로 보낸다.
  func makePermanent(onNoTicket: () -> Void) async {
    guard !isMakingPermanent else { return }
    isMakingPermanent = true
    errorMessage = nil
    defer { isMakingPermanent = false }
    do {
      try await ticketUsecase.makePermanent(letterId: letterId)
      await load()
    } catch let error as MutterError where error.define == .noTicket {
      if entitlements?.showsPurchaseUI == true {
        onNoTicket()
      } else {
        errorMessage = error.userMessage
      }
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }

  /// 같은 내용으로 새 편지를 만들고, 새 편지 id로 발송 흐름을 잇는다.
  func duplicate(onDuplicated: (String) -> Void) async {
    guard !isDuplicating else { return }
    isDuplicating = true
    errorMessage = nil
    defer { isDuplicating = false }
    do {
      let newLetterId = try await letterAccessUsecase.duplicate(letterId: letterId)
      onDuplicated(newLetterId)
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }

  func issue() async {
    await run {
      let link = try await deliveryUsecase.issue(
        letterId: letterId,
        password: usePassword ? password : nil,
        revealAt: useReveal ? revealAt : nil
      )
      lastIssuedLink = link
      password = ""
      await load()
    }
  }

  func revoke(_ token: String) async {
    await run {
      try await deliveryUsecase.revoke(token: token)
      await load()
    }
  }

  private func run(_ operation: () async throws -> Void) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      try await operation()
    } catch {
      errorMessage = (error as? MutterError)?.userMessage ?? L10n.commonRetryLater
    }
  }
}

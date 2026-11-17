import Foundation

/// GA4 `screen_view`의 화면 이름. 3플랫폼 계약(docs/specs/2026-11-16-analytics.md)과 같다.
public enum AnalyticsScreen: String {
  case signIn = "sign_in"
  case onboardNickname = "onboard_nickname"
  case home
  case inbox
  case threads
  case connections
  case profile
  case compose
  case viewer
  case delivery
  case connectInvite = "connect_invite"
  case trash
  case inboxTrash = "inbox_trash"
  case tickets
  case ticketCheckout = "ticket_checkout"
  case legalTerms = "legal_terms"
  case legalPrivacy = "legal_privacy"
  case legalTakedown = "legal_takedown"
}

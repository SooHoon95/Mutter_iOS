import Foundation

import Supabase

import AppFoundation
import Domain
import Networking

/// report_takedown RPC 파라미터(p_letter_id/p_track_ref는 null 명시).
private struct TakedownParams: Encodable {
  let letterId: String?
  let trackRef: String?
  let claimant: String
  let contact: String
  let reason: String

  enum CodingKeys: String, CodingKey {
    case letterId = "p_letter_id"
    case trackRef = "p_track_ref"
    case claimant = "p_claimant"
    case contact = "p_contact"
    case reason = "p_reason"
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(letterId, forKey: .letterId)
    try c.encode(trackRef, forKey: .trackRef)
    try c.encode(claimant, forKey: .claimant)
    try c.encode(contact, forKey: .contact)
    try c.encode(reason, forKey: .reason)
  }
}

/// `TakedownRepositorable` 구현 — 신고 접수(익명 허용).
public final class TakedownRepository: TakedownRepositorable {
  private let provider: SupabaseProvider

  public init(provider: SupabaseProvider = .shared) {
    self.provider = provider
  }

  public func report(
    letterId: String?,
    trackRef: String?,
    claimant: String,
    contact: String,
    reason: String
  ) async throws {
    do {
      let params = TakedownParams(
        letterId: letterId,
        trackRef: trackRef,
        claimant: claimant,
        contact: contact,
        reason: reason
      )
      try await provider.client
        .rpc("report_takedown", params: params)
        .execute()
    } catch {
      throw SupabaseErrorMapper.map(error)
    }
  }
}

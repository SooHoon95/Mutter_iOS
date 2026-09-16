import XCTest

@testable import UIComponent

final class LetterShareMessageTests: XCTestCase {
  private let url = "https://example.com/l/abc123"
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  func test_plain_bodyThenBlankLineThenURL() {
    let text = LetterShareMessage.text(url: url, hasPassword: false, revealAt: nil, now: now)
    XCTAssertTrue(text.hasPrefix(L10n.shareLetterBody))
    XCTAssertTrue(text.hasSuffix("\n\n\(url)"))
    XCTAssertFalse(text.contains(L10n.shareLetterPassword))
  }

  func test_password_addsPasswordLineBeforeURL() {
    let text = LetterShareMessage.text(url: url, hasPassword: true, revealAt: nil, now: now)
    XCTAssertTrue(text.contains("\n\(L10n.shareLetterPassword)\n\n\(url)"))
  }

  func test_futureReveal_addsRevealLine() {
    let revealAt = now.addingTimeInterval(3600)
    let expected = L10n.shareLetterRevealAt(revealAt.formatted(date: .abbreviated, time: .shortened))
    let text = LetterShareMessage.text(url: url, hasPassword: false, revealAt: revealAt, now: now)
    XCTAssertTrue(text.contains("\n\(expected)\n\n\(url)"))
  }

  func test_pastReveal_isIgnored() {
    let plain = LetterShareMessage.text(url: url, hasPassword: false, revealAt: nil, now: now)
    let past = LetterShareMessage.text(url: url, hasPassword: false, revealAt: now.addingTimeInterval(-60), now: now)
    XCTAssertEqual(past, plain)
  }

  func test_passwordAndReveal_keepOrder() {
    let revealAt = now.addingTimeInterval(86_400)
    let reveal = L10n.shareLetterRevealAt(revealAt.formatted(date: .abbreviated, time: .shortened))
    let text = LetterShareMessage.text(url: url, hasPassword: true, revealAt: revealAt, now: now)
    XCTAssertEqual(text, [L10n.shareLetterBody, L10n.shareLetterPassword, reveal, "", url].joined(separator: "\n"))
  }
}

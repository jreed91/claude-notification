import XCTest
@testable import AgentBar

/// Tests for `HookServer`'s HTTP parsing and bearer-token check. Both run on
/// attacker-reachable input — any local process can hit the loopback port, and `parse`
/// runs *before* authentication — so their edge cases are pinned here. The server is
/// never started; `parse`/`authorized` are pure functions over the instance's token.
final class HookServerTests: XCTestCase {

    private func request(_ raw: String) -> Data { Data(raw.utf8) }

    // MARK: - parse: well-formed requests

    func testParsesCompleteRequest() {
        let server = HookServer()
        let raw = "POST /v1/stop HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}"
        guard case .complete(let req) = server.parse(request(raw)) else {
            return XCTFail("expected a complete request")
        }
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.path, "/v1/stop")
        XCTAssertEqual(req.headers["content-type"], "application/json")
        XCTAssertEqual(req.body, Data("{}".utf8))
    }

    func testHeaderKeysAreCaseInsensitive() {
        let server = HookServer()
        let raw = "GET /v1/health HTTP/1.1\r\nAUTHORIZATION: Bearer x\r\n\r\n"
        guard case .complete(let req) = server.parse(request(raw)) else {
            return XCTFail("expected a complete request")
        }
        XCTAssertEqual(req.headers["authorization"], "Bearer x")
    }

    // MARK: - parse: framing

    func testPartialHeadersAreIncomplete() {
        let server = HookServer()
        if case .incomplete = server.parse(request("POST /v1/stop HTTP/1.1\r\nContent-")) {
            // expected: wait for more bytes
        } else {
            XCTFail("headers without the blank-line terminator must be incomplete")
        }
    }

    func testBodyShorterThanContentLengthIsIncomplete() {
        let server = HookServer()
        let raw = "POST /v1/stop HTTP/1.1\r\nContent-Length: 10\r\n\r\n{}"
        if case .incomplete = server.parse(request(raw)) {
            // expected: body still streaming in
        } else {
            XCTFail("a body shorter than Content-Length must be incomplete")
        }
    }

    // MARK: - parse: hostile input

    func testNegativeContentLengthIsRejectedNotCrashing() {
        let server = HookServer()
        let raw = "POST /v1/stop HTTP/1.1\r\nContent-Length: -1\r\n\r\n"
        if case .tooLarge = server.parse(request(raw)) {
            // expected: rejected before any Data-range math can trap
        } else {
            XCTFail("a negative Content-Length must be rejected, not parsed")
        }
    }

    func testOversizedContentLengthIsTooLarge() {
        let server = HookServer()
        let raw = "POST /v1/stop HTTP/1.1\r\nContent-Length: 2097152\r\n\r\n"
        if case .tooLarge = server.parse(request(raw)) {
            // expected: over the 1 MiB cap
        } else {
            XCTFail("a Content-Length over the cap must be tooLarge")
        }
    }

    func testUnboundedHeaderSectionIsTooLarge() {
        let server = HookServer()
        // No \r\n\r\n terminator and more bytes than the cap: must bail, not buffer forever.
        var raw = Data("POST /v1/stop HTTP/1.1\r\nX-Junk: ".utf8)
        raw.append(Data(repeating: UInt8(ascii: "a"), count: (1 << 20) + 1))
        if case .tooLarge = server.parse(raw) {
            // expected
        } else {
            XCTFail("an unbounded header section must be tooLarge")
        }
    }

    // MARK: - authorized

    func testAuthorizedAcceptsExactToken() {
        let server = HookServer()
        XCTAssertTrue(server.authorized("Bearer \(server.token)"))
    }

    func testAuthorizedRejectsWrongMissingOrMalformedTokens() {
        let server = HookServer()
        XCTAssertFalse(server.authorized(nil), "missing header must be rejected")
        XCTAssertFalse(server.authorized(""), "empty header must be rejected")
        XCTAssertFalse(server.authorized(server.token), "token without the Bearer prefix must be rejected")
        XCTAssertFalse(server.authorized("Bearer "), "empty token must be rejected")
        XCTAssertFalse(server.authorized("Bearer \(server.token)x"), "token with a suffix must be rejected")
        XCTAssertFalse(server.authorized("Bearer \(String(server.token.dropLast()))"), "truncated token must be rejected")
    }
}

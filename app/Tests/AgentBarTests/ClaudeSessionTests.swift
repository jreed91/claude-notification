import XCTest
@testable import AgentBar

/// Tests for the pure core of the Claude Code transcript parser (`SessionScanner`). The
/// transcript's line shapes are only loosely pinned in the public docs, so these lock in the
/// fields the roster relies on — in particular `stop_reason`, the transcript's own
/// authoritative "is this turn still working" signal that keeps a long-running tool call from
/// being misread as idle.
final class ClaudeSessionTests: XCTestCase {

    private let fileURL = URL(fileURLWithPath: "/Users/me/.claude/projects/-Users-me-proj/abc.jsonl")

    private func parse(_ jsonl: String, folderName: String = "-Users-me-proj") -> ClaudeSession {
        SessionScanner.parseTranscript(
            contents: jsonl,
            sessionID: "abc",
            folderName: folderName,
            modified: Date(timeIntervalSince1970: 1_700_000_000),
            fileURL: fileURL
        )
    }

    // MARK: - isTurnInFlight (stop_reason)

    /// A turn whose last main-chain assistant message stopped for `tool_use` is still working —
    /// the agent has committed to another tool call and has not ended the turn.
    func testTurnInFlightWhenLastAssistantStoppedForToolUse() {
        let jsonl = """
        {"type":"user","timestamp":"2026-07-11T10:00:00Z","message":{"content":"Build the app"}}
        {"type":"assistant","timestamp":"2026-07-11T10:00:01Z","message":{"model":"claude-opus-4-8","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Bash","input":{"command":"swift build"}}]}}
        {"type":"user","timestamp":"2026-07-11T10:00:02Z","message":{"content":[{"type":"tool_result","content":"ok"}]}}
        {"type":"assistant","timestamp":"2026-07-11T10:00:03Z","message":{"model":"claude-opus-4-8","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Bash","input":{"command":"swift test"}}]}}
        """
        XCTAssertTrue(parse(jsonl).isTurnInFlight)
    }

    /// A completed turn (`end_turn`) is not in flight — the agent has yielded back to the user.
    func testTurnNotInFlightWhenLastAssistantEndedTurn() {
        let jsonl = """
        {"type":"user","timestamp":"2026-07-11T10:00:00Z","message":{"content":"Explain this"}}
        {"type":"assistant","timestamp":"2026-07-11T10:00:01Z","message":{"model":"claude-opus-4-8","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/a.swift"}}]}}
        {"type":"user","timestamp":"2026-07-11T10:00:02Z","message":{"content":[{"type":"tool_result","content":"…"}]}}
        {"type":"assistant","timestamp":"2026-07-11T10:00:03Z","message":{"model":"claude-opus-4-8","stop_reason":"end_turn","content":[{"type":"text","text":"Here is what it does."}]}}
        """
        XCTAssertFalse(parse(jsonl).isTurnInFlight)
    }

    /// A trailing assistant message still streaming carries no `stop_reason` yet; the last
    /// known reason (`tool_use`) must stand so an in-flight turn isn't misread as finished.
    func testTurnInFlightSurvivesTrailingMessageWithoutStopReason() {
        let jsonl = """
        {"type":"assistant","timestamp":"2026-07-11T10:00:01Z","message":{"model":"claude-opus-4-8","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Bash","input":{"command":"make"}}]}}
        {"type":"assistant","timestamp":"2026-07-11T10:00:02Z","message":{"model":"claude-opus-4-8","content":[{"type":"text","text":"partial…"}]}}
        """
        XCTAssertTrue(parse(jsonl).isTurnInFlight)
    }

    /// A subagent (`isSidechain`) turn's `stop_reason` must not set the main session's state:
    /// a sidechain still calling tools while the main turn has ended reads as not in flight.
    func testSidechainStopReasonIgnored() {
        let jsonl = """
        {"type":"assistant","timestamp":"2026-07-11T10:00:01Z","message":{"model":"claude-opus-4-8","stop_reason":"end_turn","content":[{"type":"text","text":"Done."}]}}
        {"type":"assistant","timestamp":"2026-07-11T10:00:02Z","isSidechain":true,"message":{"model":"claude-opus-4-8","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Grep","input":{"pattern":"x"}}]}}
        """
        XCTAssertFalse(parse(jsonl).isTurnInFlight)
    }

    /// A brand-new session with no assistant turn yet is not in flight.
    func testTurnNotInFlightWithNoAssistantTurn() {
        let jsonl = #"{"type":"user","timestamp":"2026-07-11T10:00:00Z","message":{"content":"hi"}}"#
        XCTAssertFalse(parse(jsonl).isTurnInFlight)
    }

    // MARK: - Regression: the rest of the row still parses

    func testTitleModelContextAndCwdStillParse() {
        let jsonl = """
        {"type":"user","cwd":"/Users/me/proj","timestamp":"2026-07-11T10:00:00Z","message":{"content":"Add a login button"}}
        {"type":"assistant","timestamp":"2026-07-11T10:00:01Z","message":{"model":"claude-opus-4-8","stop_reason":"end_turn","content":[{"type":"text","text":"Added."}],"usage":{"input_tokens":100,"cache_read_input_tokens":900,"cache_creation_input_tokens":0}}}
        """
        let session = parse(jsonl)
        XCTAssertEqual(session.id, "abc")
        XCTAssertEqual(session.title, "Add a login button")
        XCTAssertEqual(session.cwd, "/Users/me/proj")
        XCTAssertEqual(session.model, "claude-opus-4-8")
        XCTAssertEqual(session.contextTokens, 1000)
        XCTAssertEqual(session.messageCount, 2)
    }

    /// With no `cwd` on any entry, the path-encoded project folder is decoded as a fallback.
    func testCwdFallsBackToDecodedFolder() {
        let jsonl = #"{"type":"user","timestamp":"2026-07-11T10:00:00Z","message":{"content":"hi"}}"#
        XCTAssertEqual(parse(jsonl, folderName: "-Users-me-proj").cwd, "/Users/me/proj")
    }
}

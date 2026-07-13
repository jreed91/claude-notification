import XCTest
@testable import AgentBar

/// Table tests for `ContextGauge` — the model-label and context-usage logic the README
/// documents in detail (200k default, 1M for models that ship it, promotion past the 200k
/// tier, amber at 75% / red at 90%). A silent regression here mis-renders every gauge.
final class ContextGaugeTests: XCTestCase {

    // MARK: - Window sizing

    func testUnknownModelDefaultsTo200k() {
        XCTAssertEqual(ContextGauge.window(for: nil, usedTokens: 48_000), 200_000)
        XCTAssertEqual(ContextGauge.window(for: "claude-sonnet-4-5-20250929", usedTokens: 48_000), 200_000)
    }

    func testUsageBeyond200kPromotesTo1M() {
        // A 200k model can't exceed its own window, so usage above it means a larger one.
        XCTAssertEqual(ContextGauge.window(for: nil, usedTokens: 200_001), 1_000_000)
        XCTAssertEqual(ContextGauge.window(for: "claude-sonnet-4-5", usedTokens: 250_000), 1_000_000)
        XCTAssertEqual(ContextGauge.window(for: nil, usedTokens: 200_000), 200_000,
                       "exactly the standard window is still the standard window")
    }

    func testMillionTokenModelsAlwaysMeasureAgainst1M() {
        XCTAssertEqual(ContextGauge.window(for: "claude-opus-4-8", usedTokens: 10_000), 1_000_000)
        XCTAssertEqual(ContextGauge.window(for: "claude-sonnet-5-20260101", usedTokens: 10_000), 1_000_000)
        XCTAssertEqual(ContextGauge.window(for: "Claude-Opus-4-8", usedTokens: 10_000), 1_000_000,
                       "model matching is case-insensitive")
    }

    // MARK: - Percent

    func testPercentAgainstTheRightWindow() {
        XCTAssertEqual(ContextGauge.percent(48_000, model: nil), 24)
        XCTAssertEqual(ContextGauge.percent(100_000, model: "claude-opus-4-8"), 10)
        XCTAssertEqual(ContextGauge.percent(250_000, model: "claude-sonnet-4-5"), 25,
                       "promoted sessions measure against 1M")
    }

    func testPercentClamps() {
        XCTAssertEqual(ContextGauge.percent(0, model: nil), 0)
        XCTAssertEqual(ContextGauge.percent(2_000_000, model: "claude-opus-4-8"), 100)
    }

    // MARK: - Warning tiers

    func testTierThresholds() {
        XCTAssertEqual(ContextGauge.tier(148_000, model: nil), .normal)   // 74%
        XCTAssertEqual(ContextGauge.tier(150_000, model: nil), .warning)  // 75%
        XCTAssertEqual(ContextGauge.tier(178_000, model: nil), .warning)  // 89%
        XCTAssertEqual(ContextGauge.tier(180_000, model: nil), .critical) // 90%
    }

    // MARK: - Labels

    func testPrettyModelTrimsPrefixAndStamp() {
        XCTAssertEqual(ContextGauge.prettyModel("claude-sonnet-4-5-20250929"), "sonnet-4-5")
        XCTAssertEqual(ContextGauge.prettyModel("claude-opus-4-8"), "opus-4-8")
        XCTAssertEqual(ContextGauge.prettyModel("some-other-model"), "some-other-model")
        XCTAssertEqual(ContextGauge.prettyModel("claude-"), "claude-",
                       "a degenerate id falls back to the raw string")
    }

    func testFormatTokens() {
        XCTAssertEqual(ContextGauge.formatTokens(999), "999")
        XCTAssertEqual(ContextGauge.formatTokens(1_000), "1k")
        XCTAssertEqual(ContextGauge.formatTokens(48_200), "48k")
        XCTAssertEqual(ContextGauge.formatTokens(1_500), "2k", "rounds to the nearest thousand")
    }
}

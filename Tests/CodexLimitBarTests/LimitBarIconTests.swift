import XCTest
@testable import CodexLimitBar

final class LimitBarIconTests: XCTestCase {
    @MainActor
    func testMenuBarImageHasFixedSize() {
        XCTAssertEqual(LimitBarIcon.image.size.width, 16)
        XCTAssertEqual(LimitBarIcon.image.size.height, 16)
        XCTAssertTrue(LimitBarIcon.image.isTemplate)
        XCTAssertNotNil(LimitBarIcon.image.tiffRepresentation)
    }

    @MainActor
    func testPercentageLabelHandlesUnavailableAndClampedValues() {
        XCTAssertEqual(LimitBarIcon.percentageLabel(remainingPercent: nil), "--%")
        XCTAssertEqual(LimitBarIcon.percentageLabel(remainingPercent: -1), "0%")
        XCTAssertEqual(LimitBarIcon.percentageLabel(remainingPercent: 42), "42%")
        XCTAssertEqual(LimitBarIcon.percentageLabel(remainingPercent: 101), "100%")
    }

    @MainActor
    func testAccessibilityLabelIncludesRemainingPercentage() {
        XCTAssertEqual(
            LimitBarIcon.accessibilityLabel(remainingPercent: nil),
            L10n.text("app_name")
        )
        XCTAssertTrue(
            LimitBarIcon.accessibilityLabel(remainingPercent: 42).contains("42%")
        )
    }
}

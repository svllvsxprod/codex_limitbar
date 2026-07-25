import XCTest
@testable import CodexLimitBar

final class LimitBarIconTests: XCTestCase {
    @MainActor
    func testMenuBarImageHasFixedSize() {
        XCTAssertEqual(LimitBarIcon.image.size.width, 16)
        XCTAssertEqual(LimitBarIcon.image.size.height, 16)
        XCTAssertTrue(LimitBarIcon.image.isTemplate)
    }
}

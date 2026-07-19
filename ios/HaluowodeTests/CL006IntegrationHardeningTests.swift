import XCTest
@testable import Haluowode

final class CL006IntegrationHardeningTests: XCTestCase {
    
    /// AG-009: Locks the PublishView step indicator text formatting for steps 1, 2, and 3
    /// using XCTest as required by the quality gate.
    func testPublishStepIndicatorTexts() {
        XCTAssertEqual(PublishView.stepIndicatorText(step: 1), "第 1 步，共 3 步")
        XCTAssertEqual(PublishView.stepIndicatorText(step: 2), "第 2 步，共 3 步")
        XCTAssertEqual(PublishView.stepIndicatorText(step: 3), "第 3 步，共 3 步")
    }
}

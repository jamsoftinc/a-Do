import XCTest
@testable import a_do

final class AppCoreTests: XCTestCase {
    func testHashtagExtractionReturnsExpectedTags() {
        let tags = ReminderCreationService.shared.extractHashtagNames(from: "Email #work and #health before #workout")

        XCTAssertTrue(tags.contains("work"))
        XCTAssertTrue(tags.contains("health"))
        XCTAssertTrue(tags.contains("workout"))
    }

    func testQuickCaptureReviewRequiredForMultipleRequests() {
        let viewModel = ReminderHomeViewModel()
        let requests = [
            ReminderCreationService.Request(title: "Plan quarterly review"),
            ReminderCreationService.Request(title: "Send summary")
        ]

        let shouldReview = viewModel.shouldReviewQuickCaptureForTesting(
            originalInput: "Plan quarterly review and send summary",
            requests: requests
        )

        XCTAssertTrue(shouldReview)
    }

    func testQuickCaptureReviewSkippedForExactSimpleMatch() {
        let viewModel = ReminderHomeViewModel()
        let requests = [
            ReminderCreationService.Request(title: "Buy milk")
        ]

        let shouldReview = viewModel.shouldReviewQuickCaptureForTesting(
            originalInput: "Buy milk",
            requests: requests
        )

        XCTAssertFalse(shouldReview)
    }

    func testHashtagExtractionPerformance() {
        measure {
            _ = ReminderCreationService.shared.extractHashtagNames(
                from: Array(repeating: "Review roadmap #work #planning #q2", count: 200).joined(separator: " ")
            )
        }
    }
}

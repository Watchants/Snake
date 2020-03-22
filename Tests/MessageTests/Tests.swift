import XCTest
@testable import Snake

final class SnakeTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Snake().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

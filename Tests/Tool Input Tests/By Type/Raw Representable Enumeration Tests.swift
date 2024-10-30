/// This file was Claudegenned, and required some light adjustment to get working

import XCTest

@testable import ClaudeToolInput

final class RawRepresentableEnumerationTests: XCTestCase {

  enum TestEnum: String, CaseIterable, ToolInput {
    case one = "1"
    case two = "2"
    case three = "3"
  }

  func testEnumerationSchema() async throws {
    XCTAssertEqual(
      try encode(TestEnum.toolInputSchema),
      """
      {
        "enum" : [
          "1",
          "2",
          "3"
        ]
      }
      """
    )

    XCTAssertEqual(
      try encode(TestEnum.toolInputSchema) { schema in
        schema.description = "A test enumeration"
      },
      """
      {
        "description" : "A test enumeration",
        "enum" : [
          "1",
          "2",
          "3"
        ]
      }
      """
    )
  }

  func testEnumerationEncoding() async throws {
    XCTAssertEqual(
      try encode(TestEnum.one),
      """
      "1"
      """
    )

    XCTAssertEqual(
      try encode(TestEnum.two),
      """
      "2"
      """
    )

    XCTAssertEqual(
      try encode(TestEnum.three),
      """
      "3"
      """
    )
  }

  func testEnumerationDecoding() async throws {
    XCTAssertEqual(
      try decode(
        TestEnum.self,
        """
        "1"
        """
      ),
      TestEnum.one
    )

    XCTAssertEqual(
      try decode(
        TestEnum.self,
        """
        "2"
        """
      ),
      TestEnum.two
    )

    XCTAssertEqual(
      try decode(
        TestEnum.self,
        """
        "3"
        """
      ),
      TestEnum.three
    )

    XCTAssertThrowsError(
      try decode(
        TestEnum.self,
        """
        "4"
        """
      )
    )
  }

  enum IntEnum: Int, CaseIterable, ToolInput {
    case zero = 0
    case one = 1
    case two = 2
  }

  func testIntEnumerationSchema() async throws {
    XCTAssertEqual(
      try encode(IntEnum.toolInputSchema),
      """
      {
        "enum" : [
          0,
          1,
          2
        ]
      }
      """
    )
  }

  func testIntEnumerationEncoding() async throws {
    XCTAssertEqual(
      try encode(IntEnum.zero),
      """
      0
      """
    )

    XCTAssertEqual(
      try encode(IntEnum.one),
      """
      1
      """
    )

    XCTAssertEqual(
      try encode(IntEnum.two),
      """
      2
      """
    )
  }

  func testIntEnumerationDecoding() async throws {
    XCTAssertEqual(
      try decode(
        IntEnum.self,
        """
        0
        """
      ),
      IntEnum.zero
    )

    XCTAssertEqual(
      try decode(
        IntEnum.self,
        """
        1
        """
      ),
      IntEnum.one
    )

    XCTAssertEqual(
      try decode(
        IntEnum.self,
        """
        2
        """
      ),
      IntEnum.two
    )

    XCTAssertThrowsError(
      try decode(
        IntEnum.self,
        """
        3
        """
      )
    )
  }
}

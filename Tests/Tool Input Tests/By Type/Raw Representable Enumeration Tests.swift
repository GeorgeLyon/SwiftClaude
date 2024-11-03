/// This file was Claudegenned, and required some light adjustment to get working

import Testing

@testable import ClaudeToolInput

@Suite
struct RawRepresentableEnumerationTests {

  enum TestEnum: String, CaseIterable, ToolInput {
    case one = "1"
    case two = "2"
    case three = "3"
  }

  @Test
  func testEnumerationSchema() async throws {
    #expect(
      try encode(TestEnum.toolInputSchema) == """
        {
          "enum" : [
            "1",
            "2",
            "3"
          ]
        }
        """
    )

    #expect(
      try encode(TestEnum.toolInputSchema) { schema in
        schema.description = "A test enumeration"
      } == """
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

  @Test
  func testEnumerationEncoding() async throws {
    #expect(
      try encode(TestEnum.one) == """
        "1"
        """
    )

    #expect(
      try encode(TestEnum.two) == """
        "2"
        """
    )

    #expect(
      try encode(TestEnum.three) == """
        "3"
        """
    )
  }

  @Test
  func testEnumerationDecoding() async throws {
    #expect(
      try decode(
        TestEnum.self,
        """
        "1"
        """
      ) == TestEnum.one
    )

    #expect(
      try decode(
        TestEnum.self,
        """
        "2"
        """
      ) == TestEnum.two
    )

    #expect(
      try decode(
        TestEnum.self,
        """
        "3"
        """
      ) == TestEnum.three
    )

    #expect(
      performing: {
        try decode(
          TestEnum.self,
          """
          "4"
          """
        )
      },
      throws: { _ in true }
    )
  }

  enum IntEnum: Int, CaseIterable, ToolInput {
    case zero = 0
    case one = 1
    case two = 2
  }

  @Test
  func testIntEnumerationSchema() async throws {
    #expect(
      try encode(IntEnum.toolInputSchema) == """
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

  @Test
  func testIntEnumerationEncoding() async throws {
    #expect(
      try encode(IntEnum.zero) == """
        0
        """
    )

    #expect(
      try encode(IntEnum.one) == """
        1
        """
    )

    #expect(
      try encode(IntEnum.two) == """
        2
        """
    )
  }

  @Test
  func testIntEnumerationDecoding() async throws {
    #expect(
      try decode(
        IntEnum.self,
        """
        0
        """
      ) == IntEnum.zero
    )

    #expect(
      try decode(
        IntEnum.self,
        """
        1
        """
      ) == IntEnum.one
    )

    #expect(
      try decode(
        IntEnum.self,
        """
        2
        """
      ) == IntEnum.two
    )

    #expect {
      try decode(
        IntEnum.self,
        """
        3
        """
      )
    } throws: { _ in
      true
    }
  }
}

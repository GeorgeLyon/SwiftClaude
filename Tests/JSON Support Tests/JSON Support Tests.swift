import Foundation
import Testing

@testable import JSONSupport

@Suite
private struct JSONSupportTests {

  @Test
  func basicTests() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Complete string
    byteBuffer.append(
      """
      Hello, World!"
      """
    )
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello, World!")
    byteBuffer.reset()
    stringBuffer.reset()

    /// Partial string
    byteBuffer.append("Hello")
    byteBuffer.append(", ")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    /// Trailing space is omitted because the last character can be modified by subsequent characters.
    #expect(stringBuffer.stringValue == "Hello,")
    byteBuffer.append("World!")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    /// Exclamation mark is omitted because the last character can be modified by subsequent characters, but the space after the comma is returned now.
    #expect(stringBuffer.stringValue == "Hello, World")
    byteBuffer.append("\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello, World!")
  }

}

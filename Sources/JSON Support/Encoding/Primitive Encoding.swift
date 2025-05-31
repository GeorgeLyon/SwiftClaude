/// We probably want to move off of `JSONSerialization`, but this works for now.
private import class Foundation.JSONSerialization
private import class Foundation.NSNull

extension JSON.EncodingStream {

  // MARK: - Null

  public mutating func encodeNull() { write("null") }

  // MARK: - Boolean

  public mutating func encode(_ value: Bool) {
    if value {
      write("true")
    } else {
      write("false")
    }
  }

  // MARK: - Integers

  public mutating func encode(_ value: Int) { write(String(value)) }
  public mutating func encode(_ value: Int8) { write(String(value)) }
  public mutating func encode(_ value: Int16) { write(String(value)) }
  public mutating func encode(_ value: Int32) { write(String(value)) }
  public mutating func encode(_ value: Int64) { write(String(value)) }
  public mutating func encode(_ value: UInt) { write(String(value)) }
  public mutating func encode(_ value: UInt8) { write(String(value)) }
  public mutating func encode(_ value: UInt16) { write(String(value)) }
  public mutating func encode(_ value: UInt32) { write(String(value)) }
  public mutating func encode(_ value: UInt64) { write(String(value)) }
  public mutating func encode<T: BinaryInteger>(_ value: T) { write(String(value)) }

  // MARK: - Floats

  public mutating func encode(_ value: Float16) { write(String(value)) }
  public mutating func encode(_ value: Float32) { write(String(value)) }
  public mutating func encode(_ value: Double) { write(String(value)) }

  // MARK: - String

  public mutating func encode(_ value: String) {
    /// For now, just use JSONSerialization to ensure we handle all edge cases properly
    let data = try! JSONSerialization.data(
      withJSONObject: value,
      options: .fragmentsAllowed
    )
    let string = String(data: data, encoding: .utf8)!
    write(string)
  }

  // MARK: - Implementation Details

  private mutating func encodePrimitive(
    _ value: Any
  ) {
    
  }

}

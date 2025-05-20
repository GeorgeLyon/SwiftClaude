/// We probably want to move off of `JSONSerialization`, but this works for now.
private import class Foundation.JSONSerialization
private import class Foundation.NSNull

extension JSON.EncodingStream {

  // MARK: - Null

  public mutating func encodeNull() { encodePrimitive(NSNull()) }

  // MARK: - String

  public mutating func encode(_ value: String) { encodePrimitive(value) }

  // MARK: - Boolean

  public mutating func encode(_ value: Bool) { encodePrimitive(value) }

  // MARK: - Integers

  public mutating func encode(_ value: Int) { encodePrimitive(value) }
  public mutating func encode(_ value: Int8) { encodePrimitive(value) }
  public mutating func encode(_ value: Int16) { encodePrimitive(value) }
  public mutating func encode(_ value: Int32) { encodePrimitive(value) }
  public mutating func encode(_ value: Int64) { encodePrimitive(value) }
  public mutating func encode(_ value: UInt) { encodePrimitive(value) }
  public mutating func encode(_ value: UInt8) { encodePrimitive(value) }
  public mutating func encode(_ value: UInt16) { encodePrimitive(value) }
  public mutating func encode(_ value: UInt32) { encodePrimitive(value) }
  public mutating func encode(_ value: UInt64) { encodePrimitive(value) }

  // MARK: - Floats

  public mutating func encode(_ value: Float16) { encodePrimitive(value) }
  public mutating func encode(_ value: Float32) { encodePrimitive(value) }
  public mutating func encode(_ value: Double) { encodePrimitive(value) }

  // MARK: - Implementation Details

  private mutating func encodePrimitive(
    _ value: Any
  ) {
    let data = try! JSONSerialization.data(
      withJSONObject: value,
      options: .fragmentsAllowed
    )
    let string = String(data: data, encoding: .utf8)!
    write(string)
  }

}

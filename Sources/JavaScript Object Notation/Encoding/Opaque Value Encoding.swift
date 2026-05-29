extension EncodingStream {

  public mutating func encode(_ value: OpaqueValue) {
    write(value.bytes)
  }

}

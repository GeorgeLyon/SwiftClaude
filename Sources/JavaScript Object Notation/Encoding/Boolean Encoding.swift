extension EncodingStream {

  public mutating func encode(_ value: Bool) {
    if value {
      write("true")
    } else {
      write("false")
    }
  }

}

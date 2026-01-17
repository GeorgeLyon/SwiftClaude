extension SchemaCoding.Support {

  public enum UnimplementedSchema<Value>: InternalSchema {

    public func encode(_ value: Value, to encoder: inout Encoder) {

    }

    public func beginDecodingValue(from decoder: borrowing Decoder) {

    }

    public func decodeValue(from decoder: inout Decoder, state: inout Void) throws
      -> DecodingResult<Value>
    {
      switch self {}
    }

    public var metaSchema: UnimplementedSchema<Self> {
      switch self {}
    }

    public var description: String? {
      get { switch self {} }
      set {}
    }

  }

}

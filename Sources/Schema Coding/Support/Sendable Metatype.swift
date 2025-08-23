#if swift(>=6.2)
  public protocol _SendableMetatype: SendableMetatype {

  }
#else
  public protocol _SendableMetatype {
  }
#endif

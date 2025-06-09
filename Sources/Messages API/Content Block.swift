public import SchemaCoding

@SchemaCodable
public enum ContentBlock {

  @SchemaCodable
  public struct Text {
    let text: String
  }
  case text(Text)

  @SchemaCodable
  public struct Image {

    @SchemaCodable
    public enum Source {

      @SchemaCodable
      public struct Base64 {
        let mediaType: String
        let data: String
      }
      case base64(Base64)
    }
  }
  case image(Image)

}

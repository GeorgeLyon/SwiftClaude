@APICodable
public enum ContentBlock {

  @APICodable
  public struct Text {
    let text: String
  }
  case text(Text)

  @APICodable
  public struct Image {

    @APICodable
    public enum Source {

      @APICodable
      public struct Base64 {
        let mediaType: String
        let data: String
      }
      case base64(Base64)
    }
  }
  case image(Image)

}

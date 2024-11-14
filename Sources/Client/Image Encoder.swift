extension ClaudeClient.Image {

  public struct Size: Sendable {
    public init(
      widthInPixels: Int,
      heightInPixels: Int
    ) {
      self.widthInPixels = widthInPixels
      self.heightInPixels = heightInPixels
    }
    public let widthInPixels: Int
    public let heightInPixels: Int
  }

}

extension ClaudeClient {

  /// `ImageEncoder` doesn't actually do any images, its just a store for the image encoding settings of a given model
  public enum Image {

    public struct Encoder {

      /// https://docs.anthropic.com/en/docs/build-with-claude/vision
      public static var `default`: Encoder {
        Encoder(
          maximumRecommendedPixelCount: 1_150_000,
          maximumRecommendedEdgeLength: 1568,
          minimumRecommendedEdgeLength: 200
        )
      }

      private let maximumRecommendedPixelCount: Double
      private let maximumRecommendedEdgeLength: Double
      private let minimumRecommendedEdgeLength: Double
    }

    public struct PreprocessingMode {

      /// Use whatever processing `SwiftClaude` deems appropriate
      /// - Parameters:
      ///   - quality:
      ///       A number between 0 and 1.
      ///       A quality of 0 will downsize images up to the minimum recommended size.
      ///       A quality of 1 will downsize images up to the maximum recommended size.
      public static func recommended(quality: Double = 1) -> Self {
        Self(kind: .default(quality: 1))
      }

      /// Don't process the images at all
      public static var disabled: Self {
        Self(kind: .disabled)
      }

      enum Kind {
        case `default`(quality: Double)
        case disabled
      }
      let kind: Kind
    }

  }

}

extension ClaudeClient.Image.Encoder {

  public typealias ImageSize = ClaudeClient.Image.Size

  public func recommendedSize(
    forSourceImageOfSize size: ImageSize,
    preprocessingMode: ClaudeClient.Image.PreprocessingMode
  ) throws -> sending ImageSize {
    guard case .default(let quality) = preprocessingMode.kind else { return size }
    assert((0...1).contains(quality))

    let aspectRatio = Double(size.widthInPixels) / Double(size.heightInPixels)
    /// `width = height * aspectRatio`
    /// `height = width / aspectRatio`

    let minimumHeight: Double
    do {
      if size.widthInPixels > size.heightInPixels {
        minimumHeight = minimumRecommendedEdgeLength
      } else {
        minimumHeight = minimumRecommendedEdgeLength / aspectRatio
      }
    }

    guard minimumHeight < Double(size.heightInPixels) else {
      throw ImageSmallerThanMinimumRecommendedSize(
        minimumSize: ImageSize(
          widthInPixels: Int(minimumHeight * aspectRatio),
          heightInPixels: Int(minimumHeight)
        )
      )
    }

    let maximumRecommendedHeightBasedOnTotalNumberOfPixels =
      (maximumRecommendedPixelCount / aspectRatio).squareRoot()

    let maximumRecommendedHeightBasedOnLongestEdge: Double
    do {
      if size.widthInPixels < size.heightInPixels {
        maximumRecommendedHeightBasedOnLongestEdge = maximumRecommendedEdgeLength
      } else {
        maximumRecommendedHeightBasedOnLongestEdge = maximumRecommendedEdgeLength / aspectRatio
      }
    }

    let maximumHeight = min(
      maximumRecommendedHeightBasedOnTotalNumberOfPixels,
      maximumRecommendedHeightBasedOnLongestEdge,
      Double(size.heightInPixels)
    )

    let qualityAdjustedRecommendedHeight =
      ((maximumHeight - minimumHeight) * quality) + minimumHeight

    return ImageSize(
      widthInPixels: Int(qualityAdjustedRecommendedHeight * aspectRatio),
      heightInPixels: Int(qualityAdjustedRecommendedHeight)
    )

  }

  private struct ImageSmallerThanMinimumRecommendedSize: Error {
    let minimumSize: ImageSize
  }

}

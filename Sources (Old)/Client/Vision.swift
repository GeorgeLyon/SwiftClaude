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

  public struct Vision {

    /// https://docs.anthropic.com/en/docs/build-with-claude/vision
    public static var standard: Vision {
      Vision(
        configuration: Configuration(
          maximumRecommendedPixelCount: 1_150_000,
          maximumRecommendedEdgeLength: 1568,
          minimumRecommendedEdgeLength: 200
        )
      )
    }

    public static var unavailable: Vision {
      Vision(configuration: nil)
    }

    private struct Configuration {
      let maximumRecommendedPixelCount: Double
      let maximumRecommendedEdgeLength: Double
      let minimumRecommendedEdgeLength: Double
    }
    private let configuration: Configuration?

  }

  /// `ImageEncoder` doesn't actually do any images, its just a store for the image encoding settings of a given model
  public enum Image {

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

extension ClaudeClient.Vision {

  public typealias ImageSize = ClaudeClient.Image.Size

  public func recommendedSize(
    forSourceImageOfSize size: ImageSize,
    preprocessingMode: ClaudeClient.Image.PreprocessingMode
  ) throws -> sending ImageSize {
    guard let configuration = configuration else {
      throw ModelDoesNotSupportVision()
    }
    guard case .default(let quality) = preprocessingMode.kind else { return size }
    assert((0...1).contains(quality))

    let aspectRatio = Double(size.widthInPixels) / Double(size.heightInPixels)
    /// `width = height * aspectRatio`
    /// `height = width / aspectRatio`

    let minimumHeight: Double
    do {
      if size.widthInPixels > size.heightInPixels {
        minimumHeight = configuration.minimumRecommendedEdgeLength
      } else {
        minimumHeight = configuration.minimumRecommendedEdgeLength / aspectRatio
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
      (configuration.maximumRecommendedPixelCount / aspectRatio).squareRoot()

    let maximumRecommendedHeightBasedOnLongestEdge: Double
    do {
      if size.widthInPixels < size.heightInPixels {
        maximumRecommendedHeightBasedOnLongestEdge = configuration.maximumRecommendedEdgeLength
      } else {
        maximumRecommendedHeightBasedOnLongestEdge =
          configuration.maximumRecommendedEdgeLength / aspectRatio
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

  private struct ModelDoesNotSupportVision: Error {

  }

}

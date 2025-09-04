public struct Vision {

  /// https://docs.anthropic.com/en/docs/build-with-claude/vision
  public static var anthropicDefault: Vision {
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

extension Vision {

  public func recommendedSize(
    forSourceImageOfSize size: Image.Size,
    preprocessingMode: Image.PreprocessingMode
  ) throws -> Image.Size {
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
        minimumSize: Image.Size(
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

    return Image.Size(
      widthInPixels: Int(qualityAdjustedRecommendedHeight * aspectRatio),
      heightInPixels: Int(qualityAdjustedRecommendedHeight)
    )

  }

  private struct ImageSmallerThanMinimumRecommendedSize: Error {
    let minimumSize: Image.Size
  }

  private struct ModelDoesNotSupportVision: Error {

  }

}

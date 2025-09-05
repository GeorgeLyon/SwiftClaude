private import struct Foundation.Data

#if canImport(AppKit)
  public import AppKit
#endif

#if canImport(UIKit)
  public import UIKit
#endif

public struct Image {

  #if canImport(UIKit)
    public init(
      _ image: UIImage
    ) {
      self.backing = image
    }
  #endif

  #if canImport(AppKit)
    public init(
      _ image: NSImage
    ) {
      self.backing = image
    }
  #endif

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
  public var size: Size {
    backing.imageSize
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

  public func block(
    vision: Vision,
    preprocessingMode: PreprocessingMode
  ) throws -> ImageBlock {

    let preprocessedImage: ImageBacking
    let recommendedSize = try vision.recommendedSize(
      forSourceImageOfSize: size,
      preprocessingMode: preprocessingMode
    )
    if recommendedSize.widthInPixels != size.widthInPixels,
      recommendedSize.heightInPixels != size.heightInPixels
    {
      preprocessedImage = try backing.resized(to: recommendedSize)
    } else {
      preprocessedImage = backing
    }

    return ImageBlock(
      source: MediaSource.Base64(
        mediaType: .image.png,
        data: try preprocessedImage.pngRepresentation
      )
    )

  }

  private let backing: ImageBacking

}

private protocol ImageBacking {
  func resized(to newSize: Image.Size) throws -> ImageBacking
  var pngRepresentation: Data { get throws }
  var imageSize: Image.Size { get }
}

#if canImport(UIKit)

  extension UIImage: ImageBacking {

    fileprivate var imageSize: Image.Size {
      Image.Size(
        widthInPixels: Int(size.width),
        heightInPixels: Int(size.height)
      )
    }

    fileprivate func resized(to newSize: Image.Size) throws -> ImageBacking {
      let newSize = CGSize(
        width: newSize.widthInPixels,
        height: newSize.heightInPixels
      )
      UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
      defer { UIGraphicsEndImageContext() }
      self.draw(in: CGRect(origin: .zero, size: newSize))
      guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
        throw ResizingFailed()
      }
      return resizedImage
    }

    fileprivate var pngRepresentation: Data {
      get throws {
        guard let data = pngData() else {
          throw FailedToCreatePNGRepresentation()
        }
        return data
      }
    }

    private struct ResizingFailed: Error {}
    private struct FailedToCreatePNGRepresentation: Error {}
  }

#endif

#if canImport(AppKit)

  extension NSImage: ImageBacking {

    fileprivate var imageSize: Image.Size {
      Image.Size(
        widthInPixels: Int(size.width),
        heightInPixels: Int(size.height)
      )
    }

    fileprivate func resized(to newSize: Image.Size) throws -> ImageBacking {
      /// Logic adapted from https://stackoverflow.com/questions/11949250/how-to-resize-nsimage/42915296#42915296

      guard isValid else { throw InvalidImage() }
      let newSize = NSSize(
        width: newSize.widthInPixels,
        height: newSize.heightInPixels
      )

      guard
        let bitmapRep = NSBitmapImageRep(
          bitmapDataPlanes: nil,
          pixelsWide: Int(newSize.width),
          pixelsHigh: Int(newSize.height),
          bitsPerSample: 8,
          samplesPerPixel: 4,
          hasAlpha: true,
          isPlanar: false,
          colorSpaceName: .calibratedRGB,
          bytesPerRow: 0,
          bitsPerPixel: 0
        )
      else {
        throw ResizingFailed()
      }
      bitmapRep.size = newSize
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
      draw(
        in: NSRect(origin: .zero, size: newSize),
        from: .zero,
        operation: .copy,
        fraction: 1.0
      )
      NSGraphicsContext.restoreGraphicsState()

      let resizedImage = NSImage(size: newSize)
      resizedImage.addRepresentation(bitmapRep)
      return resizedImage
    }

    fileprivate var pngRepresentation: Data {
      get throws {
        guard isValid else { throw InvalidImage() }
        guard
          let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil),
          let data = NSBitmapImageRep(cgImage: cgImage).representation(
            using: .png, properties: [:]
          )
        else {
          throw FailedToCreatePNGRepresentation()
        }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(data.base64EncodedString(), forType: .string)
        return data
      }
    }

    private struct InvalidImage: Error {}
    private struct ResizingFailed: Error {}
    private struct FailedToCreatePNGRepresentation: Error {}
  }

#endif

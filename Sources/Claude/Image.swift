public import ClaudeClient

#if canImport(AppKit)
  public import AppKit
#endif

#if canImport(UIKit)
  public import UIKit
#endif

extension Claude {

  public struct Image {

    #if canImport(AppKit)
      public typealias PlatformImage = NSImage
    #endif

    #if canImport(UIKit)
      public typealias PlatformImage = UIImage
    #endif

    public init(
      _ image: PlatformImage
    ) {
      self.platformImage = image
    }

    public typealias Size = ClaudeClient.ImageSize
    public var size: Size {
      return Size(
        widthInPixels: Int(platformImage.size.width),
        heightInPixels: Int(platformImage.size.height)
      )
    }

    public typealias PreprocessingMode = ClaudeClient.Image.PreprocessingMode

    func messagesRequestMessageContent(
      for model: Model,
      preprocessingMode: PreprocessingMode
    ) throws -> ClaudeClient.MessagesEndpoint.Request.Message.Content {

      let preprocessedImage: PlatformImage
      let recommendedSize = try model.imageEncoder.recommendedSize(
        forSourceImageOfSize: size,
        preprocessingMode: preprocessingMode
      )
      if recommendedSize.widthInPixels != size.widthInPixels,
        recommendedSize.heightInPixels != size.heightInPixels
      {
        preprocessedImage = try platformImage.resized(to: recommendedSize)
      } else {
        preprocessedImage = platformImage
      }

      return [
        .image(
          mediaType: .png,
          data: try preprocessedImage.pngRepresentation
        )
      ]

    }

    let platformImage: PlatformImage

  }

}

extension Claude.Image {

}

#if canImport(UIKit)

  extension UIImage {

    fileprivate func resized(to newSize: ClaudeClient.ImageSize) throws -> UIImage {
      UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
      defer { UIGraphicsEndImageContext() }
      self.draw(in: CGRect(origin: .zero, size: size))
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

  extension NSImage {

    fileprivate func resized(to newSize: ClaudeClient.ImageSize) throws -> NSImage {
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

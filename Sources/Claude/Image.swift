public import ClaudeClient
public import ClaudeMessagesEndpoint

private import struct Foundation.Data

#if canImport(AppKit)
  public import AppKit
#endif

#if canImport(UIKit)
  public import UIKit
#endif

extension Claude {
  
  public typealias ImageSize = ClaudeClient.Image.Size

  public protocol Image {
    var size: Size { get }

    func messagesRequestMessageContent(
      for model: Model,
      preprocessingMode: PreprocessingMode
    ) throws -> ClaudeClient.MessagesEndpoint.Request.Message.Content
  }

}

extension Claude.Image {
  public typealias Size = ClaudeClient.Image.Size
  public typealias PreprocessingMode = ClaudeClient.Image.PreprocessingMode
}

extension Claude {

  struct PlatformImage: Image {

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

    public typealias Size = ClaudeClient.Image.Size
    public var size: Size {
      backing.claudeImageSize
    }

    public typealias PreprocessingMode = ClaudeClient.Image.PreprocessingMode

    public func messagesRequestMessageContent(
      for model: Model,
      preprocessingMode: PreprocessingMode
    ) throws -> ClaudeClient.MessagesEndpoint.Request.Message.Content {

      let preprocessedImage: PlatformImageBacking
      let recommendedSize = try model.imageEncoder.recommendedSize(
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

      return [
        .image(
          mediaType: .png,
          data: try preprocessedImage.pngRepresentation
        )
      ]

    }

    private let backing: PlatformImageBacking

  }

}

extension Claude.Image {

}

private protocol PlatformImageBacking {
  func resized(to newSize: ClaudeClient.Image.Size) throws -> PlatformImageBacking
  var pngRepresentation: Data { get throws }
  var claudeImageSize: Claude.Image.Size { get }
}

#if canImport(UIKit)

  extension UIImage: PlatformImageBacking {

    fileprivate var claudeImageSize: Claude.Image.Size {
      Claude.Image.Size(
        widthInPixels: Int(size.width),
        heightInPixels: Int(size.height)
      )
    }

    fileprivate func resized(to newSize: ClaudeClient.Image.Size) throws -> PlatformImageBacking {
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

  extension NSImage: PlatformImageBacking {

    fileprivate var claudeImageSize: Claude.Image.Size {
      Claude.Image.Size(
        widthInPixels: Int(size.width),
        heightInPixels: Int(size.height)
      )
    }

    fileprivate func resized(to newSize: ClaudeClient.Image.Size) throws -> PlatformImageBacking {
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

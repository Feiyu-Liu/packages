// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import CoreImage
import Flutter
import Foundation
import ImageIO

/// The completion handler block for save photo operations.
/// Can be called from either main queue or IO queue.
/// If success, `path` will be present and `error` will be nil. Otherwise, `path` will be nil and
/// `error` will be present.
/// path - the path for successfully saved photo file.
/// error - photo capture error or IO error.
typealias SavePhotoDelegateCompletionHandler = (String?, Error?) -> Void

/// Called when AVFoundation is about to capture a still photo.
typealias SavePhotoDelegateWillCaptureHandler = () -> Void

enum PhotoFileSaveMode {
  case original
  case sdrHeif
}

enum PhotoFileSaveError: LocalizedError {
  case missingPhotoData
  case missingCGImageRepresentation
  case failedToRenderSDRImage
  case failedToCreateHEIFDestination
  case failedToFinalizeHEIFDestination

  var errorDescription: String? {
    switch self {
    case .missingPhotoData:
      return "Captured photo did not produce writable image data."
    case .missingCGImageRepresentation:
      return "Captured photo did not produce a CGImage representation."
    case .failedToRenderSDRImage:
      return "Failed to render captured photo as an 8-bit SDR image."
    case .failedToCreateHEIFDestination:
      return "Failed to create HEIF image destination."
    case .failedToFinalizeHEIFDestination:
      return "Failed to finalize HEIF image destination."
    }
  }
}

/// Delegate object that handles photo capture results.
class SavePhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  /// The file path for the captured photo.
  private let path: String

  /// The queue on which captured photos are written to disk.
  private let ioQueue: DispatchQueue

  private let fileSaveMode: PhotoFileSaveMode

  private let cropMode: PlatformPhotoCropMode

  private let compressionQuality: Double

  private let ciContext: CIContext

  /// The completion handler block for capture and save photo operations.
  let completionHandler: SavePhotoDelegateCompletionHandler

  private let willCaptureHandler: SavePhotoDelegateWillCaptureHandler?

  /// The path for captured photo file.
  /// Exposed for unit tests to verify the captured photo file path.
  var filePath: String {
    path
  }

  var fileSaveModeForTesting: PhotoFileSaveMode {
    fileSaveMode
  }

  var compressionQualityForTesting: Double {
    compressionQuality
  }

  var cropModeForTesting: PlatformPhotoCropMode {
    cropMode
  }

  /// Initialize a photo capture delegate.
  /// path - the path for captured photo file.
  /// ioQueue - the queue on which captured photos are written to disk.
  /// completionHandler - The completion handler block for save photo operations. Can
  /// be called from either main queue or IO queue.
  init(
    path: String,
    ioQueue: DispatchQueue,
    fileSaveMode: PhotoFileSaveMode = .original,
    cropMode: PlatformPhotoCropMode = .none,
    compressionQuality: Double = 1.0,
    willCaptureHandler: SavePhotoDelegateWillCaptureHandler? = nil,
    completionHandler: @escaping SavePhotoDelegateCompletionHandler
  ) {
    self.path = path
    self.ioQueue = ioQueue
    self.fileSaveMode = fileSaveMode
    self.cropMode = cropMode
    self.compressionQuality = compressionQuality
    self.ciContext = CIContext()
    self.willCaptureHandler = willCaptureHandler
    self.completionHandler = completionHandler
    super.init()
  }

  /// Handler to write captured photo data into a file.
  /// - Parameters:
  ///   - error: The capture error
  ///   - photoDataProvider: A closure that provides photo data
  func handlePhotoCaptureResult(
    error: Error?,
    photoDataProvider: @escaping () throws -> WritableData?
  ) {
    if let error = error {
      completionHandler(nil, error)
      return
    }

    ioQueue.async { [weak self] in
      guard let strongSelf = self else { return }

      do {
        guard let data = try photoDataProvider() else {
          throw PhotoFileSaveError.missingPhotoData
        }

        try data.writeToPath(strongSelf.path, options: .atomic)
        strongSelf.completionHandler(strongSelf.path, nil)
      } catch {
        strongSelf.completionHandler(nil, error)
      }
    }
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
  ) {
    willCaptureHandler?()
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    switch fileSaveMode {
    case .original:
      handlePhotoCaptureResult(error: error) {
        photo.fileDataRepresentation()
      }
    case .sdrHeif:
      handlePhotoCaptureResult(error: error) { [weak self] in
        guard let strongSelf = self else { return nil }
        return try strongSelf.createSDRHeifData(from: photo)
      }
    }
  }

  private func createSDRHeifData(from photo: AVCapturePhoto) throws -> WritableData? {
    guard let cgImage = photo.cgImageRepresentation() else {
      throw PhotoFileSaveError.missingCGImageRepresentation
    }

    let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
    let ciImage = CIImage(cgImage: cgImage)
    let renderExtent: CGRect
    switch cropMode {
    case .none:
      renderExtent = ciImage.extent
    case .square:
      let side = floor(min(ciImage.extent.width, ciImage.extent.height))
      renderExtent = CGRect(
        x: floor(ciImage.extent.midX - side / 2),
        y: floor(ciImage.extent.midY - side / 2),
        width: side,
        height: side
      )
    }
    guard
      let sdrCGImage = ciContext.createCGImage(
        ciImage,
        from: renderExtent,
        format: .RGBA8,
        colorSpace: colorSpace
      )
    else {
      throw PhotoFileSaveError.failedToRenderSDRImage
    }

    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data,
        AVFileType.heic.rawValue as CFString,
        1,
        nil
      )
    else {
      throw PhotoFileSaveError.failedToCreateHEIFDestination
    }

    CGImageDestinationAddImage(
      destination,
      sdrCGImage,
      sdrHeifDestinationProperties(
        from: photo.metadata,
        colorSpace: colorSpace,
        pixelWidth: sdrCGImage.width,
        pixelHeight: sdrCGImage.height
      ) as CFDictionary)

    guard CGImageDestinationFinalize(destination) else {
      throw PhotoFileSaveError.failedToFinalizeHEIFDestination
    }

    return data as Data
  }

  private func sdrHeifDestinationProperties(
    from metadata: [String: Any],
    colorSpace: CGColorSpace,
    pixelWidth: Int,
    pixelHeight: Int
  ) -> [String: Any] {
    var properties: [String: Any] = [
      kCGImageDestinationLossyCompressionQuality as String: compressionQuality,
      kCGImagePropertyColorModel as String: kCGImagePropertyColorModelRGB,
      kCGImagePropertyProfileName as String: colorSpace.name as String? ?? "Display P3",
      kCGImagePropertyPixelWidth as String: pixelWidth,
      kCGImagePropertyPixelHeight as String: pixelHeight,
    ]

    for key in [
      kCGImagePropertyTIFFDictionary as String,
      kCGImagePropertyExifDictionary as String,
      kCGImagePropertyGPSDictionary as String,
    ] {
      if let value = metadata[key] {
        properties[key] = value
      }
    }

    if var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
      exif[kCGImagePropertyExifPixelXDimension as String] = pixelWidth
      exif[kCGImagePropertyExifPixelYDimension as String] = pixelHeight
      properties[kCGImagePropertyExifDictionary as String] = exif
    }

    properties[kCGImagePropertyOrientation as String] =
      metadata[
        kCGImagePropertyOrientation as String]

    return properties
  }
}

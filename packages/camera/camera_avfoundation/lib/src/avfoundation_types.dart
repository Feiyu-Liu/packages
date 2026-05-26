// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// The AVFoundation capture device type.
enum AVFoundationCaptureDeviceType {
  /// A built-in wide-angle camera.
  builtInWideAngleCamera,

  /// A built-in telephoto camera.
  builtInTelephotoCamera,

  /// A built-in ultra-wide camera.
  builtInUltraWideCamera,

  /// A built-in dual camera virtual device.
  builtInDualCamera,

  /// A built-in dual-wide camera virtual device.
  builtInDualWideCamera,

  /// A built-in triple camera virtual device.
  builtInTripleCamera,

  /// A built-in TrueDepth camera.
  builtInTrueDepthCamera,

  /// An unknown capture device type.
  unknown,
}

/// AVFoundation metadata for a physical camera device.
@immutable
class AVFoundationPhysicalCameraDevice {
  /// Creates a physical camera device description.
  const AVFoundationPhysicalCameraDevice({
    required this.id,
    required this.lensDirection,
    required this.lensType,
    required this.deviceType,
  });

  /// The unique AVFoundation device identifier.
  final String id;

  /// The direction the camera is facing.
  final CameraLensDirection lensDirection;

  /// The type of lens the camera has.
  final CameraLensType lensType;

  /// The AVFoundation capture device type.
  final AVFoundationCaptureDeviceType deviceType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AVFoundationPhysicalCameraDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          lensDirection == other.lensDirection &&
          lensType == other.lensType &&
          deviceType == other.deviceType;

  @override
  int get hashCode => Object.hash(id, lensDirection, lensType, deviceType);
}

/// AVFoundation metadata for a camera device.
@immutable
class AVFoundationCameraDevice {
  /// Creates a camera device description.
  const AVFoundationCameraDevice({
    required this.id,
    required this.lensDirection,
    required this.lensType,
    required this.deviceType,
    required this.isVirtualDevice,
    required this.constituentDevices,
  });

  /// The unique AVFoundation device identifier.
  final String id;

  /// The direction the camera is facing.
  final CameraLensDirection lensDirection;

  /// The type of lens the camera has.
  final CameraLensType lensType;

  /// The AVFoundation capture device type.
  final AVFoundationCaptureDeviceType deviceType;

  /// Whether this device is an AVFoundation virtual device.
  final bool isVirtualDevice;

  /// Physical devices that make up this virtual device.
  final List<AVFoundationPhysicalCameraDevice> constituentDevices;

  /// Converts this device into the description expected by [CameraController].
  CameraDescription toCameraDescription() {
    return CameraDescription(
      name: id,
      lensDirection: lensDirection,
      sensorOrientation: 90,
      lensType: lensType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AVFoundationCameraDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          lensDirection == other.lensDirection &&
          lensType == other.lensType &&
          deviceType == other.deviceType &&
          isVirtualDevice == other.isVirtualDevice &&
          listEquals(constituentDevices, other.constituentDevices);

  @override
  int get hashCode => Object.hash(
    id,
    lensDirection,
    lensType,
    deviceType,
    isVirtualDevice,
    Object.hashAll(constituentDevices),
  );
}

/// AVFoundation zoom capabilities for the active camera.
@immutable
class AVFoundationZoomCapabilities {
  /// Creates zoom capabilities.
  const AVFoundationZoomCapabilities({
    required this.minZoomFactor,
    required this.maxZoomFactor,
    required this.currentZoomFactor,
    required this.displayZoomFactorMultiplier,
    required this.virtualDeviceSwitchOverZoomFactors,
    required this.secondaryNativeResolutionZoomFactors,
    required this.isVirtualDevice,
    required this.constituentDevices,
  });

  /// The minimum supported raw `AVCaptureDevice.videoZoomFactor`.
  final double minZoomFactor;

  /// The maximum supported raw `AVCaptureDevice.videoZoomFactor`.
  final double maxZoomFactor;

  /// The current raw `AVCaptureDevice.videoZoomFactor`.
  final double currentZoomFactor;

  /// Multiplier for converting raw zoom to a display zoom factor.
  final double displayZoomFactorMultiplier;

  /// Raw zoom factors where a virtual device may switch physical lenses.
  final List<double> virtualDeviceSwitchOverZoomFactors;

  /// Raw zoom factors where the active format can use secondary native resolution modes.
  final List<double> secondaryNativeResolutionZoomFactors;

  /// Whether the active device is an AVFoundation virtual device.
  final bool isVirtualDevice;

  /// Physical devices that make up this virtual device.
  final List<AVFoundationPhysicalCameraDevice> constituentDevices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AVFoundationZoomCapabilities &&
          runtimeType == other.runtimeType &&
          minZoomFactor == other.minZoomFactor &&
          maxZoomFactor == other.maxZoomFactor &&
          currentZoomFactor == other.currentZoomFactor &&
          displayZoomFactorMultiplier == other.displayZoomFactorMultiplier &&
          listEquals(
            virtualDeviceSwitchOverZoomFactors,
            other.virtualDeviceSwitchOverZoomFactors,
          ) &&
          listEquals(
            secondaryNativeResolutionZoomFactors,
            other.secondaryNativeResolutionZoomFactors,
          ) &&
          isVirtualDevice == other.isVirtualDevice &&
          listEquals(constituentDevices, other.constituentDevices);

  @override
  int get hashCode => Object.hash(
    minZoomFactor,
    maxZoomFactor,
    currentZoomFactor,
    displayZoomFactorMultiplier,
    Object.hashAll(virtualDeviceSwitchOverZoomFactors),
    Object.hashAll(secondaryNativeResolutionZoomFactors),
    isVirtualDevice,
    Object.hashAll(constituentDevices),
  );
}

/// Event emitted when the current AVFoundation zoom factor changes.
@immutable
class AVFoundationZoomChangedEvent extends CameraEvent {
  /// Creates a zoom changed event.
  const AVFoundationZoomChangedEvent(
    super.cameraId,
    this.zoomFactor,
    this.isRamping,
  );

  /// The current raw `AVCaptureDevice.videoZoomFactor`.
  final double zoomFactor;

  /// Whether AVFoundation is currently ramping zoom.
  final bool isRamping;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AVFoundationZoomChangedEvent &&
          runtimeType == other.runtimeType &&
          cameraId == other.cameraId &&
          zoomFactor == other.zoomFactor &&
          isRamping == other.isRamping;

  @override
  int get hashCode => Object.hash(cameraId, zoomFactor, isRamping);
}

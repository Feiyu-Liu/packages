# camera\_avfoundation

The iOS implementation of [`camera`][1].

## Usage

This package is [endorsed][2], which means you can simply use `camera`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package to use any of its APIs directly, you
should add it to your `pubspec.yaml` as usual.

## AVFoundation zoom capabilities

`AVFoundationCamera.getZoomCapabilities` exposes raw AVFoundation zoom values
for the active camera. `maxZoomFactor` is the maximum supported
`AVCaptureDevice.videoZoomFactor`, which can be much higher than the system
Camera app's zoom UI.

Use `recommendedMaxZoomFactor` when you want a system-recommended UI range. On
iOS 18 and later, it is sourced from
`AVCaptureDevice.Format.systemRecommendedVideoZoomRange`. It is null when the
system does not provide a recommendation, so callers should fall back to
`maxZoomFactor`.

[1]: https://pub.dev/packages/camera
[2]: https://flutter.dev/to/endorsed-federated-plugin

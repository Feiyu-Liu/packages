// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import XCTest

@testable import camera_avfoundation

final class CameraZoomTests: XCTestCase {
  private func createCamera() -> (Camera, MockCaptureDevice) {
    let mockDevice = MockCaptureDevice()

    let configuration = CameraTestUtils.createTestCameraConfiguration()
    configuration.videoCaptureDeviceFactory = { _ in mockDevice }
    let camera = CameraTestUtils.createTestCamera(configuration)

    return (camera, mockDevice)
  }

  private func createCameraWithSession() -> (Camera, MockCaptureDevice, MockCaptureSession) {
    let mockDevice = MockCaptureDevice()
    let mockSession = MockCaptureSession()
    mockSession.canSetSessionPresetStub = { _ in true }

    let configuration = CameraTestUtils.createTestCameraConfiguration()
    configuration.videoCaptureDeviceFactory = { _ in mockDevice }
    configuration.videoCaptureSession = mockSession
    let camera = CameraTestUtils.createTestCamera(configuration)

    return (camera, mockDevice, mockSession)
  }

  func testStart_appliesDefaultStartupZoomBeforeSessionStartsForBackVirtualCamera() {
    let (camera, mockDevice, mockSession) = createCameraWithSession()

    mockDevice.position = .back
    mockDevice.isVirtualDevice = true
    mockDevice.minAvailableVideoZoomFactor = 0.5
    mockDevice.maxAvailableVideoZoomFactor = 10.0
    mockDevice.storedVideoZoomFactor = 1.0
    mockDevice.flutterDisplayVideoZoomFactorMultiplier = 0.5

    var events = [String]()
    mockDevice.setVideoZoomFactorStub = { zoom in
      XCTAssertEqual(zoom, 2.0)
      events.append("setZoom")
    }
    mockSession.startRunningStub = {
      events.append("startRunning")
    }

    camera.start()

    XCTAssertEqual(events, ["setZoom", "startRunning"])
    XCTAssertEqual(mockDevice.videoZoomFactor, 2.0)
  }

  func testStart_doesNotApplyDefaultStartupZoomForNonVirtualBackCamera() {
    let (camera, mockDevice, mockSession) = createCameraWithSession()

    mockDevice.position = .back
    mockDevice.isVirtualDevice = false
    mockDevice.minAvailableVideoZoomFactor = 0.5
    mockDevice.maxAvailableVideoZoomFactor = 10.0
    mockDevice.storedVideoZoomFactor = 1.0
    mockDevice.flutterDisplayVideoZoomFactorMultiplier = 0.5

    var setVideoZoomFactorCalled = false
    mockDevice.setVideoZoomFactorStub = { _ in
      setVideoZoomFactorCalled = true
    }
    var startRunningCalled = false
    mockSession.startRunningStub = {
      startRunningCalled = true
    }

    camera.start()

    XCTAssertFalse(setVideoZoomFactorCalled)
    XCTAssertTrue(startRunningCalled)
    XCTAssertEqual(mockDevice.videoZoomFactor, 1.0)
  }

  func testStart_doesNotApplyDefaultStartupZoomForFrontVirtualCamera() {
    let (camera, mockDevice, mockSession) = createCameraWithSession()

    mockDevice.position = .front
    mockDevice.isVirtualDevice = true
    mockDevice.minAvailableVideoZoomFactor = 0.5
    mockDevice.maxAvailableVideoZoomFactor = 10.0
    mockDevice.storedVideoZoomFactor = 1.0
    mockDevice.flutterDisplayVideoZoomFactorMultiplier = 0.5

    var setVideoZoomFactorCalled = false
    mockDevice.setVideoZoomFactorStub = { _ in
      setVideoZoomFactorCalled = true
    }
    var startRunningCalled = false
    mockSession.startRunningStub = {
      startRunningCalled = true
    }

    camera.start()

    XCTAssertFalse(setVideoZoomFactorCalled)
    XCTAssertTrue(startRunningCalled)
    XCTAssertEqual(mockDevice.videoZoomFactor, 1.0)
  }

  func testStart_clampsDefaultStartupZoomToAvailableRange() {
    let (camera, mockDevice, _) = createCameraWithSession()

    mockDevice.position = .back
    mockDevice.isVirtualDevice = true
    mockDevice.minAvailableVideoZoomFactor = 0.5
    mockDevice.maxAvailableVideoZoomFactor = 1.5
    mockDevice.storedVideoZoomFactor = 1.0
    mockDevice.flutterDisplayVideoZoomFactorMultiplier = 0.5

    var targetZoom: CGFloat?
    mockDevice.setVideoZoomFactorStub = { zoom in
      targetZoom = zoom
    }

    camera.start()

    XCTAssertEqual(targetZoom, 1.5)
    XCTAssertEqual(mockDevice.videoZoomFactor, 1.5)
  }

  func testStart_continuesStartingSessionWhenDefaultStartupZoomLockFails() {
    let (camera, mockDevice, mockSession) = createCameraWithSession()

    mockDevice.position = .back
    mockDevice.isVirtualDevice = true
    mockDevice.minAvailableVideoZoomFactor = 0.5
    mockDevice.maxAvailableVideoZoomFactor = 10.0
    mockDevice.storedVideoZoomFactor = 1.0
    mockDevice.flutterDisplayVideoZoomFactorMultiplier = 0.5
    mockDevice.lockForConfigurationStub = {
      throw NSError(domain: "test", code: 1)
    }

    var setVideoZoomFactorCalled = false
    mockDevice.setVideoZoomFactorStub = { _ in
      setVideoZoomFactorCalled = true
    }
    var startRunningCalled = false
    mockSession.startRunningStub = {
      startRunningCalled = true
    }

    camera.start()

    XCTAssertFalse(setVideoZoomFactorCalled)
    XCTAssertTrue(startRunningCalled)
    XCTAssertEqual(mockDevice.videoZoomFactor, 1.0)
  }

  func testSetZoomLevel_setVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    mockDevice.maxAvailableVideoZoomFactor = 2.0
    mockDevice.minAvailableVideoZoomFactor = 0.0

    let targetZoom = CGFloat(1.0)

    var setVideoZoomFactorCalled = false
    mockDevice.setVideoZoomFactorStub = { zoom in
      XCTAssertEqual(zoom, targetZoom)
      setVideoZoomFactorCalled = true
    }

    let expectation = expectation(description: "Call completed")

    camera.setZoomLevel(targetZoom) {
      result in
      let _ = self.assertSuccess(result)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)

    XCTAssertTrue(setVideoZoomFactorCalled)
  }

  func testSetZoomFactorAnimated_rampsVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    mockDevice.maxAvailableVideoZoomFactor = 5.0
    mockDevice.minAvailableVideoZoomFactor = 0.5

    let targetZoom = CGFloat(2.0)
    let targetRate = Float(5.0)

    var rampCalled = false
    mockDevice.rampToVideoZoomFactorStub = { zoom, rate in
      XCTAssertEqual(zoom, targetZoom)
      XCTAssertEqual(rate, targetRate)
      rampCalled = true
    }

    let expectation = expectation(description: "Call completed")

    camera.setZoomFactor(targetZoom, animated: true, rate: targetRate) { result in
      let _ = self.assertSuccess(result)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)

    XCTAssertTrue(rampCalled)
  }

  func testSetZoomFactorImmediate_cancelsRampAndSetsVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    mockDevice.maxAvailableVideoZoomFactor = 5.0
    mockDevice.minAvailableVideoZoomFactor = 0.5

    let targetZoom = CGFloat(2.0)

    var cancelRampCalled = false
    var setVideoZoomFactorCalled = false
    mockDevice.cancelVideoZoomRampStub = {
      cancelRampCalled = true
    }
    mockDevice.setVideoZoomFactorStub = { zoom in
      XCTAssertEqual(zoom, targetZoom)
      setVideoZoomFactorCalled = true
    }

    let expectation = expectation(description: "Call completed")

    camera.setZoomFactor(targetZoom, animated: false, rate: 0) { result in
      let _ = self.assertSuccess(result)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)

    XCTAssertTrue(cancelRampCalled)
    XCTAssertTrue(setVideoZoomFactorCalled)
  }

  func testSetZoomFactorAnimated_returnsErrorForInvalidRate() {
    let (camera, mockDevice) = createCamera()

    mockDevice.maxAvailableVideoZoomFactor = 5.0
    mockDevice.minAvailableVideoZoomFactor = 0.5

    let expectation = expectation(description: "Call completed")

    camera.setZoomFactor(2.0, animated: true, rate: 0) { result in
      switch result {
      case .failure(let error as PigeonError):
        XCTAssertEqual(error.code, "ZOOM_ERROR")
      default:
        XCTFail("Expected failure")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)
  }

  func testZoomCapabilities_returnsDeviceZoomMetadata() {
    let (camera, mockDevice) = createCamera()

    let wideAngleCamera = MockCaptureDevice()
    wideAngleCamera.uniqueID = "wide"
    wideAngleCamera.position = .back
    wideAngleCamera.deviceType = .builtInWideAngleCamera

    mockDevice.maxAvailableVideoZoomFactor = 10.0
    mockDevice.minAvailableVideoZoomFactor = 0.5
    mockDevice.storedVideoZoomFactor = 2.0
    mockDevice.flutterDisplayVideoZoomFactorMultiplier = 0.5
    mockDevice.virtualDeviceSwitchOverVideoZoomFactors = [1.0, 3.0]
    mockDevice.flutterSecondaryNativeResolutionZoomFactors = [2.0]
    mockDevice.isVirtualDevice = true
    mockDevice.flutterConstituentDevices = [wideAngleCamera]

    let capabilities = camera.zoomCapabilities

    XCTAssertEqual(capabilities.minZoomFactor, 0.5)
    XCTAssertEqual(capabilities.maxZoomFactor, 10.0)
    XCTAssertEqual(capabilities.currentZoomFactor, 2.0)
    XCTAssertEqual(capabilities.displayZoomFactorMultiplier, 0.5)
    XCTAssertEqual(capabilities.virtualDeviceSwitchOverZoomFactors, [1.0, 3.0])
    XCTAssertEqual(capabilities.secondaryNativeResolutionZoomFactors, [2.0])
    XCTAssertEqual(capabilities.isVirtualDevice, true)
    XCTAssertEqual(capabilities.constituentDevices.first?.name, "wide")
  }

  func testSetZoomLevel_returnsError_forZoomLevelBlowMinimum() {
    let (camera, mockDevice) = createCamera()

    // Allowed zoom range between 2.0 and 3.0
    mockDevice.maxAvailableVideoZoomFactor = 2.0
    mockDevice.minAvailableVideoZoomFactor = 3.0

    let expectation = expectation(description: "Call completed")

    camera.setZoomLevel(CGFloat(1.0)) { result in
      switch result {
      case .failure(let error as PigeonError):
        XCTAssertEqual(error.code, "ZOOM_ERROR")
      default:
        XCTFail("Expected failure")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)
  }

  func testSetZoomLevel_returnsError_forZoomLevelAboveMaximum() {
    let (camera, mockDevice) = createCamera()

    // Allowed zoom range between 0.0 and 1.0
    mockDevice.maxAvailableVideoZoomFactor = 0.0
    mockDevice.minAvailableVideoZoomFactor = 1.0

    let expectation = expectation(description: "Call completed")

    camera.setZoomLevel(CGFloat(2.0)) { result in
      switch result {
      case .failure(let error as PigeonError):
        XCTAssertEqual(error.code, "ZOOM_ERROR")
      default:
        XCTFail("Expected failure")
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30)
  }

  func testMaximumAvailableZoomFactor_returnsDeviceMaxAvailableVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    let targetZoom = CGFloat(1.0)

    mockDevice.maxAvailableVideoZoomFactor = CGFloat(targetZoom)

    XCTAssertEqual(camera.maximumAvailableZoomFactor, targetZoom)
  }

  func testMinimumAvailableZoomFactor_returnsDeviceMinAvailableVideoZoomFactor() {
    let (camera, mockDevice) = createCamera()

    let targetZoom = CGFloat(1.0)

    mockDevice.minAvailableVideoZoomFactor = CGFloat(targetZoom)

    XCTAssertEqual(camera.minimumAvailableZoomFactor, targetZoom)
  }
}

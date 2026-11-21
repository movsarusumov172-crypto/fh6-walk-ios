import ARKit
import Foundation
import simd
import UIKit

/// Runs ARKit world tracking and sends the phone pose to the PC every camera frame.
@MainActor
final class TrackingSession: NSObject, ObservableObject, ARSessionDelegate {
  @Published private(set) var isRunning = false
  @Published private(set) var statusText = "Остановлено"
  @Published private(set) var positionText = ""

  private let session = ARSession()
  private var sender: PoseSender?
  private var pin: UInt32 = 0
  private var sequence: UInt32 = 0
  private var lastStatusUpdate: TimeInterval = 0

  // The screen text changes a few times a second, not 60: enough to read, cheap to draw.
  private static let statusUpdateSeconds: TimeInterval = 0.25

  override init() {
    super.init()
    session.delegate = self
  }

  /// Starts tracking. Returns an error text, or nil on success.
  func start(host: String, port: UInt16, pin: UInt32) -> String? {
    guard ARWorldTrackingConfiguration.isSupported else {
      return "Этот iPhone не поддерживает ARKit."
    }
    guard
      let sender = PoseSender(
        host: host, port: port,
        onError: { [weak self] message in
          Task { @MainActor in self?.statusText = message }
        })
    else {
      return "Неверный порт: \(port)"
    }
    self.sender = sender
    self.pin = pin
    sequence = 0
    let configuration = ARWorldTrackingConfiguration()
    configuration.worldAlignment = .gravity
    session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    // Tracking stops when the screen locks, so the screen stays on while it runs.
    UIApplication.shared.isIdleTimerDisabled = true
    isRunning = true
    statusText = "Запуск…"
    return nil
  }

  func stop() {
    session.pause()
    sender?.stop()
    sender = nil
    UIApplication.shared.isIdleTimerDisabled = false
    isRunning = false
    statusText = "Остановлено"
    positionText = ""
  }

  nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
    let transform = frame.camera.transform
    let pose = PosePacket.Pose(
      position: SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z),
      orientation: simd_quatf(transform))
    let tracking = Self.tracking(from: frame.camera.trackingState)
    let time = frame.timestamp
    Task { @MainActor in
      self.send(pose: pose, tracking: tracking, time: time)
    }
  }

  nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
    let message = "Ошибка ARKit: \(error.localizedDescription)"
    Task { @MainActor in self.statusText = message }
  }

  private func send(pose: PosePacket.Pose, tracking: PosePacket.Tracking, time: TimeInterval) {
    guard let sender else {
      return
    }
    sequence &+= 1
    sender.send(
      PosePacket.encode(pin: pin, sequence: sequence, time: time, pose: pose, tracking: tracking))
    guard time - lastStatusUpdate >= Self.statusUpdateSeconds else {
      return
    }
    lastStatusUpdate = time
    statusText = Self.description(of: tracking)
    positionText = String(
      format: "x %.2f  y %.2f  z %.2f м", pose.position.x, pose.position.y, pose.position.z)
  }

  private nonisolated static func tracking(from state: ARCamera.TrackingState)
    -> PosePacket.Tracking
  {
    switch state {
    case .normal:
      return .normal
    case .limited:
      return .limited
    case .notAvailable:
      return .notAvailable
    }
  }

  private static func description(of tracking: PosePacket.Tracking) -> String {
    switch tracking {
    case .normal:
      return "Отслеживание работает"
    case .limited:
      return "Отслеживание ограничено: больше света, медленнее движения"
    case .notAvailable:
      return "Отслеживание недоступно"
    }
  }
}

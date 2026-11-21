import Foundation

/// Everything the screen asks for besides the phone pose: joystick, buttons and settings.
/// Settings are remembered between launches.
@MainActor
final class ControlState: ObservableObject {
  // Ranges of the settings sliders. The PC rejects values outside wider ones
  // (phone_cam/walk_packet.py), so these must stay inside them.
  static let scaleRange: ClosedRange<Double> = 0.5...10
  static let joystickSpeedRange: ClosedRange<Double> = 0.5...15
  static let smoothingRange: ClosedRange<Double> = 0...1
  static let turnSensitivityRange: ClosedRange<Double> = 0.5...3

  @Published var joystick = SIMD2<Float>(0, 0)
  @Published var isUpHeld = false
  @Published var isDownHeld = false
  @Published var isClutchHeld = false
  @Published private(set) var resetCount: UInt32 = 0

  @Published var scale: Double { didSet { save(scale, for: Keys.scale) } }
  @Published var joystickSpeed: Double { didSet { save(joystickSpeed, for: Keys.joystickSpeed) } }
  @Published var smoothing: Double { didSet { save(smoothing, for: Keys.smoothing) } }
  @Published var turnSensitivity: Double {
    didSet { save(turnSensitivity, for: Keys.turnSensitivity) }
  }
  @Published var lockHeight: Bool { didSet { save(lockHeight, for: Keys.lockHeight) } }
  @Published var noRoll: Bool { didSet { save(noRoll, for: Keys.noRoll) } }
  @Published var invertRoll: Bool { didSet { save(invertRoll, for: Keys.invertRoll) } }

  private enum Keys {
    static let scale = "scale"
    static let joystickSpeed = "joystickSpeed"
    static let smoothing = "smoothing"
    static let turnSensitivity = "turnSensitivity"
    static let lockHeight = "lockHeight"
    static let noRoll = "noRoll"
    static let invertRoll = "invertRoll"
  }

  init() {
    let defaults = UserDefaults.standard
    scale = Self.stored(defaults, Keys.scale, default: 1, in: Self.scaleRange)
    joystickSpeed = Self.stored(defaults, Keys.joystickSpeed, default: 2, in: Self.joystickSpeedRange)
    smoothing = Self.stored(defaults, Keys.smoothing, default: 0.2, in: Self.smoothingRange)
    turnSensitivity = Self.stored(
      defaults, Keys.turnSensitivity, default: 1, in: Self.turnSensitivityRange)
    lockHeight = defaults.bool(forKey: Keys.lockHeight)
    noRoll = defaults.bool(forKey: Keys.noRoll)
    invertRoll = defaults.bool(forKey: Keys.invertRoll)
  }

  /// "Сбросить": the PC takes the current phone and camera as the new starting point.
  func reset() {
    resetCount &+= 1
  }

  var packetControls: PosePacket.Controls {
    PosePacket.Controls(
      joystick: joystick,
      vertical: (isUpHeld ? 1 : 0) - (isDownHeld ? 1 : 0),
      scale: Float(scale),
      joystickSpeed: Float(joystickSpeed),
      smoothing: Float(smoothing),
      turnSensitivity: Float(turnSensitivity),
      resetCount: resetCount,
      isClutchHeld: isClutchHeld,
      lockHeight: lockHeight,
      noRoll: noRoll,
      invertRoll: invertRoll)
  }

  private func save(_ value: Any, for key: String) {
    UserDefaults.standard.set(value, forKey: key)
  }

  /// A stored number, or the default if nothing valid is stored.
  private static func stored(
    _ defaults: UserDefaults, _ key: String, default fallback: Double, in range: ClosedRange<Double>
  ) -> Double {
    guard let value = defaults.object(forKey: key) as? Double, range.contains(value) else {
      return fallback
    }
    return value
  }
}

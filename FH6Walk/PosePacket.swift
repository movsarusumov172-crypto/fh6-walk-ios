import Foundation
import simd

/// Phone pose and screen controls for the PC program (phone_cam/walk_packet.py reads it).
///
/// Little-endian, version 2, 92 bytes:
/// magic "FH6W", UInt32 version, UInt32 PIN, UInt32 sequence number, Float64 time in seconds,
/// Float32 x, y, z in meters (ARKit world: y is up), Float32 quaternion x, y, z, w,
/// UInt8 tracking quality, 3 zero bytes; then Float32 joystick x, joystick y, vertical,
/// step scale, joystick speed, smoothing, turn sensitivity; UInt32 reset counter,
/// UInt8 clutch held, UInt8 flags (1 lock height, 2 no roll, 4 invert roll), 2 zero bytes.
enum PosePacket {
  static let magic: [UInt8] = Array("FH6W".utf8)
  static let version: UInt32 = 2
  static let byteCount = 92

  enum Tracking: UInt8 {
    case notAvailable = 0
    case limited = 1
    case normal = 2
  }

  struct Pose {
    var position: SIMD3<Float>
    var orientation: simd_quatf
  }

  struct Controls {
    var joystick = SIMD2<Float>(0, 0)  // x to the right, y forward, each -1...1
    var vertical: Float = 0  // -1 down, 1 up
    var scale: Float = 1
    var joystickSpeed: Float = 2
    var smoothing: Float = 0
    var turnSensitivity: Float = 1
    var resetCount: UInt32 = 0
    var isClutchHeld = false
    var lockHeight = false
    var noRoll = false
    var invertRoll = false

    var flags: UInt8 {
      (lockHeight ? 1 : 0) | (noRoll ? 2 : 0) | (invertRoll ? 4 : 0)
    }
  }

  static func encode(
    pin: UInt32, sequence: UInt32, time: Double, pose: Pose, tracking: Tracking,
    controls: Controls
  ) -> Data {
    var data = Data(capacity: byteCount)
    data.append(contentsOf: magic)
    appendLittleEndian(version, to: &data)
    appendLittleEndian(pin, to: &data)
    appendLittleEndian(sequence, to: &data)
    appendLittleEndian(time.bitPattern, to: &data)
    let quaternion = pose.orientation.vector
    let poseFloats = [
      pose.position.x, pose.position.y, pose.position.z,
      quaternion.x, quaternion.y, quaternion.z, quaternion.w,
    ]
    for value in poseFloats {
      appendLittleEndian(value.bitPattern, to: &data)
    }
    data.append(tracking.rawValue)
    data.append(contentsOf: [0, 0, 0])
    let controlFloats = [
      controls.joystick.x, controls.joystick.y, controls.vertical,
      controls.scale, controls.joystickSpeed, controls.smoothing, controls.turnSensitivity,
    ]
    for value in controlFloats {
      appendLittleEndian(value.bitPattern, to: &data)
    }
    appendLittleEndian(controls.resetCount, to: &data)
    data.append(controls.isClutchHeld ? 1 : 0)
    data.append(controls.flags)
    data.append(contentsOf: [0, 0])
    return data
  }

  private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
  }
}

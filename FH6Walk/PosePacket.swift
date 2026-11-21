import Foundation
import simd

/// Phone pose for the PC program (phone_cam/walk_packet.py reads it).
///
/// Little-endian, 56 bytes:
/// magic "FH6W", UInt32 version, UInt32 PIN, UInt32 sequence number, Float64 time in seconds,
/// Float32 x, y, z in meters (ARKit world: y is up), Float32 quaternion x, y, z, w,
/// UInt8 tracking quality, 3 zero bytes.
enum PosePacket {
  static let magic: [UInt8] = Array("FH6W".utf8)
  static let version: UInt32 = 1
  static let byteCount = 56

  enum Tracking: UInt8 {
    case notAvailable = 0
    case limited = 1
    case normal = 2
  }

  struct Pose {
    var position: SIMD3<Float>
    var orientation: simd_quatf
  }

  static func encode(
    pin: UInt32, sequence: UInt32, time: Double, pose: Pose, tracking: Tracking
  ) -> Data {
    var data = Data(capacity: byteCount)
    data.append(contentsOf: magic)
    appendLittleEndian(version, to: &data)
    appendLittleEndian(pin, to: &data)
    appendLittleEndian(sequence, to: &data)
    appendLittleEndian(time.bitPattern, to: &data)
    let quaternion = pose.orientation.vector
    let floats = [
      pose.position.x, pose.position.y, pose.position.z,
      quaternion.x, quaternion.y, quaternion.z, quaternion.w,
    ]
    for value in floats {
      appendLittleEndian(value.bitPattern, to: &data)
    }
    data.append(tracking.rawValue)
    data.append(contentsOf: [0, 0, 0])
    return data
  }

  private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
  }
}

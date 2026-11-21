// Checks the packet bytes against the layout phone_cam/walk_packet.py expects.
// Built and run on macOS in CI: swiftc -parse-as-library FH6Walk/PosePacket.swift <this file>.

import Foundation
import simd

@main
struct PosePacketTests {
  static func main() {
    let pose = PosePacket.Pose(
      position: SIMD3<Float>(1.5, -0.25, 3.0),
      orientation: simd_quatf(ix: 0, iy: 0.6, iz: 0, r: 0.8))
    var controls = PosePacket.Controls()
    controls.joystick = SIMD2<Float>(0.5, -1)
    controls.vertical = 1
    controls.scale = 4
    controls.joystickSpeed = 2.5
    controls.smoothing = 0.25
    controls.turnSensitivity = 1.5
    controls.resetCount = 7
    controls.isClutchHeld = true
    controls.lockHeight = true
    controls.invertRoll = true
    let packet = PosePacket.encode(
      pin: 424_242, sequence: 7, time: 12.5, pose: pose, tracking: .normal, controls: controls)

    expect(packet.count == PosePacket.byteCount, "packet is \(PosePacket.byteCount) bytes")
    expect(Array(packet.prefix(4)) == Array("FH6W".utf8), "magic comes first")
    expect(readUInt32(packet, at: 4) == 2, "version")
    expect(readUInt32(packet, at: 8) == 424_242, "PIN")
    expect(readUInt32(packet, at: 12) == 7, "sequence")
    expect(Double(bitPattern: readUInt64(packet, at: 16)) == 12.5, "time")
    expect(readFloat(packet, at: 24) == 1.5, "x")
    expect(readFloat(packet, at: 28) == -0.25, "y")
    expect(readFloat(packet, at: 32) == 3.0, "z")
    expect(readFloat(packet, at: 36) == 0, "quaternion x")
    expect(readFloat(packet, at: 40) == 0.6, "quaternion y")
    expect(readFloat(packet, at: 44) == 0, "quaternion z")
    expect(readFloat(packet, at: 48) == 0.8, "quaternion w")
    expect(packet[52] == PosePacket.Tracking.normal.rawValue, "tracking byte")
    expect(Array(packet[53..<56]) == [0, 0, 0], "padding after tracking is zero")
    expect(readFloat(packet, at: 56) == 0.5, "joystick x")
    expect(readFloat(packet, at: 60) == -1, "joystick y")
    expect(readFloat(packet, at: 64) == 1, "vertical")
    expect(readFloat(packet, at: 68) == 4, "scale")
    expect(readFloat(packet, at: 72) == 2.5, "joystick speed")
    expect(readFloat(packet, at: 76) == 0.25, "smoothing")
    expect(readFloat(packet, at: 80) == 1.5, "turn sensitivity")
    expect(readUInt32(packet, at: 84) == 7, "reset counter")
    expect(packet[88] == 1, "clutch held")
    expect(packet[89] == 1 | 4, "flags: lock height and invert roll")
    expect(Array(packet.suffix(2)) == [0, 0], "final padding is zero")
    print("PosePacketTests: all checks passed")
  }

  static func expect(_ condition: Bool, _ description: String) {
    if !condition {
      print("FAIL: \(description)")
      exit(1)
    }
  }

  static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
    let bytes = data.subdata(in: offset..<offset + 4)
    return bytes.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
  }

  static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
    let bytes = data.subdata(in: offset..<offset + 8)
    return bytes.withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self)) }
  }

  static func readFloat(_ data: Data, at offset: Int) -> Float {
    Float(bitPattern: readUInt32(data, at: offset))
  }
}

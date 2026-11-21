import Foundation
import Network

/// Sends pose packets to the PC over UDP on the home network.
///
/// UDP on purpose: a late pose is useless, so nothing is resent or queued.
final class PoseSender {
  private let connection: NWConnection
  private let queue = DispatchQueue(label: "fh6walk.pose-sender")
  private var hasReportedError = false
  private let onError: (String) -> Void

  /// Returns nil if the port is not a valid UDP port.
  init?(host: String, port: UInt16, onError: @escaping (String) -> Void) {
    guard let udpPort = NWEndpoint.Port(rawValue: port) else {
      return nil
    }
    self.onError = onError
    connection = NWConnection(host: NWEndpoint.Host(host), port: udpPort, using: .udp)
    connection.start(queue: queue)
  }

  func send(_ packet: Data) {
    connection.send(
      content: packet,
      completion: .contentProcessed { [weak self] error in
        guard let self, let error, !self.hasReportedError else {
          return
        }
        // One message is enough: the same error would repeat 60 times a second.
        self.hasReportedError = true
        self.onError("Не удалось отправить данные на ПК: \(error.localizedDescription)")
      })
  }

  func stop() {
    connection.cancel()
  }
}

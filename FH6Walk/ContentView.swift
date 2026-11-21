import SwiftUI

struct ContentView: View {
  @StateObject private var tracking = TrackingSession()
  @AppStorage("pcAddress") private var pcAddress = ""
  @AppStorage("pin") private var pinText = ""
  @State private var errorText: String?

  // Must match WALK_PORT in phone_cam/walk.py.
  private static let pcPort: UInt16 = 5701
  private static let pinLength = 6

  var body: some View {
    NavigationStack {
      Form {
        Section("Компьютер") {
          TextField("IP-адрес ПК, например 192.168.0.57", text: $pcAddress)
            // Not .decimalPad: with a Russian locale it shows a comma instead of a dot.
            .keyboardType(.numbersAndPunctuation)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          TextField("PIN из окна программы на ПК", text: $pinText)
            .keyboardType(.numberPad)
        }
        .disabled(tracking.isRunning)

        Section {
          Button(action: toggleTracking) {
            Label(
              tracking.isRunning ? "Остановить" : "Начать",
              systemImage: tracking.isRunning ? "stop.circle" : "figure.walk")
          }
        }

        Section("Состояние") {
          Text(tracking.statusText)
          if !tracking.positionText.isEmpty {
            Text(tracking.positionText).monospacedDigit()
          }
          if let errorText {
            Text(errorText).foregroundStyle(.red)
          }
        }

        Section {
          Text(
            "Держите телефон камерой вперёд, как будто снимаете. "
              + "Пока программа на ПК включена, ваши шаги двигают персонажа или дрон в игре."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("FH6 Walk")
    }
  }

  private func toggleTracking() {
    if tracking.isRunning {
      tracking.stop()
      return
    }
    let address = pcAddress.trimmingCharacters(in: .whitespaces)
    guard !address.isEmpty else {
      errorText = "Введите IP-адрес ПК."
      return
    }
    guard pinText.count == Self.pinLength, let pin = UInt32(pinText) else {
      errorText = "PIN — это \(Self.pinLength) цифр из окна программы на ПК."
      return
    }
    errorText = tracking.start(host: address, port: Self.pcPort, pin: pin)
  }
}

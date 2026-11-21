import SwiftUI

struct ContentView: View {
  @StateObject private var controls: ControlState
  @StateObject private var tracking: TrackingSession
  @AppStorage("pcAddress") private var pcAddress = ""
  @AppStorage("pin") private var pinText = ""
  @State private var errorText: String?
  @State private var isShowingSettings = false

  // Must match WALK_PORT in phone_cam/walk.py.
  private static let pcPort: UInt16 = 5701
  private static let pinLength = 6

  init() {
    let controls = ControlState()
    _controls = StateObject(wrappedValue: controls)
    _tracking = StateObject(wrappedValue: TrackingSession(controls: controls))
  }

  var body: some View {
    NavigationStack {
      Group {
        if tracking.isRunning {
          controlPanel
        } else {
          setupForm
        }
      }
      .navigationTitle("FH6 Walk")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            isShowingSettings = true
          } label: {
            Image(systemName: "slider.horizontal.3")
          }
          .accessibilityLabel("Настройки")
        }
      }
      .sheet(isPresented: $isShowingSettings) {
        SettingsView(controls: controls)
      }
    }
  }

  private var setupForm: some View {
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

      Section {
        Button(action: start) {
          Label("Начать", systemImage: "figure.walk")
        }
        if let errorText {
          Text(errorText).foregroundStyle(.red)
        }
      }

      Section {
        Text(
          "Держите телефон камерой вперёд, как будто снимаете. Шаги, повороты и наклоны "
            + "телефона двигают камеру в игре. Комнаты мало — держите «Сцепление», "
            + "перейдите и отпустите, или идите джойстиком."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
    }
  }

  private var controlPanel: some View {
    VStack(spacing: 16) {
      VStack(spacing: 4) {
        Text(tracking.statusText).font(.subheadline)
        if !tracking.positionText.isEmpty {
          Text(tracking.positionText).font(.caption).monospacedDigit()
            .foregroundStyle(.secondary)
        }
      }

      HStack {
        Button {
          controls.reset()
        } label: {
          Label("Сбросить", systemImage: "scope")
        }
        Spacer()
        Button(role: .destructive) {
          tracking.stop()
        } label: {
          Label("Стоп", systemImage: "stop.circle")
        }
      }
      .buttonStyle(.bordered)

      HoldButton(
        title: "Сцепление: держите, перейдите, отпустите",
        systemImage: "hand.raised",
        isPressed: $controls.isClutchHeld)

      Spacer()

      HStack(alignment: .bottom) {
        JoystickView(value: $controls.joystick)
        Spacer()
        VStack(spacing: 12) {
          HoldButton(title: "Выше", systemImage: "arrow.up", isPressed: $controls.isUpHeld)
          HoldButton(title: "Ниже", systemImage: "arrow.down", isPressed: $controls.isDownHeld)
        }
        .frame(width: 130)
      }
    }
    .padding()
  }

  private func start() {
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

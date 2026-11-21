import SwiftUI

/// Round on-screen joystick. value: x to the right, y forward (up on screen), each -1...1;
/// back to zero when the finger lets go.
struct JoystickView: View {
  @Binding var value: SIMD2<Float>

  private let size: CGFloat = 170
  private let knobSize: CGFloat = 64

  var body: some View {
    let radius = (size - knobSize) / 2
    ZStack {
      Circle().fill(Color.secondary.opacity(0.15))
      Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 2)
      Circle()
        .fill(Color.accentColor)
        .frame(width: knobSize, height: knobSize)
        .offset(x: CGFloat(value.x) * radius, y: CGFloat(-value.y) * radius)
    }
    .frame(width: size, height: size)
    .contentShape(Circle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { drag in
          let dx = (drag.location.x - size / 2) / radius
          let dy = (drag.location.y - size / 2) / radius
          // Outside the circle the knob stays on its edge.
          let length = max(1, (dx * dx + dy * dy).squareRoot())
          value = SIMD2(Float(dx / length), Float(-dy / length))
        }
        .onEnded { _ in value = SIMD2(0, 0) }
    )
    .accessibilityLabel("Джойстик: идти вперёд, назад и вбок")
  }
}

/// A button that is "on" only while a finger is on it.
struct HoldButton: View {
  let title: String
  let systemImage: String
  @Binding var isPressed: Bool

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.headline)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity, minHeight: 64)
      .background(
        isPressed ? Color.accentColor : Color.secondary.opacity(0.2),
        in: RoundedRectangle(cornerRadius: 14)
      )
      .foregroundStyle(isPressed ? Color.white : Color.primary)
      .contentShape(RoundedRectangle(cornerRadius: 14))
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            if !isPressed {
              isPressed = true
            }
          }
          .onEnded { _ in isPressed = false }
      )
      .accessibilityAddTraits(.isButton)
  }
}

struct SettingsView: View {
  @ObservedObject var controls: ControlState
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledSlider(
            title: "Масштаб шагов",
            valueText: String(format: "1 м = %.1f м в игре", controls.scale),
            value: $controls.scale, range: ControlState.scaleRange, step: 0.5)
          LabeledSlider(
            title: "Скорость джойстика",
            valueText: String(format: "%.1f м/с", controls.joystickSpeed),
            value: $controls.joystickSpeed, range: ControlState.joystickSpeedRange, step: 0.5)
        } header: {
          Text("Движение")
        } footer: {
          Text("Если комнаты не хватает — увеличьте масштаб или держите «Сцепление».")
        }

        Section("Камера") {
          LabeledSlider(
            title: "Стабилизация",
            valueText: controls.smoothing == 0
              ? "выкл.: каждая дрожь рук" : String(format: "%.0f %%", controls.smoothing * 100),
            value: $controls.smoothing, range: ControlState.smoothingRange, step: 0.05)
          LabeledSlider(
            title: "Чувствительность поворота",
            valueText: String(format: "×%.1f", controls.turnSensitivity),
            value: $controls.turnSensitivity, range: ControlState.turnSensitivityRange, step: 0.1)
          Toggle("Закрепить высоту", isOn: $controls.lockHeight)
          Toggle("Без наклона вбок", isOn: $controls.noRoll)
          Toggle("Наклон вбок в обратную сторону", isOn: $controls.invertRoll)
        }
      }
      .navigationTitle("Настройки")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Готово") { dismiss() }
        }
      }
    }
  }
}

private struct LabeledSlider: View {
  let title: String
  let valueText: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(title)
        Spacer()
        Text(valueText).foregroundStyle(.secondary).monospacedDigit()
      }
      Slider(value: $value, in: range, step: step)
    }
  }
}

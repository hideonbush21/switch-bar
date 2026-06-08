import SwitchBarCore
import SwiftUI

struct ToggleRowView: View {
    @ObservedObject var toggle: AnyToggleProvider

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: toggle.iconName)
                .frame(width: 20, height: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toggle.title)
                            .font(.body)
                        if let subtitle = toggle.subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    control
                }

                if let errorMessage = toggle.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var control: some View {
        if toggle.controlType == .action {
            Button(action: {
                toggle.triggerAction()
            }) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(BorderlessButtonStyle())
        } else {
            Toggle("", isOn: Binding(
                get: { toggle.isOn },
                set: { newValue in
                    toggle.requestSet(newValue)
                }
            ))
            .labelsHidden()
            .disabled(toggle.isBusy)
        }
    }
}

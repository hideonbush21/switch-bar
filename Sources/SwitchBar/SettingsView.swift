import SwitchBarCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var registry: ToggleRegistry

    var body: some View {
        List {
            ForEach(registry.orderedToggles) { toggle in
                Toggle(isOn: Binding(
                    get: { registry.enabledIDs.contains(toggle.id) },
                    set: { registry.setEnabled($0, for: toggle.id) }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: toggle.iconName)
                            .frame(width: 18)
                        Text(toggle.title)
                    }
                }
            }
            .onMove(perform: registry.moveToggle)
        }
        .listStyle(PlainListStyle())
    }
}

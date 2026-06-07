import SwitchBarCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var registry: ToggleRegistry
    @State private var showsSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if showsSettings {
                SettingsView(registry: registry)
            } else {
                toggleList
            }

            Divider()

            Button(action: {
                showsSettings.toggle()
            }) {
                HStack {
                    Image(systemName: showsSettings ? "chevron.left" : "slider.horizontal.3")
                    Text(showsSettings ? "返回" : "设置")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 320, height: 360)
    }

    private var header: some View {
        HStack {
            Text(showsSettings ? "设置" : "SwitchBar")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var toggleList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(registry.visibleToggles) { toggle in
                    ToggleRowView(toggle: toggle)
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
    }
}

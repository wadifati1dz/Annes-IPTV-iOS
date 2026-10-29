import SwiftUI
import PhotosUI

/// Language, background picture, extra M3U playlists and a manual refresh.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    @State private var pickedPhoto: PhotosPickerItem?
    @State private var newPlaylist = ""

    var body: some View {
        Form {
            Section(header: Text("settings_language")) {
                Picker(selection: $store.languageCode) {
                    Text("language_system").tag("system")
                    Text("العربية").tag("ar")
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                } label: {
                    Text("settings_language")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section(header: Text("settings_background")) {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Label { Text("background_choose") } icon: { Image(systemName: "photo") }
                }
                Button {
                    store.setBackground(data: nil)
                } label: {
                    Label { Text("background_reset") } icon: { Image(systemName: "arrow.uturn.backward") }
                }
            }

            Section(header: Text("settings_playlists")) {
                ForEach(store.extraPlaylists, id: \.self) { url in
                    Text(url).font(.footnote).lineLimit(1)
                }
                .onDelete { offsets in store.extraPlaylists.remove(atOffsets: offsets) }
                HStack {
                    TextField(LocalizedStringKey("playlist_url_hint"), text: $newPlaylist)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button {
                        let value = newPlaylist.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard value.lowercased().hasPrefix("http"), !store.extraPlaylists.contains(value) else { return }
                        store.extraPlaylists.append(value)
                        newPlaylist = ""
                        store.refresh()
                    } label: {
                        Text("add")
                    }
                }
                Button {
                    store.refresh()
                } label: {
                    Label { Text("refresh") } icon: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(Text("nav_settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickedPhoto) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { store.setBackground(data: data) }
                }
            }
        }
    }
}

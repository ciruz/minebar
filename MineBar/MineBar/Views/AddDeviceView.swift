import SwiftUI

struct AddDeviceView: View {
    @Bindable var store: MinerStore

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Add Device")
                    .font(.caption.bold())
                Spacer()
                Button("Cancel") {
                    store.isAddingDevice = false
                    store.newDeviceName = ""
                    store.newDeviceIP = ""
                    store.newDeviceType = .bitaxe
                }
                .font(.caption)
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundStyle(.secondary)
            }

            Picker("Type", selection: $store.newDeviceType) {
                ForEach(MinerType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("Name (e.g. Bitaxe #1)", text: $store.newDeviceName)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            TextField("IP Address (e.g. 192.168.1.100)", text: $store.newDeviceIP)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit { store.addDevice() }

            Button("Add") {
                store.addDevice()
            }
            .disabled(store.newDeviceName.trimmingCharacters(in: .whitespaces).isEmpty ||
                store.newDeviceIP.trimmingCharacters(in: .whitespaces).isEmpty)
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct EditDeviceView: View {
    @Bindable var store: MinerStore

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Edit Device")
                    .font(.caption.bold())
                Spacer()
                Button("Cancel") { store.cancelEdit() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .focusable(false)
                    .foregroundStyle(.secondary)
            }

            Picker("Type", selection: $store.editType) {
                ForEach(MinerType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("Name", text: $store.editName)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            TextField("IP Address", text: $store.editIP)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit { store.saveEdit() }

            Button("Save") {
                store.saveEdit()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

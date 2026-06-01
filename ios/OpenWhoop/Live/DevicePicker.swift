import SwiftUI

struct DevicePicker: View {

    @EnvironmentObject private var model: LiveViewModel
    @EnvironmentObject private var state: LiveState
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                if state.isScanning && state.discoveredDevices.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("A procurar dispositivos WHOOP…")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                ForEach(state.discoveredDevices) { device in
                    Button {
                        model.connectDevice(device)
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.peripheral.identifier.uuidString)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: rssiIcon(device.rssi))
                                Text("\(device.rssi) dBm")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Ligar dispositivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        model.disconnect()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if state.isScanning {
                        ProgressView()
                    } else {
                        Button("Procurar") { model.connect() }
                    }
                }
            }
        }
    }

    private func rssiIcon(_ rssi: Int) -> String {
        switch rssi {
        case _ where rssi >= -60: return "wifi"
        case _ where rssi >= -75: return "wifi"
        default:                  return "wifi.slash"
        }
    }
}

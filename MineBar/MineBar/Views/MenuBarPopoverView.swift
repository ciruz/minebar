import Sparkle
import SwiftUI

struct MenuBarPopoverView: View {
    var store: MinerStore
    var updater: SPUUpdater

    var body: some View {
        VStack(spacing: 0) {
            SummaryView(
                totalHashrate: store.totalHashrate,
                totalPower: store.totalPower,
                efficiency: store.efficiency,
                onlineCount: store.onlineCount,
                totalCount: store.miners.count
            )

            Divider()

            // Scan status bar, always in view tree, collapses when empty
            scanStatusBar

            ScrollView {
                VStack(spacing: 0) {
                    if store.miners.isEmpty, !store.isScanning, store.scanStatus.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No devices configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Add a device or scan your network")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }

                    ForEach(store.miners) { miner in
                        MinerRowView(
                            miner: miner,
                            isExpanded: store.expandedDeviceID == miner.id,
                            isRestartConfirm: store.restartConfirmDeviceID == miner.id,
                            onToggleExpand: { store.toggleExpanded(miner.id) },
                            onOpenWebUI: { store.openWebUI(ip: miner.device.ip) },
                            onRestartTap: { store.restartConfirmDeviceID = miner.id },
                            onRestartConfirm: { store.restartDevice(miner) },
                            onRestartCancel: { store.restartConfirmDeviceID = nil },
                            onEdit: { store.beginEdit(miner.device) },
                            onDelete: { store.removeDevice(miner) }
                        )
                        Divider()
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: 700)

            // Inline forms, always in view tree, collapse when hidden
            Divider()
                .opacity(store.editingDevice != nil ? 1 : 0)
                .frame(height: store.editingDevice != nil ? nil : 0)
            EditDeviceView(store: store)
                .frame(height: store.editingDevice != nil ? nil : 0)
                .clipped()
                .opacity(store.editingDevice != nil ? 1 : 0)

            Divider()
                .opacity(store.isAddingDevice ? 1 : 0)
                .frame(height: store.isAddingDevice ? nil : 0)
            AddDeviceView(store: store)
                .frame(height: store.isAddingDevice ? nil : 0)
                .clipped()
                .opacity(store.isAddingDevice ? 1 : 0)

            Divider()

            VStack(spacing: 1) {
                MenuFooterButton(title: "Add Device...", icon: "plus") {
                    store.isAddingDevice.toggle()
                }

                MenuFooterButton(title: "Scan Network", icon: "antenna.radiowaves.left.and.right") {
                    store.rescan()
                }

                Divider()
                    .padding(.vertical, 2)

                MenuFooterButton(title: "Settings...", icon: "gearshape") {
                    WindowManager.shared.openSettings()
                }

                MenuFooterButton(title: "Check for Updates...", icon: "arrow.triangle.2.circlepath") {
                    updater.checkForUpdates()
                }

                Divider()
                    .padding(.vertical, 2)

                MenuFooterButton(title: "Quit", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 440)
        .background(PopoverMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var scanStatusBar: some View {
        HStack(spacing: 6) {
            if store.isScanning {
                ProgressView()
                    .controlSize(.small)
            }
            Text(store.scanStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, store.scanStatus.isEmpty ? 0 : 6)
        .frame(height: store.scanStatus.isEmpty ? 0 : nil)
        .clipped()
    }
}

private struct PopoverMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct MenuFooterButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(title)
                Spacer()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isHovering ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

import SwiftUI

struct MinerRowView: View {
    let miner: Miner
    let isExpanded: Bool
    let isRestartConfirm: Bool
    let onToggleExpand: () -> Void
    let onOpenWebUI: () -> Void
    let onRestartTap: () -> Void
    let onRestartConfirm: () -> Void
    let onRestartCancel: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleExpand) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(miner.isOnline ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(miner.device.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)

                    Text(miner.device.type.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(badgeBackground(miner.device.type))
                        .foregroundStyle(badgeForeground(miner.device.type))
                        .cornerRadius(3)

                    Spacer()

                    if miner.isOnline, let info = miner.info {
                        Text(SystemInfo.formatHashrate(info.hashRate ?? 0))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)

                        if let temp = info.temp {
                            Text(String(format: "%.0f°C", temp))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(tempColor(temp))
                        }

                        if let power = info.power {
                            Text(String(format: "%.1fW", power))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                        }

                        // Best Diff (all-time tracked)
                        Text(miner.formattedAllTimeBestDiff)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color(red: 0.8, green: 0.4, blue: 0.0))
                    } else {
                        Text("offline")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)

            if isExpanded {
                DetailView(
                    miner: miner,
                    isRestartConfirm: isRestartConfirm,
                    onOpenWebUI: onOpenWebUI,
                    onRestartTap: onRestartTap,
                    onRestartConfirm: onRestartConfirm,
                    onRestartCancel: onRestartCancel,
                    onEdit: onEdit,
                    onDelete: onDelete
                )
            }
        }
    }

    private func badgeBackground(_ type: MinerType) -> Color {
        switch type {
        case .bitaxe: return Color(red: 0.827, green: 0.008, blue: 0.106).opacity(0.25) // #D3021B
        case .nerdaxe: return Color(red: 0.667, green: 1.0, blue: 0.0).opacity(0.25) // #AAFF00
        case .avalon: return Color(red: 0.169, green: 0.424, blue: 0.69).opacity(0.25) // #2B6CB0
        }
    }

    private func badgeForeground(_ type: MinerType) -> Color {
        switch type {
        case .bitaxe: return Color(red: 0.827, green: 0.008, blue: 0.106) // #D3021B
        case .nerdaxe: return Color(red: 0.5, green: 0.78, blue: 0.0) // #AAFF00 darkened for readability
        case .avalon: return Color(red: 0.169, green: 0.424, blue: 0.69) // #2B6CB0
        }
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp < 55 { return Color(red: 0.0, green: 0.55, blue: 0.2) }
        if temp < 70 { return Color(red: 0.7, green: 0.5, blue: 0.0) }
        return Color(red: 0.85, green: 0.15, blue: 0.1)
    }
}

private struct DetailView: View {
    let miner: Miner
    let isRestartConfirm: Bool
    let onOpenWebUI: () -> Void
    let onRestartTap: () -> Void
    let onRestartConfirm: () -> Void
    let onRestartCancel: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if miner.isOnline, let info = miner.info {
                let fields = buildFields(info: info, ip: miner.device.ip)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], alignment: .leading, spacing: 6) {
                    ForEach(fields, id: \.label) { field in
                        DetailField(label: field.label, value: field.value)
                    }
                }

                if let stratumURL = info.stratumURL, let stratumPort = info.stratumPort {
                    DetailField(label: "Pool", value: "\(stratumURL):\(stratumPort)")
                }
                if let stratumUser = info.stratumUser {
                    DetailField(label: "Worker", value: stratumUser)
                        .textSelection(.enabled)
                }
            } else {
                Text("Device is offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DetailField(label: "IP", value: miner.device.ip)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: onOpenWebUI) {
                    Label("Web UI", systemImage: "safari")
                        .font(.caption)
                }

                if isRestartConfirm {
                    Button("Cancel", role: .cancel, action: onRestartCancel)
                        .font(.caption)
                    Button("Confirm Restart", role: .destructive, action: onRestartConfirm)
                        .font(.caption)
                } else {
                    Button(action: onRestartTap) {
                        Label("Restart", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }

                Spacer()

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Remove", systemImage: "trash")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .padding(.top, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func buildFields(info: SystemInfo, ip: String) -> [(label: String, value: String)] {
        var fields: [(label: String, value: String)] = []

        fields.append(("IP", ip))
        if let hostname = info.hostname { fields.append(("Hostname", hostname)) }

        fields.append(("Hashrate", SystemInfo.formatHashrate(info.hashRate ?? 0)))

        if let temp = info.temp { fields.append(("Temp", String(format: "%.1f °C", temp))) }
        if let power = info.power { fields.append(("Power", String(format: "%.1f W", power))) }
        if let voltage = info.voltage { fields.append(("Input V", String(format: "%.2f V", voltage / 1000))) }

        if let cv = info.coreVoltage, let cva = info.coreVoltageActual {
            fields.append(("Core mV", String(format: "%d / %d", Int(round(cv)), Int(round(cva)))))
        }
        if let freq = info.frequency { fields.append(("Frequency", String(format: "%d MHz", Int(freq)))) }

        if let rpm = info.fanrpm {
            let pct = info.fanspeed.map { " (\($0)%)" } ?? ""
            fields.append(("Fan", "\(rpm) RPM\(pct)"))
        }
        if let vrTemp = info.vrTemp { fields.append(("ASIC Temp", String(format: "%.0f °C", vrTemp))) }

        // Use all-time best diff instead of per-boot value
        fields.append(("Best Diff", miner.formattedAllTimeBestDiff))
        if info.bestSessionDiff != nil { fields.append(("Session Diff", info.formattedSessionDiff)) }

        if let accepted = info.sharesAccepted {
            let rejected = info.sharesRejected ?? 0
            fields.append(("Shares", "\(accepted) ✓  \(rejected) ✗"))
        }
        if info.uptimeSeconds != nil { fields.append(("Uptime", info.formattedUptime)) }
        if let asic = info.ASICModel { fields.append(("ASIC", asic)) }
        if let version = info.version { fields.append(("Version", version)) }

        if let wifiStatus = info.wifiStatus {
            let rssi = info.wifiRSSI.map { " (\($0) dBm)" } ?? ""
            fields.append(("WiFi", "\(wifiStatus)\(rssi)"))
        }
        if let board = info.boardVersion { fields.append(("Board", board)) }

        return fields
    }
}

private struct DetailField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

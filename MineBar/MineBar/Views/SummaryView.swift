import SwiftUI

struct SummaryView: View {
    let totalHashrate: Double
    let totalPower: Double
    let efficiency: Double
    let onlineCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("MineBar")
                    .font(.headline)
                Spacer()
                Text("\(onlineCount)/\(totalCount) online")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                StatBadge(label: "Hashrate", value: SystemInfo.formatHashrate(totalHashrate))
                StatBadge(label: "Power", value: String(format: "%.1f W", totalPower))
                StatBadge(label: "Efficiency", value: efficiency > 0 ? String(format: "%.1f J/TH", efficiency) : "-")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 80)
        .background(.ultraThinMaterial)
    }
}

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .monospaced, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

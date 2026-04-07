import CoreImage.CIFilterBuiltins
import Sparkle
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case notifications = "Notifications"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .notifications: return "bell"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    var settings = SettingsStore.shared
    var updater: SPUUpdater
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    TabButton(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(settings: settings, updater: updater)
                case .notifications:
                    NotificationSettingsTab(settings: settings)
                case .about:
                    AboutSettingsTab()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 360, height: 420)
    }
}

private struct TabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) :
                        isHovering ? Color.primary.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct GeneralSettingsTab: View {
    @Bindable var settings: SettingsStore
    var updater: SPUUpdater

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
            } header: {
                Text("Startup")
            }

            Section {
                Picker("Polling Interval", selection: $settings.pollingInterval) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("60 seconds").tag(60.0)
                }
            } header: {
                Text("Monitoring")
            }
        }
        .formStyle(.grouped)
    }
}

struct NotificationSettingsTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Device Offline", isOn: $settings.notifyDeviceOffline)
                Toggle("Hashrate Drop", isOn: $settings.notifyHashrateDrop)
            } header: {
                Text("Alerts")
            }

            Section {
                Toggle("Temperature Warning", isOn: $settings.notifyTemperatureWarning)
                if settings.notifyTemperatureWarning {
                    HStack {
                        Text("Threshold")
                        Spacer()
                        Text("\(Int(settings.temperatureThreshold))°C")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.temperatureThreshold, in: 50 ... 100, step: 5)
                }
            } header: {
                Text("Temperature")
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettingsTab: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 2) {
                Text("MineBar")
                    .font(.title3.bold())

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Solo mining, simplified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Link("Website", destination: URL(string: "https://minebar.app")!)
                Link("GitHub", destination: URL(string: "https://github.com/ciruz/minebar")!)
            }
            .font(.callout)

            Divider()
                .padding(.horizontal, 40)

            DonationView()

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

private struct DonationView: View {
    private static let btcAddress = "bc1qfvmlkev4hp3m30r42yyklln7lwhc6kfv3lqu2c"

    @State private var copied = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Support Development")
                .font(.callout.bold())

            if let qrImage = Self.generateQRCode(from: "bitcoin:\(Self.btcAddress)") {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 100, height: 100)
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(Self.btcAddress, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                HStack(spacing: 4) {
                    Text(Self.btcAddress)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .frame(width: 12, height: 12)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Copy BTC address")
        }
    }

    private static func generateQRCode(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

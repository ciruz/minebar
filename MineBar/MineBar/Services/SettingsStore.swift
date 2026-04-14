import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    var pollingInterval: Double {
        didSet { UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval") }
    }

    // MARK: - Status Bar Display

    var showHashrateInBar: Bool {
        didSet { UserDefaults.standard.set(showHashrateInBar, forKey: "showHashrateInBar") }
    }

    var showPowerInBar: Bool {
        didSet { UserDefaults.standard.set(showPowerInBar, forKey: "showPowerInBar") }
    }

    // MARK: - Notification Settings

    var notifyDeviceOffline: Bool {
        didSet { UserDefaults.standard.set(notifyDeviceOffline, forKey: "notifyDeviceOffline") }
    }

    var notifyHashrateDrop: Bool {
        didSet { UserDefaults.standard.set(notifyHashrateDrop, forKey: "notifyHashrateDrop") }
    }

    var notifyTemperatureWarning: Bool {
        didSet { UserDefaults.standard.set(notifyTemperatureWarning, forKey: "notifyTemperatureWarning") }
    }

    var temperatureThreshold: Double {
        didSet { UserDefaults.standard.set(temperatureThreshold, forKey: "temperatureThreshold") }
    }

    private init() {
        UserDefaults.standard.register(defaults: [
            "launchAtLogin": false,
            "pollingInterval": 10.0,
            "showHashrateInBar": true,
            "showPowerInBar": true,
            "notifyDeviceOffline": true,
            "notifyHashrateDrop": true,
            "notifyTemperatureWarning": true,
            "temperatureThreshold": 70.0
        ])
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        pollingInterval = UserDefaults.standard.double(forKey: "pollingInterval")
        showHashrateInBar = UserDefaults.standard.bool(forKey: "showHashrateInBar")
        showPowerInBar = UserDefaults.standard.bool(forKey: "showPowerInBar")
        notifyDeviceOffline = UserDefaults.standard.bool(forKey: "notifyDeviceOffline")
        notifyHashrateDrop = UserDefaults.standard.bool(forKey: "notifyHashrateDrop")
        notifyTemperatureWarning = UserDefaults.standard.bool(forKey: "notifyTemperatureWarning")
        temperatureThreshold = UserDefaults.standard.double(forKey: "temperatureThreshold")
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }
}

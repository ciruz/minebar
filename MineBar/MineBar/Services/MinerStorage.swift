import Foundation

enum MinerStorage {
    private static let key = "bitaxe_devices"

    static func load() -> [DeviceConfig] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([DeviceConfig].self, from: data)) ?? []
    }

    static func save(_ devices: [DeviceConfig]) {
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

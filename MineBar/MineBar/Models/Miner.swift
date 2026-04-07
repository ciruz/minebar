import Foundation

enum MinerType: String, Codable, CaseIterable {
    case bitaxe
    case nerdaxe
    case avalon

    var displayName: String {
        switch self {
        case .bitaxe: return "BitAxe"
        case .nerdaxe: return "NerdAxe"
        case .avalon: return "Avalon"
        }
    }
}

struct Miner: Identifiable, Codable, Equatable {
    var id: String {
        device.id
    }

    let device: DeviceConfig
    let info: SystemInfo?
    let isOnline: Bool
    let allTimeBestDiff: Double?

    init(device: DeviceConfig, info: SystemInfo? = nil, isOnline: Bool = false, allTimeBestDiff: Double? = nil) {
        self.device = device
        self.info = info
        self.isOnline = isOnline
        self.allTimeBestDiff = allTimeBestDiff
    }

    var formattedAllTimeBestDiff: String {
        guard let diff = allTimeBestDiff else { return "-" }
        return SystemInfo.formatDifficulty(diff)
    }
}

struct DeviceConfig: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var ip: String
    var type: MinerType

    init(id: String = UUID().uuidString, name: String, ip: String, type: MinerType = .bitaxe) {
        self.id = id
        self.name = name
        self.ip = ip
        self.type = type
    }

    // Decode legacy devices that don't have a type field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ip = try container.decode(String.self, forKey: .ip)
        type = try container.decodeIfPresent(MinerType.self, forKey: .type) ?? .bitaxe
    }
}

struct SystemInfo: Codable, Equatable {
    // Core metrics
    let hashRate: Double?
    let hashRate_1m: Double?
    let hashRate_10m: Double?
    let hashRate_1h: Double?
    let expectedHashrate: Double?
    let temp: Double?
    let vrTemp: Double?
    let power: Double?
    let voltage: Double?
    let current: Double?
    let coreVoltage: Double?
    let coreVoltageActual: Double?
    let frequency: Double?
    let fanrpm: Int?
    let fanspeed: Int?

    // Difficulty
    let bestDiff: Double?
    let bestSessionDiff: Double?
    let poolDifficulty: Double?

    // Pool
    let sharesAccepted: Int?
    let sharesRejected: Int?

    // Network
    let hostname: String?
    let ssid: String?
    let ipv4: String?
    let wifiStatus: String?
    let wifiRSSI: Int?

    // Device info
    let version: String?
    let ASICModel: String?
    let boardVersion: String?
    let uptimeSeconds: Int?
    let smallCoreCount: Int?

    // Stratum
    let stratumURL: String?
    let stratumPort: Int?
    let stratumUser: String?

    // MARK: - Computed

    var formattedUptime: String {
        guard let uptime = uptimeSeconds else { return "-" }
        let days = uptime / 86400
        let hours = (uptime % 86400) / 3600
        let minutes = (uptime % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedBestDiff: String {
        guard let diff = bestDiff else { return "-" }
        return Self.formatDifficulty(diff)
    }

    var formattedSessionDiff: String {
        guard let diff = bestSessionDiff else { return "-" }
        return Self.formatDifficulty(diff)
    }

    // Format GH/s with auto-scaling (GH/s, TH/s, PH/s)
    static func formatHashrate(_ ghps: Double) -> String {
        if ghps >= 1_000_000 {
            return String(format: "%.2f PH/s", ghps / 1_000_000)
        } else if ghps >= 1000 {
            return String(format: "%.2f TH/s", ghps / 1000)
        } else {
            return String(format: "%.1f GH/s", ghps)
        }
    }

    static func formatDifficulty(_ diff: Double) -> String {
        if diff >= 1_000_000_000_000 {
            return String(format: "%.2f T", diff / 1_000_000_000_000)
        } else if diff >= 1_000_000_000 {
            return String(format: "%.2f G", diff / 1_000_000_000)
        } else if diff >= 1_000_000 {
            return String(format: "%.2f M", diff / 1_000_000)
        } else if diff >= 1000 {
            return String(format: "%.2f K", diff / 1000)
        } else {
            return String(format: "%.0f", diff)
        }
    }
}

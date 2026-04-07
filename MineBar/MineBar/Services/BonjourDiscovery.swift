import Foundation

struct DiscoveredDevice: Identifiable, Equatable {
    let id = UUID().uuidString
    let hostname: String
    let ip: String
    let hashRate: Double
    let type: MinerType

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.ip == rhs.ip
    }
}

actor NetworkScanner {
    private let minerAPI = MinerAPIService(timeout: 3)
    private let avalonAPI = AvalonAPIService(timeout: 3)

    func scan(
        localIP: String,
        onFound: @escaping @Sendable (DiscoveredDevice) -> Void,
        onProgress: @escaping @Sendable (Int, Int) -> Void
    ) async {
        let parts = localIP.split(separator: ".").map(String.init)
        guard parts.count == 4, let base = parts.dropLast().joined(separator: ".") as String? else { return }

        let ips = (1 ... 254).map { "\(base).\($0)" }
        let total = ips.count
        var checked = 0

        await withTaskGroup(of: Void.self) { group in
            var running = 0
            for ip in ips {
                if running >= 32 {
                    await group.next()
                    running -= 1
                }
                running += 1
                group.addTask { [minerAPI, avalonAPI] in
                    // Try both APIs
                    async let minerResult = minerAPI.fetchSystemInfo(ip: ip)
                    async let avalonResult = avalonAPI.probe(ip: ip)

                    let minerInfo = await minerResult
                    let avalonModel = await avalonResult

                    if let info = minerInfo {
                        let isNerd = [info.hostname, info.boardVersion]
                            .compactMap { $0?.lowercased() }
                            .contains { $0.contains("nerd") }
                        let device = DiscoveredDevice(
                            hostname: info.hostname ?? ip,
                            ip: ip,
                            hashRate: info.hashRate ?? 0,
                            type: isNerd ? .nerdaxe : .bitaxe
                        )
                        onFound(device)
                    } else if let model = avalonModel {
                        let device = DiscoveredDevice(
                            hostname: model,
                            ip: ip,
                            hashRate: 0,
                            type: .avalon
                        )
                        onFound(device)
                    }

                    let current = checked + 1
                    onProgress(current, total)
                }
                checked += 1
            }
            for await _ in group {}
        }
    }
}

func getLocalIPAddress() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let addr = ptr.pointee
        guard addr.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

        let name = String(cString: addr.ifa_name)
        guard name.hasPrefix("en") else { continue }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(
            addr.ifa_addr,
            socklen_t(addr.ifa_addr.pointee.sa_len),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 {
            let ip = String(cString: hostname)
            if ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
                return ip
            }
        }
    }
    return nil
}

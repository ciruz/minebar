import Foundation

actor AvalonAPIService {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    func fetchSystemInfo(ip: String) async -> SystemInfo? {
        let t = timeout
        // Send commands sequentially (CGMiner API is single-threaded)
        guard let summaryRaw = await Self.tcpCommand("summary", ip: ip, timeout: t) else { return nil }
        let estatsRaw = await Self.tcpCommand("estats", ip: ip, timeout: t)
        let poolsRaw = await Self.tcpCommand("pools", ip: ip, timeout: t)
        let versionRaw = await Self.tcpCommand("version", ip: ip, timeout: t)

        return Self.mapToSystemInfo(
            summary: Self.parseFields(summaryRaw),
            estats: Self.parseFields(estatsRaw ?? ""),
            pools: Self.parseFields(poolsRaw ?? ""),
            version: Self.parseFields(versionRaw ?? "")
        )
    }

    func probe(ip: String) async -> String? {
        let t = timeout
        guard let raw = await Self.tcpCommand("version", ip: ip, timeout: t) else { return nil }
        let fields = Self.parseFields(raw)
        if let prod = fields["PROD"] {
            return prod
        }
        if fields["CGMiner"] != nil {
            return "CGMiner Device"
        }
        return nil
    }

    func restartDevice(ip: String) async -> Bool {
        let t = timeout
        return await Self.tcpCommand("ascset|0,reboot,0", ip: ip, timeout: t) != nil
    }

    // MARK: - TCP Communication

    private static func tcpCommand(_ command: String, ip: String, port: UInt16 = 4028, timeout: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = tcpCommandSync(command, ip: ip, port: port, timeout: timeout)
                continuation.resume(returning: result)
            }
        }
    }

    private static func tcpCommandSync(_ command: String, ip: String, port: UInt16, timeout: TimeInterval) -> String? {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return nil }
        defer { Darwin.close(sock) }

        // Non-blocking connect
        var flags = fcntl(sock, F_GETFL, 0)
        guard flags >= 0 else { return nil }
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return nil }

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult != 0 {
            guard errno == EINPROGRESS else { return nil }
            var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
            let ready = poll(&pfd, 1, Int32(timeout * 1000))
            guard ready > 0 else { return nil }
            var sockError: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(sock, SOL_SOCKET, SO_ERROR, &sockError, &len)
            guard sockError == 0 else { return nil }
        }

        // Back to blocking mode
        flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags & ~O_NONBLOCK)

        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let bytes = Array(command.utf8)
        guard Darwin.send(sock, bytes, bytes.count, 0) == bytes.count else { return nil }

        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let n = recv(sock, &buffer, buffer.count, 0)
            if n <= 0 { break }
            response.append(contentsOf: buffer[0 ..< n])
        }

        guard !response.isEmpty else { return nil }
        // Strip null terminator
        if response.last == 0 { response.removeLast() }
        return String(data: response, encoding: .utf8)
    }

    // MARK: - Response Parsing

    // Parse pipe-delimited CGMiner response into key=value dict
    private static func parseFields(_ raw: String) -> [String: String] {
        var fields: [String: String] = [:]
        let sections = raw.components(separatedBy: "|")

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let tokens = trimmed.components(separatedBy: ",")
            for token in tokens {
                if token.contains("=") {
                    let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        fields[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                } else if token.contains("["), token.contains("]") {
                    // Handle bracket fields like "PS[0 120 1200 12 144 1200]"
                    if let bracketStart = token.firstIndex(of: "["),
                       let bracketEnd = token.lastIndex(of: "]") {
                        let key = String(token[token.startIndex ..< bracketStart]).trimmingCharacters(in: .whitespaces)
                        let value = String(token[token.index(after: bracketStart) ..< bracketEnd])
                        if !key.isEmpty {
                            fields[key] = value
                        }
                    }
                }
            }
        }

        return fields
    }

    private static func mapToSystemInfo(
        summary: [String: String],
        estats: [String: String],
        pools: [String: String],
        version: [String: String]
    ) -> SystemInfo? {
        guard !summary.isEmpty else { return nil }

        // Hashrate: GHS preferred, MHS as fallback
        let hashRateGH: Double? = {
            if let ghs = summary["GHS av"].flatMap(Double.init) { return ghs }
            if let mhs = summary["MHS av"].flatMap(Double.init) { return mhs / 1000.0 }
            return nil
        }()

        let hashRate5s: Double? = {
            if let ghs = summary["GHS 5s"].flatMap(Double.init) { return ghs }
            if let mhs = summary["MHS 5s"].flatMap(Double.init) { return mhs / 1000.0 }
            return nil
        }()

        let temp = estats["TMax"].flatMap(Double.init) ?? estats["TAvg"].flatMap(Double.init)

        let fanrpm = estats["Fan1"].flatMap(Int.init) ?? estats["Fan2"].flatMap(Int.init)
        let fanspeed: Int? = {
            if let fr = estats["FanR"] {
                return Int(fr.replacingOccurrences(of: "%", with: ""))
            }
            return nil
        }()

        // Power from PS field: "errcode vctrl vhash current power setvolt"
        let power: Double? = {
            if let ps = estats["PS"] {
                let parts = ps.split(separator: " ")
                if parts.count >= 5, let p = Double(parts[4]) {
                    return p
                }
            }
            return nil
        }()

        let poolURL = pools["URL"]
        let poolUser = pools["User"]

        // Parse stratum URL
        let (stratumHost, stratumPort): (String?, Int?) = {
            guard let url = poolURL else { return (nil, nil) }
            var cleaned = url
            if let range = cleaned.range(of: "://") {
                cleaned = String(cleaned[range.upperBound...])
            }
            let hostPort = cleaned.split(separator: ":")
            if hostPort.count == 2 {
                return (String(hostPort[0]), Int(hostPort[1]))
            }
            return (cleaned, nil)
        }()

        let model = version["PROD"]
        let firmware = version["CGMiner"]

        return SystemInfo(
            hashRate: hashRateGH,
            hashRate_1m: hashRate5s,
            hashRate_10m: nil,
            hashRate_1h: nil,
            expectedHashrate: nil,
            temp: temp,
            vrTemp: estats["TAvg"].flatMap(Double.init),
            power: power,
            voltage: nil,
            current: nil,
            coreVoltage: nil,
            coreVoltageActual: nil,
            frequency: nil,
            fanrpm: fanrpm,
            fanspeed: fanspeed,
            bestDiff: nil,
            bestSessionDiff: summary["Best Share"].flatMap(Double.init),
            poolDifficulty: summary["Difficulty Accepted"].flatMap(Double.init),
            sharesAccepted: summary["Accepted"].flatMap(Int.init),
            sharesRejected: summary["Rejected"].flatMap(Int.init),
            hostname: model,
            ssid: nil,
            ipv4: nil,
            wifiStatus: nil,
            wifiRSSI: nil,
            version: firmware,
            ASICModel: model,
            boardVersion: nil,
            uptimeSeconds: summary["Elapsed"].flatMap(Int.init),
            smallCoreCount: nil,
            stratumURL: stratumHost,
            stratumPort: stratumPort,
            stratumUser: poolUser
        )
    }
}

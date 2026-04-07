import Foundation

actor MinerAPIService {
    private let session: URLSession

    init(timeout: TimeInterval = 10) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout + 5
        session = URLSession(configuration: config)
    }

    func fetchSystemInfo(ip: String) async -> SystemInfo? {
        guard let url = URL(string: "http://\(ip)/api/system/info") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(SystemInfo.self, from: data)
        } catch {
            return nil
        }
    }

    func restartDevice(ip: String) async -> Bool {
        guard let url = URL(string: "http://\(ip)/api/system/restart") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200 ... 299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}

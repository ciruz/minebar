import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Notification auth error: \(error)")
            }
        }
    }

    func sendDeviceOffline(name: String) {
        send(
            id: "offline-\(name)",
            title: "Device Offline",
            body: "\(name) is no longer responding."
        )
    }

    func sendHashrateDrop(name: String, hashrate: Double) {
        send(
            id: "hashrate-\(name)",
            title: "Hashrate Drop",
            body: String(format: "%@ hashrate dropped to %.1f GH/s.", name, hashrate)
        )
    }

    func sendTemperatureWarning(name: String, temp: Double, threshold: Double) {
        send(
            id: "temp-\(name)",
            title: "Temperature Warning",
            body: String(format: "%@ is at %.0f°C (threshold: %.0f°C).", name, temp, threshold)
        )
    }

    private func send(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}

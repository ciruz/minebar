import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class MinerStore {
    var miners: [Miner] = []
    var isAddingDevice = false
    var newDeviceName = ""
    var newDeviceIP = ""
    var newDeviceType: MinerType = .bitaxe
    var expandedDeviceID: String?
    var restartConfirmDeviceID: String?
    var editingDevice: DeviceConfig?
    var editName = ""
    var editIP = ""
    var editType: MinerType = .bitaxe

    private let minerAPI = MinerAPIService()
    private let avalonAPI = AvalonAPIService()
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    private let scanner = NetworkScanner()
    private let settings = SettingsStore.shared
    private let notifications = NotificationService.shared
    @ObservationIgnored private var previousStates: [String: MinerSnapshot] = [:]
    @ObservationIgnored private var hasCompletedFirstPoll = false

    private struct MinerSnapshot {
        let isOnline: Bool
        let hashRate: Double?
        let temp: Double?
        let temperatureThreshold: Double
    }

    // All-time best diff per device (API only tracks since boot)
    private var bestDiffHistory: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: "bestDiffHistory") as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "bestDiffHistory") }
    }

    var totalHashrate: Double {
        miners.filter(\.isOnline).compactMap(\.info?.hashRate).reduce(0, +)
    }

    var totalPower: Double {
        miners.filter(\.isOnline).compactMap(\.info?.power).reduce(0, +)
    }

    var efficiency: Double {
        guard totalPower > 0, totalHashrate > 0 else { return 0 }
        return totalPower / (totalHashrate / 1000.0)
    }

    var onlineCount: Int {
        miners.filter(\.isOnline).count
    }

    var menuBarTitle: String {
        guard !miners.isEmpty else { return "⛏ No Devices" }
        guard onlineCount > 0 else { return "⛏ Offline" }
        var parts: [String] = []
        if settings.showHashrateInBar {
            parts.append(SystemInfo.formatHashrate(totalHashrate))
        }
        if settings.showPowerInBar {
            parts.append(String(format: "%.1fW", totalPower))
        }
        if parts.isEmpty { return "⛏" }
        return "⛏ \(parts.joined(separator: " | "))"
    }

    init() {
        let savedDevices = MinerStorage.load()
        let tracked = UserDefaults.standard.dictionary(forKey: "bestDiffHistory") as? [String: Double] ?? [:]
        miners = savedDevices.map { device in
            Miner(device: device, allTimeBestDiff: tracked[device.id])
        }
        startPolling()
    }

    func stop() {
        pollingTask?.cancel()
    }

    func addDevice() {
        let trimmedName = newDeviceName.trimmingCharacters(in: .whitespaces)
        let trimmedIP = newDeviceIP.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedIP.isEmpty else { return }

        let device = DeviceConfig(name: trimmedName, ip: trimmedIP, type: newDeviceType)
        miners.append(Miner(device: device))
        saveDevices()
        newDeviceName = ""
        newDeviceIP = ""
        newDeviceType = .bitaxe
        isAddingDevice = false

        let newID = device.id
        Task { await pollDevice(id: newID) }
    }

    func removeDevice(_ miner: Miner) {
        miners.removeAll { $0.id == miner.id }
        saveDevices()
    }

    func beginEdit(_ device: DeviceConfig) {
        editingDevice = device
        editName = device.name
        editIP = device.ip
        editType = device.type
    }

    func saveEdit() {
        guard let editing = editingDevice else { return }
        if let index = miners.firstIndex(where: { $0.device.id == editing.id }) {
            let updatedDevice = DeviceConfig(
                id: editing.id,
                name: editName.trimmingCharacters(in: .whitespaces),
                ip: editIP.trimmingCharacters(in: .whitespaces),
                type: editType
            )
            miners[index] = Miner(
                device: updatedDevice,
                info: miners[index].info,
                isOnline: miners[index].isOnline,
                allTimeBestDiff: miners[index].allTimeBestDiff
            )
            saveDevices()
            Task { await pollDevice(id: editing.id) }
        }
        editingDevice = nil
    }

    func cancelEdit() {
        editingDevice = nil
    }

    func openWebUI(ip: String) {
        if let url = URL(string: "http://\(ip)") {
            NSWorkspace.shared.open(url)
        }
    }

    func restartDevice(_ miner: Miner) {
        Task {
            switch miner.device.type {
            case .bitaxe, .nerdaxe:
                _ = await minerAPI.restartDevice(ip: miner.device.ip)
            case .avalon:
                _ = await avalonAPI.restartDevice(ip: miner.device.ip)
            }
        }
        restartConfirmDeviceID = nil
    }

    func toggleExpanded(_ id: String) {
        if expandedDeviceID == id {
            expandedDeviceID = nil
        } else {
            expandedDeviceID = id
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await pollAll()
                let interval = UInt64(settings.pollingInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func pollAll() async {
        guard !miners.isEmpty else { return }
        let bAPI = minerAPI
        let aAPI = avalonAPI
        let snapshot = miners.map(\.device)
        await withTaskGroup(of: (String, SystemInfo?).self) { group in
            for device in snapshot {
                group.addTask {
                    let info: SystemInfo?
                    switch device.type {
                    case .bitaxe, .nerdaxe:
                        info = await bAPI.fetchSystemInfo(ip: device.ip)
                    case .avalon:
                        info = await aAPI.fetchSystemInfo(ip: device.ip)
                    }
                    return (device.id, info)
                }
            }
            for await (deviceID, info) in group {
                guard let idx = miners.firstIndex(where: { $0.device.id == deviceID }) else { continue }
                let apiDiff = info?.bestDiff ?? info?.bestSessionDiff ?? 0
                let stored = bestDiffHistory[deviceID] ?? 0
                let best = max(apiDiff, stored)
                if best > 0 { bestDiffHistory[deviceID] = best }
                miners[idx] = Miner(device: miners[idx].device, info: info, isOnline: info != nil, allTimeBestDiff: best > 0 ? best : nil)
            }
        }

        if hasCompletedFirstPoll {
            checkNotifications()
        }
        snapshotStates()
        hasCompletedFirstPoll = true
    }

    private func checkNotifications() {
        for miner in miners {
            let id = miner.device.id
            let name = miner.device.name
            guard let prev = previousStates[id] else { continue }

            if settings.notifyDeviceOffline, prev.isOnline, !miner.isOnline {
                notifications.sendDeviceOffline(name: name)
            }

            if settings.notifyHashrateDrop, miner.isOnline,
               let prevHash = prev.hashRate, prevHash > 0,
               let curHash = miner.info?.hashRate, curHash > 0, curHash < prevHash * 0.5 {
                notifications.sendHashrateDrop(name: name, hashrate: curHash)
            }

            if settings.notifyTemperatureWarning, miner.isOnline,
               let temp = miner.info?.temp, temp >= settings.temperatureThreshold {
                let wasInViolation = (prev.temp ?? 0) >= prev.temperatureThreshold
                if !wasInViolation {
                    notifications.sendTemperatureWarning(name: name, temp: temp, threshold: settings.temperatureThreshold)
                }
            }
        }
    }

    private func snapshotStates() {
        let threshold = settings.temperatureThreshold
        previousStates = Dictionary(uniqueKeysWithValues: miners.map { miner in
            (miner.device.id, MinerSnapshot(
                isOnline: miner.isOnline,
                hashRate: miner.info?.hashRate,
                temp: miner.info?.temp,
                temperatureThreshold: threshold
            ))
        })
    }

    private func pollDevice(id deviceID: String) async {
        guard let idx = miners.firstIndex(where: { $0.device.id == deviceID }) else { return }
        let device = miners[idx].device
        let info: SystemInfo?
        switch device.type {
        case .bitaxe, .nerdaxe:
            info = await minerAPI.fetchSystemInfo(ip: device.ip)
        case .avalon:
            info = await avalonAPI.fetchSystemInfo(ip: device.ip)
        }
        guard let newIdx = miners.firstIndex(where: { $0.device.id == deviceID }) else { return }
        let apiDiff = info?.bestDiff ?? info?.bestSessionDiff ?? 0
        let stored = bestDiffHistory[deviceID] ?? 0
        let best = max(apiDiff, stored)
        if best > 0 { bestDiffHistory[deviceID] = best }
        miners[newIdx] = Miner(device: miners[newIdx].device, info: info, isOnline: info != nil, allTimeBestDiff: best > 0 ? best : nil)
    }

    private func saveDevices() {
        MinerStorage.save(miners.map(\.device))
    }

    // MARK: - Network Scan

    var isScanning = false
    var scanStatus = ""

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var newlyFound = 0

    func rescan() {
        scanTask?.cancel()
        isScanning = true
        newlyFound = 0
        scanStatus = "Detecting local network..."

        guard let localIP = getLocalIPAddress() else {
            scanStatus = "Could not determine local IP"
            isScanning = false
            return
        }

        let subnet = localIP.split(separator: ".").dropLast().joined(separator: ".")
        scanStatus = "Scanning \(subnet).0/24..."

        scanTask = Task {
            await scanner.scan(
                localIP: localIP,
                onFound: { [weak self] device in
                    Task { @MainActor in
                        guard let self, !Task.isCancelled else { return }
                        guard !self.miners.contains(where: { $0.device.ip == device.ip }) else { return }
                        let config = DeviceConfig(name: device.hostname, ip: device.ip, type: device.type)
                        self.miners.append(Miner(device: config))
                        self.saveDevices()
                        self.newlyFound += 1
                        self.scanStatus = "Found \(self.newlyFound) new device\(self.newlyFound == 1 ? "" : "s")..."
                        let newDeviceID = config.id
                        Task { await self.pollDevice(id: newDeviceID) }
                    }
                },
                onProgress: { [weak self] checked, total in
                    Task { @MainActor in
                        guard let self, !Task.isCancelled else { return }
                        let pct = Int(Double(checked) / Double(total) * 100)
                        if self.newlyFound > 0 {
                            self.scanStatus = "Scanning... \(pct)% - \(self.newlyFound) new"
                        } else {
                            self.scanStatus = "Scanning... \(pct)%"
                        }
                    }
                }
            )
            if newlyFound > 0 {
                scanStatus = "Done - added \(newlyFound) device\(newlyFound == 1 ? "" : "s")"
            } else {
                scanStatus = miners.isEmpty
                    ? "Done - no mining devices found"
                    : "Done - no new devices found"
            }
            isScanning = false
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !isScanning {
                scanStatus = ""
            }
        }
    }
}

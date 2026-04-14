import Network
import Sparkle
import SwiftUI
import UserNotifications

@main
struct MineBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: PopoverPanel!
    private var viewModel: MinerStore!
    private var updaterController: SPUStandardUpdaterController!
    private var titleObservationTask: Task<Void, Never>?
    private var isPopoverOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = MinerStore()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        WindowManager.shared.updater = updaterController.updater

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Prompt for local network access before first popover open
        triggerLocalNetworkPermission()

        panel = PopoverPanel()
        let hc = NSHostingController(rootView: MenuBarPopoverView(
            store: viewModel,
            updater: updaterController.updater
        ))
        hc.sizingOptions = .preferredContentSize
        panel.contentViewController = hc
        panel.onClose = { [weak self] in
            self?.panelDidClose()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.title = viewModel.menuBarTitle
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Observe miners and settings changes for title sync (frozen while popover is open)
        let settings = SettingsStore.shared
        titleObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.viewModel.miners
                        _ = settings.showHashrateInBar
                        _ = settings.showPowerInBar
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !isPopoverOpen else { continue }
                updateStatusTitle()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        titleObservationTask?.cancel()
        viewModel.stop()
    }

    private nonisolated func triggerLocalNetworkPermission() {
        let connection = NWConnection(host: "224.0.0.1", port: 9, using: .udp)
        connection.start(queue: .global(qos: .utility))
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            connection.cancel()
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if panel.isVisible {
            panel.close()
        } else {
            // Debounce: don't reopen if just closed by event monitor
            guard Date().timeIntervalSince(panel.lastCloseTime) > 0.2 else { return }
            isPopoverOpen = true
            panel.show(relativeTo: button)
        }
    }

    private func panelDidClose() {
        isPopoverOpen = false
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        let newTitle = viewModel.menuBarTitle
        guard let button = statusItem.button, button.title != newTitle else { return }
        button.title = newTitle
    }
}

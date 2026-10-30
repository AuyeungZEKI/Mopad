import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppState.shared.boot()
            // 首次启动直接打开设置页
            if !UserDefaults.standard.bool(forKey: "launchedOnce") {
                UserDefaults.standard.set(true, forKey: "launchedOnce")
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .openSettings, object: nil)
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        MultitouchManager.shared.stopAll()
    }
}

extension Notification.Name { static let openSettings = Notification.Name("MopadOpenSettings") }

/// 隐形桥接：监听通知并打开设置窗口（openWindow 只能在 View 内使用）
struct WindowOpener: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Image(systemName: "hand.point.up.left.and.text")
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
    }
}

@main
struct MopadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            WindowOpener()
        }

        Window("Mopad", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

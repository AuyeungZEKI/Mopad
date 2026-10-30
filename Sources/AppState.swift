import AppKit
import SwiftUI
import ServiceManagement
import ApplicationServices
import os

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // 手势设置（持久化到 UserDefaults）
    @AppStorage("enabled") var enabled = true { didSet { push() } }
    @AppStorage("oneTapEnabled") var oneTapEnabled = true { didSet { push() } }
    @AppStorage("tapEnabled") var tapEnabled = true { didSet { push() } }
    @AppStorage("tapMaxDuration") var tapMaxDuration = 0.30 { didSet { push() } }
    @AppStorage("pinch3Enabled") var pinch3Enabled = true { didSet { push() } }
    @AppStorage("pinch3Sensitivity") var pinch3Sensitivity = 0.5 { didSet { push() } }
    @AppStorage("pinch3Action") var pinch3Action: PinchAction = .apps { didSet { push() } }
    @AppStorage("zoomEnabled") var zoomEnabled = true { didSet { push() } }
    @AppStorage("zoomMode") var zoomMode: ZoomMode = .native { didSet { push() } }
    @AppStorage("zoomSensitivity") var zoomSensitivity = 0.5 { didSet { push() } }
    @AppStorage("zoomSpeed") var zoomSpeed = 1.6 { didSet { push() } }

    // 系统鼠标设置（直接读写系统）
    @Published var trackingSpeed = MouseSettings.trackingSpeed
    @Published var scrollSpeed = MouseSettings.scrollSpeed
    @Published var doubleClick = MouseSettings.doubleClickInterval { didSet { push() } }
    @Published var naturalScroll = MouseSettings.naturalScroll
    @Published var secondaryClick = MouseSettings.secondaryClick
    @Published var smartZoom = MouseSettings.smartZoom
    @Published var missionControlTap = MouseSettings.missionControlTap
    @Published var fullscreenSwipe = MouseSettings.fullscreenSwipe
    @Published var pageSwipe = MouseSettings.pageSwipe

    // 运行状态
    @Published var trusted = AXIsProcessTrusted()
    @Published var postAccess = CGPreflightPostEventAccess()
    @Published var tapRunning = false
    @Published var mouseName: String? = nil
    @Published var mtAvailable = MultitouchManager.shared.isLoaded
    @Published var live = LiveStatus()
    @Published var touchPoints: [CGPoint] = []          // 归一化坐标，用于实时预览
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    var permissionsOK: Bool { trusted && postAccess && tapRunning }

    private var timer: Timer?
    private let launchedTrusted = AXIsProcessTrusted()

    private init() {}

    /// 触控回调运行在私有框架的后台线程，必须在非隔离上下文中创建
    nonisolated private static func installHandlers() {
        let throttle = OSAllocatedUnfairLock(initialState: 0.0)
        MultitouchManager.shared.onFrame = { _, touches in
            GestureEngine.shared.process(touches)
            let pts = touches.filter { $0.state == 4 || $0.state == 5 }.map { CGPoint(x: $0.nx, y: $0.ny) }
            let t = ProcessInfo.processInfo.systemUptime
            let go = throttle.withLock { last -> Bool in
                if pts.isEmpty || t - last > 1.0 / 30 { last = t; return true }
                return false
            }
            guard go else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { AppState.shared.touchPoints = pts } }
        }
        GestureEngine.shared.onStatus = { s in
            DispatchQueue.main.async { MainActor.assumeIsolated { AppState.shared.live = s } }
        }
    }

    func boot() {
        push()
        AppState.installHandlers()
        rescan()
        startInputIfTrusted()
        tapRunning = InputMonitor.shared.isRunning
        writeDiagnostics()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.rescan()
            }
        }
    }

    private func tick() {
        let t = AXIsProcessTrusted()
        if t != trusted { trusted = t }

        // 启动时未授权、运行中刚获得授权：重启进程，确保事件发送与监听生效
        if t && !launchedTrusted {
            relaunch()
            return
        }

        startInputIfTrusted()
        let p = CGPreflightPostEventAccess()
        if t && !p { _ = CGRequestPostEventAccess() }
        if p != postAccess { postAccess = p }
        let r = InputMonitor.shared.isRunning
        if r != tapRunning { tapRunning = r }

        if MultitouchManager.shared.mouseIDsChanged() { rescan() }
        writeDiagnostics()
    }

    func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.8; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    /// 诊断信息：~/Library/Application Support/Mopad/status.json
    private func writeDiagnostics() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mopad")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "time": ISO8601DateFormatter().string(from: Date()),
            "pid": ProcessInfo.processInfo.processIdentifier,
            "accessibility": trusted,
            "postEventAccess": postAccess,
            "eventTapRunning": tapRunning,
            "magicMouse": mouseName != nil,
            "multitouchLoaded": mtAvailable,
            "lastGesture": live.lastGesture,
        ]
        if let d = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: dir.appendingPathComponent("status.json"))
        }
    }

    func rescan() {
        let devices = MultitouchManager.shared.rescan()
        mouseName = devices.contains(where: { $0.isMagicMouse }) ? "妙控鼠标" : nil
    }

    private func startInputIfTrusted() {
        if trusted && !InputMonitor.shared.isRunning { InputMonitor.shared.start() }
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        _ = CGRequestPostEventAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func reloadMouseSettings() {
        trackingSpeed = MouseSettings.trackingSpeed
        scrollSpeed = MouseSettings.scrollSpeed
        doubleClick = MouseSettings.doubleClickInterval
        naturalScroll = MouseSettings.naturalScroll
        secondaryClick = MouseSettings.secondaryClick
        smartZoom = MouseSettings.smartZoom
        missionControlTap = MouseSettings.missionControlTap
        fullscreenSwipe = MouseSettings.fullscreenSwipe
        pageSwipe = MouseSettings.pageSwipe
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { NSLog("Mopad login item: \(error)") }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// 把 UI 参数换算成引擎阈值
    private func push() {
        var c = GestureConfig()
        c.enabled = enabled
        c.oneTapEnabled = oneTapEnabled
        c.doubleClickInterval = doubleClick
        c.tapEnabled = tapEnabled
        c.tapMaxDuration = tapMaxDuration
        c.pinch3Enabled = pinch3Enabled
        c.pinch3Ratio = 0.76 + 0.16 * pinch3Sensitivity          // 低 0.76 … 中 0.84 … 高 0.92
        c.pinch3ShrinkMM = 6.5 - 5.0 * pinch3Sensitivity         // 低 6.5mm … 中 4mm … 高 1.5mm
        c.pinch3Action = pinch3Action
        c.zoomEnabled = zoomEnabled
        c.zoomMode = zoomMode
        c.zoomStartMM = 7.0 - 5.0 * zoomSensitivity               // 灵敏 2mm … 迟钝 7mm
        c.zoomGain = zoomSpeed
        GestureEngine.shared.config = c
    }
}

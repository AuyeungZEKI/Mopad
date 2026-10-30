import AppKit
import CoreGraphics

/// 标记由 Mopad 合成的事件，事件监听里据此放行，避免自我干扰
let kMopadEventMarker: Int64 = 0x4D4F5041 // "MOPA"

enum GesturePhase: Int64 {
    case began = 1, changed = 2, ended = 4, cancelled = 8
}

enum Actions {
    /// 仿真测试用：只记录不执行
    nonisolated(unsafe) static var dryRun = false
    private static let source = CGEventSource(stateID: .hidSystemState)

    private static func cursor() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
    static func cursorLocation() -> CGPoint { cursor() }

    private static func post(_ e: CGEvent?, tap: CGEventTapLocation = .cghidEventTap) {
        guard !dryRun, let e else { return }
        e.setIntegerValueField(.eventSourceUserData, value: kMopadEventMarker)
        e.post(tap: tap)
    }

    // MARK: 左键（支持连按计数）
    static func leftClick(at p: CGPoint, clickState: Int64) {
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)
        down?.setIntegerValueField(.mouseEventClickState, value: clickState)
        up?.setIntegerValueField(.mouseEventClickState, value: clickState)
        post(down); post(up)
    }

    // MARK: 右键
    static func rightClick() {
        let p = cursor()
        post(CGEvent(mouseEventSource: source, mouseType: .rightMouseDown, mouseCursorPosition: p, mouseButton: .right))
        post(CGEvent(mouseEventSource: source, mouseType: .rightMouseUp, mouseCursorPosition: p, mouseButton: .right))
    }

    // MARK: 原生缩放（合成触控板 magnify 手势事件）
    // 字段编号来自 WindowServer 私有约定：55=事件类型 29(Gesture)，110=HID 子类型 8(Zoom)，113=缩放量，132=阶段
    static func magnify(_ amount: Double, phase: GesturePhase) {
        guard let e = CGEvent(source: nil) else { return }
        e.type = CGEventType(rawValue: 29)!
        e.setIntegerValueField(CGEventField(rawValue: 110)!, value: 8)
        e.setIntegerValueField(CGEventField(rawValue: 132)!, value: phase.rawValue)
        e.setDoubleValueField(CGEventField(rawValue: 113)!, value: amount)
        post(e, tap: .cgSessionEventTap)
    }

    // MARK: 快捷键缩放
    static func zoomKey(zoomIn: Bool) {
        key(code: zoomIn ? 0x18 : 0x1B, flags: .maskCommand)   // = / -
    }

    static func key(code: CGKeyCode, flags: CGEventFlags) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.flags = flags; up?.flags = flags
        post(down); post(up)
    }

    // MARK: 三指捏合动作
    static func perform(_ action: PinchAction) {
        guard !dryRun else { return }
        DispatchQueue.main.async {
            switch action {
            case .apps:
                let candidates = ["/System/Applications/Apps.app", "/System/Applications/Launchpad.app"]
                if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                    openApp(path)
                }
            case .missionControl:
                openApp("/System/Applications/Mission Control.app")
            case .showDesktop:
                openApp("/System/Applications/Mission Control.app", args: ["1"])
            case .spotlight:
                key(code: 0x31, flags: .maskCommand)                 // ⌘ Space
            }
        }
    }

    private static func openApp(_ path: String, args: [String] = []) {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.arguments = args
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: cfg) { _, _ in }
    }
}

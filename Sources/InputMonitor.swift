import AppKit
import CoreGraphics

/// 全局事件监听：识别物理点击（防止三指轻触误判）+ 缩放时屏蔽滚动与系统轻扫
final class InputMonitor {
    static let shared = InputMonitor()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        var mask: CGEventMask = 0
        for t: CGEventType in [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel] {
            mask |= 1 << CGEventMask(t.rawValue)
        }
        mask |= 1 << 29   // 手势事件
        mask |= 1 << 30   // Dock 轻扫（全屏应用切换）

        let cb: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = InputMonitor.shared.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            if event.getIntegerValueField(.eventSourceUserData) == kMopadEventMarker {
                return Unmanaged.passUnretained(event)
            }
            switch type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                GestureEngine.shared.notePhysicalClick()
            case .scrollWheel:
                GestureEngine.shared.noteScroll()
                if GestureEngine.shared.shouldSuppressScroll() { return nil }
            default:
                if type.rawValue == 30, GestureEngine.shared.shouldSuppressScroll() { return nil }
            }
            return Unmanaged.passUnretained(event)
        }

        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .defaultTap, eventsOfInterest: mask,
                                        callback: cb, userInfo: nil) else { return false }
        tap = t
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func stop() {
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        tap = nil; source = nil
    }
}

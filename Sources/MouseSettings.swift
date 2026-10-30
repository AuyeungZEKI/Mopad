import Foundation

enum SecondaryClick: String, CaseIterable, Identifiable {
    case right = "TwoButton", left = "TwoButtonSwapped", off = "OneButton"
    var id: String { rawValue }
    var title: String {
        switch self { case .right: return "点按右侧"; case .left: return "点按左侧"; case .off: return "关闭" }
    }
}

/// 读写「系统设置 › 鼠标」的同一套参数：写入 HID 事件系统（即时生效）+ 用户偏好（持久化，与系统设置同步）
enum MouseSettings {
    private static let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    private static let mouseDomains = ["com.apple.AppleMultitouchMouse", "com.apple.driver.AppleBluetoothMultitouch.mouse"]

    private static let ppsHandle = dlopen("/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport", RTLD_NOW)
    private static let setSwipe: SetSwipeScrollDirectionFn? = {
        guard let h = ppsHandle, let p = dlsym(h, "setSwipeScrollDirection") else { return nil }
        return unsafeBitCast(p, to: SetSwipeScrollDirectionFn.self)
    }()

    // MARK: 底层

    private static func hidSet(_ key: String, _ value: CFTypeRef) {
        guard let c = client else { return }
        _ = IOHIDEventSystemClientSetProperty(c, key as CFString, value)
    }
    private static func hidFixed(_ key: String, _ v: Double) {
        hidSet(key, NSNumber(value: Int64((v * 65536).rounded())))
    }
    private static func globalGet(_ key: String) -> Any? {
        CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    private static func globalSet(_ key: String, _ v: Any) {
        CFPreferencesSetValue(key as CFString, v as CFPropertyList, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    private static func mouseGet(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, mouseDomains[0] as CFString)
    }
    private static func mouseSet(_ key: String, _ v: Any) {
        for d in mouseDomains {
            CFPreferencesSetAppValue(key as CFString, v as CFPropertyList, d as CFString)
            CFPreferencesAppSynchronize(d as CFString)
        }
        hidSet(key, v as CFTypeRef)
    }
    private static func num(_ any: Any?, _ fallback: Double) -> Double { (any as? NSNumber)?.doubleValue ?? fallback }

    // MARK: 跟踪速度 0 ~ 3
    static var trackingSpeed: Double { num(globalGet("com.apple.mouse.scaling"), 1.0) }
    static func setTrackingSpeed(_ v: Double) {
        globalSet("com.apple.mouse.scaling", v)
        hidFixed("HIDMouseAcceleration", v)
    }

    // MARK: 滚动速度 0 ~ 1
    static var scrollSpeed: Double { num(globalGet("com.apple.scrollwheel.scaling"), 0.3125) }
    static func setScrollSpeed(_ v: Double) {
        globalSet("com.apple.scrollwheel.scaling", v)
        hidFixed("HIDMouseScrollAcceleration", v)
    }

    // MARK: 双击速度（秒，越小越快）
    static var doubleClickInterval: Double { num(globalGet("com.apple.mouse.doubleClickThreshold"), 0.5) }
    static func setDoubleClickInterval(_ v: Double) {
        globalSet("com.apple.mouse.doubleClickThreshold", v)
        hidSet("HIDClickTime", NSNumber(value: Int64(v * 1_000_000_000)))
    }

    // MARK: 自然滚动（与触控板共用）
    static var naturalScroll: Bool { (globalGet("com.apple.swipescrolldirection") as? Bool) ?? true }
    static func setNaturalScroll(_ on: Bool) {
        if let f = setSwipe { f(on) } else { globalSet("com.apple.swipescrolldirection", on) }
        DistributedNotificationCenter.default().postNotificationName(.init("SwipeScrollDirectionDidChangeNotification"), object: nil, userInfo: nil, deliverImmediately: true)
    }

    // MARK: 辅助点按
    static var secondaryClick: SecondaryClick {
        SecondaryClick(rawValue: (mouseGet("MouseButtonMode") as? String) ?? "") ?? .right
    }
    static func setSecondaryClick(_ m: SecondaryClick) { mouseSet("MouseButtonMode", m.rawValue) }

    // MARK: 智能缩放（单指连按两下）
    static var smartZoom: Bool { num(mouseGet("MouseOneFingerDoubleTapGesture"), 1) != 0 }
    static func setSmartZoom(_ on: Bool) { mouseSet("MouseOneFingerDoubleTapGesture", on ? 1 : 0) }

    // MARK: 调度中心（双指连按两下）
    static var missionControlTap: Bool { num(mouseGet("MouseTwoFingerDoubleTapGesture"), 3) != 0 }
    static func setMissionControlTap(_ on: Bool) { mouseSet("MouseTwoFingerDoubleTapGesture", on ? 3 : 0) }

    // MARK: 在全屏应用间轻扫（双指左右扫）
    static var fullscreenSwipe: Bool { num(mouseGet("MouseTwoFingerHorizSwipeGesture"), 2) != 0 }
    static func setFullscreenSwipe(_ on: Bool) { mouseSet("MouseTwoFingerHorizSwipeGesture", on ? 2 : 0) }

    // MARK: 在页面间轻扫（单指左右扫）
    static var pageSwipe: Bool { (globalGet("AppleEnableMouseSwipeNavigateWithScrolls") as? Bool) ?? true }
    static func setPageSwipe(_ on: Bool) { globalSet("AppleEnableMouseSwipeNavigateWithScrolls", on) }
}

import Foundation
import CoreGraphics

/// 归一化后的单个触点
struct Touch {
    let id: Int32
    let state: Int32
    let nx: Double          // 0~1
    let ny: Double          // 0~1
    let pt: CGPoint         // 毫米坐标
}

struct MTDeviceInfo: Identifiable {
    let id: UInt
    let ref: MTDeviceRef
    let deviceID: UInt64
    let family: Int32
    let widthMM: Double
    let heightMM: Double
    let builtIn: Bool

    /// 妙控鼠标：family 112/113，或外接且感应面竖长
    var isMagicMouse: Bool { [112, 113].contains(family) || (!builtIn && heightMM > widthMM) }
}

/// C 回调：私有框架在后台线程逐帧调用
private let mtCallback: MTContactCallback = { device, touches, count, _, _ in
    MultitouchManager.shared.dispatch(device: device, touches: touches, count: Int(count))
    return 0
}

final class MultitouchManager {
    static let shared = MultitouchManager()

    private var fnCreateList: MTDeviceCreateListFn?
    private var fnRegister: MTRegisterContactFrameCallbackFn?
    private var fnUnregister: MTUnregisterContactFrameCallbackFn?
    private var fnStart: MTDeviceStartFn?
    private var fnStop: MTDeviceStopFn?
    private var fnFamily: MTDeviceGetFamilyIDFn?
    private var fnDeviceID: MTDeviceGetDeviceIDFn?
    private var fnDims: MTDeviceGetSensorSurfaceDimensionsFn?
    private var fnBuiltIn: MTDeviceIsBuiltInFn?

    private(set) var isLoaded = false
    private let lock = NSLock()
    private var active: [UInt: MTDeviceInfo] = [:]
    private var retainedList: CFArray?

    var onFrame: ((MTDeviceInfo, [Touch]) -> Void)?

    private init() { load() }

    private func load() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let h = dlopen(path, RTLD_NOW) else { return }
        func sym<T>(_ name: String, _: T.Type) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }
        fnCreateList = sym("MTDeviceCreateList", MTDeviceCreateListFn.self)
        fnRegister   = sym("MTRegisterContactFrameCallback", MTRegisterContactFrameCallbackFn.self)
        fnUnregister = sym("MTUnregisterContactFrameCallback", MTUnregisterContactFrameCallbackFn.self)
        fnStart      = sym("MTDeviceStart", MTDeviceStartFn.self)
        fnStop       = sym("MTDeviceStop", MTDeviceStopFn.self)
        fnFamily     = sym("MTDeviceGetFamilyID", MTDeviceGetFamilyIDFn.self)
        fnDeviceID   = sym("MTDeviceGetDeviceID", MTDeviceGetDeviceIDFn.self)
        fnDims       = sym("MTDeviceGetSensorSurfaceDimensions", MTDeviceGetSensorSurfaceDimensionsFn.self)
        fnBuiltIn    = sym("MTDeviceIsBuiltIn", MTDeviceIsBuiltInFn.self)
        isLoaded = fnCreateList != nil && fnRegister != nil && fnStart != nil
    }

    private func enumerate() -> (CFArray, [MTDeviceInfo])? {
        guard isLoaded, let create = fnCreateList, let list = create()?.takeRetainedValue() else { return nil }
        var out: [MTDeviceInfo] = []
        for i in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, i) else { continue }
            let ref = UnsafeMutableRawPointer(mutating: raw)
            var fam: Int32 = 0; _ = fnFamily?(ref, &fam)
            var did: UInt64 = 0; _ = fnDeviceID?(ref, &did)
            var w: Int32 = 0, hgt: Int32 = 0; _ = fnDims?(ref, &w, &hgt)
            out.append(MTDeviceInfo(id: UInt(bitPattern: ref), ref: ref, deviceID: did, family: fam,
                                    widthMM: Double(w) / 100, heightMM: Double(hgt) / 100,
                                    builtIn: fnBuiltIn?(ref) ?? false))
        }
        return (list, out)
    }

    /// 重新扫描并只监听妙控鼠标
    @discardableResult
    func rescan() -> [MTDeviceInfo] {
        stopAll()
        guard let (list, found) = enumerate() else { return [] }
        retainedList = list
        let mice = found.filter { $0.isMagicMouse }
        lock.lock(); for d in mice { active[d.id] = d }; lock.unlock()
        for d in mice {
            fnRegister?(d.ref, mtCallback)
            _ = fnStart?(d.ref, 0)
        }
        return found
    }

    /// 鼠标断开重连后 deviceID 会变化，用于判断是否需要重新扫描
    func mouseIDsChanged() -> Bool {
        guard let (_, found) = enumerate() else { return false }
        let now = Set(found.filter { $0.isMagicMouse }.map { $0.deviceID })
        lock.lock(); let cur = Set(active.values.map { $0.deviceID }); lock.unlock()
        return now != cur
    }

    func stopAll() {
        lock.lock(); let ds = Array(active.values); active.removeAll(); lock.unlock()
        for d in ds {
            fnUnregister?(d.ref, mtCallback)
            _ = fnStop?(d.ref)
        }
    }

    fileprivate func dispatch(device: MTDeviceRef?, touches: UnsafePointer<MTTouch>?, count: Int) {
        lock.lock()
        var info = device.flatMap { active[UInt(bitPattern: $0)] }
        if info == nil, active.count == 1 { info = active.values.first }
        lock.unlock()
        guard let info else { return }

        var arr: [Touch] = []
        if let touches, count > 0 {
            arr.reserveCapacity(count)
            for i in 0..<count {
                let t = touches[i]
                let nx = Double(t.normalized.position.x), ny = Double(t.normalized.position.y)
                arr.append(Touch(id: t.identifier, state: t.state, nx: nx, ny: ny,
                                 pt: CGPoint(x: nx * info.widthMM, y: ny * info.heightMM)))
            }
        }
        onFrame?(info, arr)
    }
}

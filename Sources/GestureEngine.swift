import Foundation
import CoreGraphics
import os

enum PinchAction: String, CaseIterable, Identifiable {
    case apps, missionControl, spotlight, showDesktop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .apps: return "应用程序索引"
        case .missionControl: return "调度中心"
        case .spotlight: return "聚焦搜索"
        case .showDesktop: return "显示桌面"
        }
    }
}

enum ZoomMode: String, CaseIterable, Identifiable {
    case native, keyboard
    var id: String { rawValue }
    var title: String { self == .native ? "原生捏合（平滑）" : "快捷键 ⌘+ / ⌘−" }
}

/// 手势参数快照（主线程写，触控线程读）
struct GestureConfig {
    var enabled = true
    var oneTapEnabled = true
    var oneTapMaxDuration = 0.20       // 单指轻点：落下到抬起不超过 0.2 秒
    var oneTapMaxMoveMM = 1.5          // 且手指几乎不动
    var doubleClickInterval = 0.5      // 与系统「连按速度」一致
    var tapEnabled = true
    var tapMaxDuration = 0.30          // 秒
    var tapMaxMoveMM = 2.5
    var pinch3Enabled = true
    var pinch3Ratio = 0.84             // 间距缩到原来的 84% 即触发（收拢约 16%）
    var pinch3ShrinkMM = 4.0           // 或间距绝对收缩超过该毫米数
    var pinch3Action: PinchAction = .apps
    var zoomEnabled = true
    var zoomMode: ZoomMode = .native
    var zoomStartMM = 4.0              // 双指距离变化超过该值才进入缩放，避免误伤滚动
    var zoomGain = 1.6
}

/// 供 UI 实时显示的状态
struct LiveStatus {
    var fingers = 0
    var lastGesture = "—"
    var lastGestureTime = Date.distantPast
}

final class GestureEngine {
    static let shared = GestureEngine()

    private let cfgLock = OSAllocatedUnfairLock(initialState: GestureConfig())
    var config: GestureConfig {
        get { cfgLock.withLock { $0 } }
        set { cfgLock.withLock { $0 = newValue } }
    }

    /// 物理点击 / 滚动时间戳与滚动屏蔽窗口（事件监听线程与触控线程共享）
    private let shared = OSAllocatedUnfairLock(initialState: (lastPhysicalClick: 0.0, lastScroll: 0.0, suppressUntil: 0.0, zooming: false))

    var onStatus: ((LiveStatus) -> Void)?
    private var status = LiveStatus()

    // —— 单指追踪
    private struct Track { var down: Double; var start: CGPoint; var maxMove: Double; var cursor: CGPoint }
    private var tracks: [Int32: Track] = [:]
    private var recentDowns: [(id: Int32, time: Double)] = []
    private var peakCount = 0

    // —— 单指轻点
    private var lastTapTime = 0.0
    private var lastTapPos = CGPoint.zero
    private var lastClickState: Int64 = 0

    // —— 三指轻触候选
    private var tapGroup: Set<Int32>? = nil
    private var tapStart = 0.0
    private var tapValid = false

    // —— 三指捏合
    private var pinchCount = 0
    private var pinchLastSeen = 0.0
    private var pinchBase = 0.0
    private var pinchFired = false

    // —— 双指缩放
    private var zoomIDs: Set<Int32> = []
    private var zoomBase = 0.0
    private var zoomPrev = 0.0
    private var zooming = false
    private var keyAccum = 0.0

    private init() {}

    // MARK: 事件监听回调

    func notePhysicalClick() {
        let t = now()
        shared.withLock { $0.lastPhysicalClick = t }
    }

    func noteScroll() {
        let t = now()
        shared.withLock { $0.lastScroll = t }
    }

    func shouldSuppressScroll() -> Bool {
        let t = now()
        return shared.withLock { $0.zooming || t < $0.suppressUntil }
    }

    // MARK: 逐帧处理（触控线程）

    func process(_ touches: [Touch]) {
        let cfg = config
        let t = now()
        let live = touches.filter { $0.state == 4 || $0.state == 5 }
        let ids = Set(live.map { $0.id })

        // 更新追踪
        for f in live {
            if var tr = tracks[f.id] {
                tr.maxMove = max(tr.maxMove, dist(tr.start, f.pt))
                tracks[f.id] = tr
            } else {
                tracks[f.id] = Track(down: t, start: f.pt, maxMove: 0, cursor: Actions.cursorLocation())
                recentDowns.append((f.id, t))
            }
        }
        var lifted: [(Int32, Track)] = []
        for (id, tr) in tracks where !ids.contains(id) {
            lifted.append((id, tr))
            tracks.removeValue(forKey: id)
        }
        recentDowns.removeAll { t - $0.time > 1.0 }

        if live.count != status.fingers { status.fingers = live.count; publish() }

        guard cfg.enabled else { resetAll(); return }

        handleOneTap(lifted: lifted, now: t, cfg: cfg)
        handleTap(live: live, ids: ids, now: t, cfg: cfg)
        handlePinch3(live: live, ids: ids, now: t, cfg: cfg)
        handleZoom(live: live, ids: ids, cfg: cfg)

        if live.isEmpty { peakCount = 0; pinchFired = false }
        else { peakCount = max(peakCount, live.count) }
    }

    // 单指轻点 = 点按；两次轻点间隔小于「连按速度」= 连按
    // 防误触：手指要快落快起且几乎不动；前后 0.15 秒内有别的手指落下（多指轻触）、
    // 期间发生物理按下或滚动、鼠标本身被移动，都不算
    private func handleOneTap(lifted: [(Int32, Track)], now t: Double, cfg: GestureConfig) {
        guard cfg.oneTapEnabled, lifted.count == 1, let (id, tr) = lifted.first else { return }
        guard t - tr.down <= cfg.oneTapMaxDuration, tr.maxMove <= cfg.oneTapMaxMoveMM else { return }
        guard !recentDowns.contains(where: { $0.id != id && $0.time >= tr.down - 0.15 }) else { return }
        guard tapGroup?.contains(id) != true, !pinchFired, !zooming else { return }

        let (click, scroll) = shared.withLock { ($0.lastPhysicalClick, $0.lastScroll) }
        guard click < tr.down - 0.05, scroll < tr.down else { return }

        let p = Actions.cursorLocation()
        guard dist(p, tr.cursor) <= 6 else { return }

        let isRepeat = t - lastTapTime <= cfg.doubleClickInterval && dist(p, lastTapPos) <= 5
        lastClickState = isRepeat ? min(lastClickState + 1, 3) : 1
        lastTapTime = t
        lastTapPos = p

        Actions.leftClick(at: p, clickState: lastClickState)
        report(lastClickState >= 2 ? "单指轻点两下 → 连按" : "单指轻点 → 点按")
    }

    // 三指轻触 = 右键：三根手指都在短时间内落下并抬起，且几乎不移动
    private func handleTap(live: [Touch], ids: Set<Int32>, now t: Double, cfg: GestureConfig) {
        guard cfg.tapEnabled else { tapGroup = nil; return }

        if live.count > 3 { tapValid = false }

        if tapGroup == nil, live.count == 3 {
            let downs = ids.compactMap { tracks[$0]?.down }
            if let first = downs.min(), t - first <= cfg.tapMaxDuration {
                tapGroup = ids; tapStart = first; tapValid = true
            }
        }

        guard let group = tapGroup else { return }

        for id in group where ids.contains(id) {
            if let tr = tracks[id], tr.maxMove > cfg.tapMaxMoveMM { tapValid = false }
        }
        if t - tapStart > cfg.tapMaxDuration { tapValid = false }
        if pinchFired || zooming { tapValid = false }

        if group.isDisjoint(with: ids) {
            let clicked = shared.withLock { $0.lastPhysicalClick } >= tapStart - 0.05
            if tapValid && !clicked {
                Actions.rightClick()
                report("三指轻触 → 右键")
            }
            tapGroup = nil
        } else if !tapValid && live.count < 3 && t - tapStart > cfg.tapMaxDuration {
            tapGroup = nil
        }
    }

    // 三指捏合 = 打开索引（接近触控板识别程度：轻微收拢即触发）
    // · 支持 3 指或「拇指 + 3 指」4 指
    // · 基准取本次捏合过程中的最大间距，先张后捏也能识别
    // · 手指短暂丢失（<0.15s）或触点重新编号时不清零进度
    private func handlePinch3(live: [Touch], ids: Set<Int32>, now t: Double, cfg: GestureConfig) {
        guard cfg.pinch3Enabled else { pinchCount = 0; return }

        guard live.count >= 3, live.count <= 4 else {
            if pinchCount > 0, t - pinchLastSeen > 0.15 { pinchCount = 0 }
            return
        }
        let s = spread(live)
        pinchLastSeen = t

        // 指数变化（3↔4）时间距不可比，重新建立基准
        if live.count != pinchCount {
            pinchCount = live.count
            pinchBase = s
            return
        }
        pinchBase = max(pinchBase, s)

        guard !pinchFired, pinchBase > 4 else { return }
        let shrink = pinchBase - s
        let ratioHit = s / pinchBase <= cfg.pinch3Ratio
        let distHit = shrink >= cfg.pinch3ShrinkMM
        if shrink >= 1.5 && (ratioHit || distHit) {
            pinchFired = true
            tapValid = false
            Actions.perform(cfg.pinch3Action)
            report("三指捏合 → \(cfg.pinch3Action.title)")
        }
    }

    // 双指捏合/张开 = 缩放
    private func handleZoom(live: [Touch], ids: Set<Int32>, cfg: GestureConfig) {
        guard cfg.zoomEnabled, live.count == 2, peakCount <= 2 || zooming else {
            endZoom(); zoomIDs = []; return
        }
        let d = dist(live[0].pt, live[1].pt)
        if ids != zoomIDs {
            endZoom()
            zoomIDs = ids; zoomBase = d; zoomPrev = d; keyAccum = 0
            return
        }
        if !zooming {
            guard abs(d - zoomBase) >= cfg.zoomStartMM, zoomBase > 3 else { return }
            zooming = true
            zoomPrev = d
            shared.withLock { $0.zooming = true }
            if cfg.zoomMode == .native { Actions.magnify(0, phase: .began) }
            report(d > zoomBase ? "双指张开 → 放大" : "双指捏合 → 缩小")
            return
        }
        let delta = (d - zoomPrev) / max(zoomBase, 8) * cfg.zoomGain
        zoomPrev = d
        guard abs(delta) > 0.0005 else { return }
        switch cfg.zoomMode {
        case .native:
            Actions.magnify(delta, phase: .changed)
        case .keyboard:
            keyAccum += delta
            let step = 0.18
            while keyAccum >= step { Actions.zoomKey(zoomIn: true); keyAccum -= step }
            while keyAccum <= -step { Actions.zoomKey(zoomIn: false); keyAccum += step }
        }
    }

    private func endZoom() {
        guard zooming else { return }
        zooming = false
        if config.zoomMode == .native { Actions.magnify(0, phase: .ended) }
        let until = now() + 0.6   // 吞掉抬指后的惯性滚动
        shared.withLock { $0.zooming = false; $0.suppressUntil = until }
    }

    private func resetAll() {
        endZoom(); tapGroup = nil; pinchCount = 0; zoomIDs = []; pinchFired = false
    }

    // MARK: 工具

    private func report(_ s: String) {
        status.lastGesture = s
        status.lastGestureTime = Date()
        publish()
    }
    private func publish() { let s = status; onStatus?(s) }

    private func now() -> Double { ProcessInfo.processInfo.systemUptime }
    private func dist(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(Double(a.x - b.x), Double(a.y - b.y)) }
    private func spread(_ ts: [Touch]) -> Double {
        let cx = ts.map { Double($0.pt.x) }.reduce(0, +) / Double(ts.count)
        let cy = ts.map { Double($0.pt.y) }.reduce(0, +) / Double(ts.count)
        return ts.map { hypot(Double($0.pt.x) - cx, Double($0.pt.y) - cy) }.reduce(0, +) / Double(ts.count)
    }
}

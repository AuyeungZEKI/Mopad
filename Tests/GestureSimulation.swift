// Mopad 手势识别仿真测试：向 GestureEngine 注入合成触点帧，校验识别结果（不执行任何真实点击）
// 运行：./Scripts/run-tests.sh
import Foundation

@main struct GestureSimulation {
    typealias P = (Int32, Double, Double)   // (触点 id, x 毫米, y 毫米)

    static var got: [String] = []
    static var seen = Date.distantPast
    static var nid: Int32 = 10
    static var failures = 0

    static func main() {
        Actions.dryRun = true
        var c = GestureConfig()
        c.pinch3Ratio = 0.84; c.pinch3ShrinkMM = 4      // 与默认灵敏度一致
        GestureEngine.shared.config = c
        GestureEngine.shared.onStatus = { st in
            if st.lastGestureTime > seen { seen = st.lastGestureTime; got.append(st.lastGesture) }
        }

        let tri: [P] = [(1, 12, 62), (2, 25, 68), (3, 38, 62)]

        print("单指轻点")
        expect("单指轻点 100ms", ["点按"]) { hold([(id(), 25, 60)], 100) }
        expect("单指轻点两下", ["点按", "连按"]) { hold([(id(), 25, 60)], 90); lift(); hold([(id(), 25.3, 60.2)], 90) }
        expect("中指搭着，食指轻点", ["点按"]) {
            let r = id(); hold([(r, 33, 50)], 600); let t = id()
            hold([(r, 33, 50), (t, 20, 62)], 100); hold([(r, 33, 50)], 200)
        }
        expect("单指按住 400ms", []) { hold([(id(), 25, 60)], 400) }
        expect("单指轻扫 3mm", []) { let i = id(); for k in 0..<9 { frame([(i, 25, 60 + Double(k) * 0.4)]) } }
        expect("双指轻点", []) { hold([(id(), 18, 60), (id(), 32, 60)], 100) }

        print("三指轻触")
        expect("三指轻触", ["右键"]) { hold(fresh(tri), 130) }

        print("三指捏合")
        expect("收拢 18%", ["应用程序索引"]) { let b = fresh(tri); for i in 0...30 { frame(scaled(1 - 0.18 * Double(i) / 30, b)) } }
        expect("先张开 10% 再收拢 15%", ["应用程序索引"]) {
            let b = fresh(tri)
            for i in 0...15 { frame(scaled(1 + 0.1 * Double(i) / 15, b)) }
            for i in 0...25 { frame(scaled(1.1 - 0.25 * Double(i) / 25, b)) }
        }
        expect("收拢 20%，中途丢指 3 帧", ["应用程序索引"]) {
            let b = fresh(tri)
            for i in 0...30 { let p = scaled(1 - 0.2 * Double(i) / 30, b); frame(i >= 10 && i < 13 ? Array(p.prefix(2)) : p) }
        }
        expect("拇指 + 三指 收拢 18%", ["应用程序索引"]) {
            let b = fresh(tri + [(4, 25, 30)]); for i in 0...30 { frame(scaled(1 - 0.18 * Double(i) / 30, b)) }
        }
        expect("只收拢 8%", []) { let b = fresh(tri); for i in 0...30 { frame(scaled(1 - 0.08 * Double(i) / 30, b)) } }
        expect("三指整体平移", []) { let b = fresh(tri); for i in 0...40 { frame(b.map { ($0.0, $0.1, $0.2 - Double(i) * 0.5) }) } }
        expect("三指静置抖动 1 秒", []) {
            let b = fresh(tri)
            for _ in 0...90 { frame(b.map { ($0.0, $0.1 + Double.random(in: -0.4...0.4), $0.2 + Double.random(in: -0.4...0.4)) }) }
        }

        print("双指缩放")
        expect("双指张开", ["放大"]) { let a = id(), b = id(); for i in 0...30 { let d = 8 + Double(i) * 0.4; frame([(a, 25 - d, 55), (b, 25 + d, 55)]) } }
        expect("双指捏合", ["缩小"]) { let a = id(), b = id(); for i in 0...30 { let d = 18 - Double(i) * 0.4; frame([(a, 25 - d, 55), (b, 25 + d, 55)]) } }
        expect("双指同向滚动", []) { let a = id(), b = id(); for i in 0...30 { frame([(a, 18, 50 + Double(i) * 0.6), (b, 32, 50 + Double(i) * 0.6)]) } }

        print(failures == 0 ? "\n✓ 全部通过" : "\n✗ \(failures) 项失败")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: 工具

    static func id() -> Int32 { nid += 1; return nid }
    static func fresh(_ pts: [P]) -> [P] { pts.map { (id(), $0.1, $0.2) } }

    static func frame(_ pts: [P]) {
        GestureEngine.shared.process(pts.map {
            Touch(id: $0.0, state: 5, nx: $0.1 / 51.5, ny: $0.2 / 90.6, pt: CGPoint(x: $0.1, y: $0.2))
        })
        usleep(11_000)   // ≈ 90 Hz
    }
    static func hold(_ pts: [P], _ ms: Int) { for _ in 0..<(ms / 11) { frame(pts) } }
    static func lift() { for _ in 0..<5 { frame([]) } }

    static func scaled(_ k: Double, _ pts: [P]) -> [P] {
        let cx = pts.map { $0.1 }.reduce(0, +) / Double(pts.count)
        let cy = pts.map { $0.2 }.reduce(0, +) / Double(pts.count)
        return pts.map { ($0.0, cx + ($0.1 - cx) * k, cy + ($0.2 - cy) * k) }
    }

    static func expect(_ name: String, _ keywords: [String], _ body: () -> Void) {
        got = []
        body(); lift()
        usleep(700_000)   // 越过连按间隔，避免与下一场景串联
        let ok = got.count == keywords.count && zip(got, keywords).allSatisfy { $0.contains($1) }
        if !ok { failures += 1 }
        let result = got.isEmpty ? "（无触发）" : got.joined(separator: " / ")
        print("  \(ok ? "✓" : "✗") \(name) → \(result)")
    }
}

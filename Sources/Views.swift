import SwiftUI

// MARK: - iOS 风格组件

/// iOS 风格开关：绿色胶囊 + 白色圆钮
struct IOSSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(configuration.isOn ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color(white: 0.86))
                    .frame(width: 38, height: 23)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    .frame(width: 19, height: 19)
                    .padding(2)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
            .contentShape(Capsule())
            .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

struct IconBadge: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.gradient))
    }
}

struct RowLabel: View {
    let title: String
    var subtitle: String? = nil
    let symbol: String
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

struct SliderRow: View {
    let title: String
    let symbol: String
    let color: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    var minLabel = "慢"
    var maxLabel = "快"
    var reversed = false
    var onCommit: (Double) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RowLabel(title: title, symbol: symbol, color: color)
            HStack(spacing: 8) {
                Text(minLabel).font(.caption).foregroundStyle(.secondary).frame(width: 28)
                Slider(value: reversed ? Binding(get: { range.upperBound + range.lowerBound - value },
                                                 set: { value = range.upperBound + range.lowerBound - $0 }) : $value,
                       in: range)
                    .controlSize(.small)
                Text(maxLabel).font(.caption).foregroundStyle(.secondary).frame(width: 28)
            }
        }
        .padding(.vertical, 2)
        .onChange(of: value) { _, v in onCommit(v) }
    }
}

// MARK: - 权限行

struct PermissionRow: View {
    let title: String
    let detail: String
    let ok: Bool
    var body: some View {
        HStack {
            RowLabel(title: title, subtitle: detail,
                     symbol: ok ? "checkmark.shield.fill" : "lock.shield.fill", color: ok ? .green : .orange)
            Spacer()
            Text(ok ? "已就绪" : "未授权")
                .font(.caption.weight(.medium))
                .foregroundStyle(ok ? Color.green : Color.orange)
        }
    }
}

// MARK: - 实时触控预览

struct TouchPreview: View {
    let points: [CGPoint]
    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.90)], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule(style: .continuous).strokeBorder(Color.black.opacity(0.08)))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            GeometryReader { geo in
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    Circle()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: 14, height: 14)
                        .position(x: p.x * geo.size.width, y: (1 - p.y) * geo.size.height)
                }
            }
            .padding(6)
        }
        .frame(width: 58, height: 96)
        .animation(.easeOut(duration: 0.08), value: points.count)
    }
}

// MARK: - 主设置页

struct SettingsView: View {
    @ObservedObject var s = AppState.shared

    var body: some View {
        Form {
            header

            if !s.permissionsOK {
                Section {
                    PermissionRow(title: "辅助功能", detail: "模拟右键、点按与缩放", ok: s.trusted)
                    PermissionRow(title: "事件发送", detail: "向系统发送合成的鼠标/键盘事件", ok: s.postAccess)
                    PermissionRow(title: "事件监听", detail: "识别物理点击、缩放时屏蔽滚动", ok: s.tapRunning)
                    HStack {
                        Button("去授权") { s.requestAccessibility() }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                        Button("重新启动 Mopad") { s.relaunch() }
                            .controlSize(.small)
                        Spacer()
                    }
                } header: { Text("权限") } footer: {
                    Text("若列表里 Mopad 已开启但这里仍显示未授权：在「辅助功能」列表中选中 Mopad，点「−」移除，再点「去授权」重新添加。授权完成后 Mopad 会自动重启。")
                }
            }

            Section {
                Toggle(isOn: $s.oneTapEnabled) {
                    RowLabel(title: "单指轻点以点按", subtitle: "轻点一下 = 点按，轻点两下 = 连按", symbol: "hand.point.up.fill", color: .blue)
                }
                if s.oneTapEnabled && s.smartZoom {
                    HStack {
                        RowLabel(title: "与「智能缩放」冲突", subtitle: "单指轻点两下会同时触发缩放",
                                 symbol: "exclamationmark.triangle.fill", color: .orange)
                        Spacer()
                        Button("关闭智能缩放") {
                            s.smartZoom = false
                            MouseSettings.setSmartZoom(false)
                        }
                        .controlSize(.small)
                    }
                }

                Toggle(isOn: $s.tapEnabled) {
                    RowLabel(title: "三指轻触", subtitle: "辅助点按（右键）", symbol: "hand.tap.fill", color: .indigo)
                }
                if s.tapEnabled {
                    SliderRow(title: "轻触判定时长", symbol: "timer", color: .gray,
                              value: $s.tapMaxDuration, range: 0.18...0.50, minLabel: "短", maxLabel: "长")
                }

                Toggle(isOn: $s.pinch3Enabled) {
                    RowLabel(title: "三指捏合", subtitle: "三指或拇指＋三指轻轻收拢 · 打开\(s.pinch3Action.title)", symbol: "square.grid.3x3.fill", color: .purple)
                }
                if s.pinch3Enabled {
                    Picker(selection: $s.pinch3Action) {
                        ForEach(PinchAction.allCases) { Text($0.title).tag($0) }
                    } label: { RowLabel(title: "捏合后打开", symbol: "arrow.up.forward.app.fill", color: .indigo) }
                    SliderRow(title: "捏合灵敏度", symbol: "dial.medium.fill", color: .gray,
                              value: $s.pinch3Sensitivity, range: 0...1, minLabel: "低", maxLabel: "高")
                }

                Toggle(isOn: $s.zoomEnabled) {
                    RowLabel(title: "双指捏合 / 张开", subtitle: "缩小 / 放大", symbol: "plus.magnifyingglass", color: .green)
                }
                if s.zoomEnabled {
                    Picker(selection: $s.zoomMode) {
                        ForEach(ZoomMode.allCases) { Text($0.title).tag($0) }
                    } label: { RowLabel(title: "缩放方式", symbol: "slider.horizontal.3", color: .teal) }
                    SliderRow(title: "触发灵敏度", symbol: "dial.medium.fill", color: .gray,
                              value: $s.zoomSensitivity, range: 0...1, minLabel: "低", maxLabel: "高")
                    SliderRow(title: "缩放速度", symbol: "speedometer", color: .gray,
                              value: $s.zoomSpeed, range: 0.5...3.5)
                }
            } header: { Text("触控手势") }

            Section {
                SliderRow(title: "跟踪速度", symbol: "cursorarrow.motionlines", color: .blue,
                          value: $s.trackingSpeed, range: 0...3) { MouseSettings.setTrackingSpeed($0) }
                SliderRow(title: "滚动速度", symbol: "scroll.fill", color: .cyan,
                          value: $s.scrollSpeed, range: 0...1) { MouseSettings.setScrollSpeed($0) }
                SliderRow(title: "连按速度", symbol: "cursorarrow.click.2", color: .mint,
                          value: $s.doubleClick, range: 0.15...2.0, reversed: true) { MouseSettings.setDoubleClickInterval($0) }

                Toggle(isOn: $s.naturalScroll) {
                    RowLabel(title: "自然滚动", subtitle: "内容跟随手指方向移动", symbol: "arrow.up.and.down", color: .orange)
                }
                .onChange(of: s.naturalScroll) { _, v in MouseSettings.setNaturalScroll(v) }

                Picker(selection: $s.secondaryClick) {
                    ForEach(SecondaryClick.allCases) { Text($0.title).tag($0) }
                } label: { RowLabel(title: "辅助点按", symbol: "computermouse.fill", color: .pink) }
                .onChange(of: s.secondaryClick) { _, v in MouseSettings.setSecondaryClick(v) }

                Toggle(isOn: $s.smartZoom) {
                    RowLabel(title: "智能缩放", subtitle: "单指连按两下", symbol: "magnifyingglass", color: .yellow)
                }
                .onChange(of: s.smartZoom) { _, v in MouseSettings.setSmartZoom(v) }
            } header: { Text("鼠标") } footer: { Text("与「系统设置 › 鼠标」同步，修改即时生效。") }

            Section {
                Toggle(isOn: $s.pageSwipe) {
                    RowLabel(title: "在页面间轻扫", subtitle: "单指左右轻扫", symbol: "arrow.left.arrow.right", color: .blue)
                }
                .onChange(of: s.pageSwipe) { _, v in MouseSettings.setPageSwipe(v) }
                Toggle(isOn: $s.fullscreenSwipe) {
                    RowLabel(title: "在全屏应用间轻扫", subtitle: "双指左右轻扫", symbol: "rectangle.on.rectangle", color: .indigo)
                }
                .onChange(of: s.fullscreenSwipe) { _, v in MouseSettings.setFullscreenSwipe(v) }
                Toggle(isOn: $s.missionControlTap) {
                    RowLabel(title: "调度中心", subtitle: "双指连按两下", symbol: "square.grid.2x2.fill", color: .gray)
                }
                .onChange(of: s.missionControlTap) { _, v in MouseSettings.setMissionControlTap(v) }
            } header: { Text("系统手势") } footer: { Text("若双指缩放时容易误触切换全屏应用，可关闭「在全屏应用间轻扫」。") }

            Section {
                Toggle(isOn: Binding(get: { s.launchAtLogin }, set: { s.setLaunchAtLogin($0) })) {
                    RowLabel(title: "登录时打开", symbol: "power", color: .gray)
                }
                Button {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Mouse-Settings.extension")!)
                } label: {
                    HStack {
                        RowLabel(title: "打开系统鼠标设置", symbol: "gearshape.fill", color: .gray)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } header: { Text("通用") }
        }
        .formStyle(.grouped)
        .toggleStyle(IOSSwitchStyle())
        .frame(width: 460)
        .frame(minHeight: 560)
        .onAppear { s.reloadMouseSettings() }
    }

    private var header: some View {
        Section {
            HStack(spacing: 16) {
                TouchPreview(points: s.touchPoints)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mopad").font(.system(size: 22, weight: .bold, design: .rounded))
                    HStack(spacing: 6) {
                        Circle().fill(s.mouseName != nil ? Color.green : Color.secondary).frame(width: 7, height: 7)
                        Text(s.mouseName.map { "\($0) 已连接" } ?? "未检测到妙控鼠标")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Text(s.live.lastGesture)
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(spacing: 8) {
                    Toggle("", isOn: $s.enabled).labelsHidden()
                    if s.mouseName == nil {
                        Button("重新扫描") { s.rescan() }.controlSize(.small)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - 菜单栏

struct MenuContent: View {
    @ObservedObject var s = AppState.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("启用 Mopad", isOn: $s.enabled)
        Toggle("单指轻点以点按", isOn: $s.oneTapEnabled)
        Divider()
        Text(s.mouseName.map { "\($0) 已连接" } ?? "未检测到妙控鼠标")
        if !s.permissionsOK {
            Button("⚠︎ 权限未就绪，去授权…") { s.requestAccessibility() }
            Button("重新启动 Mopad") { s.relaunch() }
        }
        Divider()
        Button("设置…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }.keyboardShortcut(",")
        Button("退出 Mopad") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

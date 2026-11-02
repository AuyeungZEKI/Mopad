<p align="center">
  <img src="assets/icon.png" width="128" alt="Mopad">
</p>

<h1 align="center">Mopad</h1>

<p align="center">
  <b>让妙控鼠标，像触控板一样会意。</b><br>
  <sub>Trackpad gestures for your Magic Mouse.</sub>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Apple silicon" src="https://img.shields.io/badge/Apple%20silicon-native-blue">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

<p align="center">
  <a href="#简体中文">简体中文</a> · <a href="#english">English</a>
</p>

<p align="center">
  <img src="assets/og.png" width="720" alt="Mopad">
</p>

---

## 简体中文

Mopad 是一款让妙控鼠标更好用的 macOS 小工具。

妙控鼠标的整个顶面都是多点触控表面，但 macOS 只让它滚动和轻扫。Mopad 把触控板上那些早已长进肌肉记忆的动作——**轻点**、**右键**、**捏合**、**缩放**——原样带到妙控鼠标上。完全免费，源码公开。

想直观地看看 Mopad 能做什么，请访问 [官网](https://YOUR-DOMAIN)，那里有可交互的手势演示。

### 功能

| 手势 | 动作 | 在触控板上相当于 |
|---|---|---|
| 单指轻点 | 点按 | 轻点来点按 |
| 单指轻点两下 | 连按（节奏跟随系统「连按速度」） | 轻点两下 |
| 三指轻触 | 辅助点按（右键） | 双指点按 |
| 三指捏合 | 打开应用程序索引，也可改为调度中心 / 聚焦搜索 / 显示桌面 | 拇指与三指合拢 |
| 双指张开 · 捏合 | 放大 · 缩小（原生平滑缩放，或 ⌘+ / ⌘− 快捷键模式） | 双指捏合 |

- **防误触**：只认「快落快起」的轻点；物理点击、光标移动、滚动期间的触碰不算点按；缩放后 0.6 秒内屏蔽滚动与全屏轻扫；三指捏合容许 0.15 秒丢指。
- **系统鼠标设置**：跟踪速度、滚动速度、连按速度、自然滚动、辅助点按、智能缩放、页面轻扫、全屏应用轻扫、调度中心，与「系统设置 › 鼠标」双向同步。
- **其他**：常驻菜单栏，登录时打开；鼠标重连、系统唤醒后自动重新识别；三项权限状态检测，授权后自动重启。

更多细节见 [更新日志](https://github.com/AuyeungZEKI/Mopad/releases)。

### 安装

在官网或 [Releases](https://github.com/AuyeungZEKI/Mopad/releases) 下载最新的 `Mopad-x.y.z.dmg`，打开后把 Mopad 拖进「应用程序」。

1. **首次打开**：发布包为自签名、尚未经 Apple 公证。请在访达中 **右键 Mopad › 打开**，或在终端执行：
   ```bash
   xattr -dr com.apple.quarantine /Applications/Mopad.app
   ```
2. **授予权限**：前往 **系统设置 › 隐私与安全性 › 辅助功能**，打开 Mopad。授权后它会自动重启，设置页顶部的权限提示消失即就绪。

### macOS 兼容性

Mopad 适用于 **macOS 14** 及以上、搭载 **Apple 芯片**的 Mac，并在 macOS 26 与 USB-C 版妙控鼠标上测试。

### 价格

免费。以 [MIT 许可](LICENSE) 开源。

### 卸载

在 Mopad 中关闭「登录时打开」，从菜单栏退出，再把 Mopad 拖到废纸篓。如需清理残留文件：

```bash
rm -rf ~/Library/Application\ Support/Mopad
defaults delete com.zeki.mopad
```

最后在「辅助功能」列表中移除 Mopad。也可以使用 [AppCleaner](https://freemacsoft.net/appcleaner/) 一并清理。

### 小技巧

- **开启单指轻点时，关掉系统「智能缩放」**
  系统的智能缩放同样响应「单指轻点两下」，两者同时开启时连按会触发缩放。Mopad 设置页会给出一键关闭按钮。
- **某个应用不响应双指缩放**
  「原生捏合」通过合成触控板手势事件实现，个别应用不接受。把「缩放方式」切换为「⌘+ / ⌘− 快捷键」，几乎所有应用都能缩放。
- **缩放时误切换了全屏应用**
  在 Mopad 的「系统手势」中关闭「在全屏应用间轻扫」。

### 常见问题

- **会影响我的触控板吗？**
  不会。Mopad 按设备类型只监听妙控鼠标。
- **为什么需要「辅助功能」权限？**
  合成点按、右键与缩放，以及识别物理点击、缩放时暂停滚动，都需要这项权限。
- **Mopad 会收集我的数据吗？**
  不会。Mopad 不联网、不收集任何数据；触点只在本机内存中逐帧处理。
- **已经授权，却仍提示未授权？**
  在「辅助功能」列表中选中 Mopad，点「−」移除，再在 Mopad 里点「去授权」重新添加。
- **能在 Mac App Store 下载吗？**
  不能。读取妙控鼠标触点需要使用 macOS 私有框架，无法上架；macOS 大版本更新后也可能需要适配。
- **支持 Intel Mac 吗？**
  暂不支持，Universal Binary 已在路线图中。

### 路线图

- [ ] 双指左右轻扫 = 前进 / 后退
- [ ] 手势自定义映射
- [ ] Universal Binary（Intel 支持）
- [ ] Developer ID 签名与公证

### 参与贡献

- **反馈**：在 [Issues](https://github.com/AuyeungZEKI/Mopad/issues) 分享你的想法、问题与手感反馈。
- **代码**：欢迎提交 [Pull Request](https://github.com/AuyeungZEKI/Mopad/pulls)。较大的改动建议先开一个只描述思路的 PR 或 Issue，方便提前讨论。
- **翻译**：官网目前提供简体中文与英文，欢迎补充其他语言。

### 致谢

思路参考了 [BetterTouchTool](https://folivora.ai/)、[Jitouch](https://github.com/JitouchApp/Jitouch-project)、[MiddleClick](https://github.com/artginzburg/MiddleClick)、[Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix)。

### 网站开发与部署

本仓库即 Mopad 官网，为纯静态页面，无需构建。

```
├── index.html            # 页面（中英双语，?lang=en 可直接打开英文）
├── assets/
│   ├── style.css
│   ├── app.js            # 丝线背景、滚动手势叙事、可操作的设置窗口、语言切换
│   ├── icon.png · favicon.png · apple-touch-icon.png · og.png
├── downloads/            # 安装包与 SHA-256
├── vercel.json           # 下载响应头、/download 与 /github 短链接
└── LICENSE
```

**本地预览**

```bash
python3 -m http.server 8000   # 打开 http://localhost:8000
```

**部署到 Vercel**

1. 把本目录推送为 GitHub 仓库。
2. 在 Vercel 中 **Add New › Project**，导入该仓库；Framework Preset 选 **Other**，构建命令与输出目录留空。
3. 部署完成后，在 **Settings › Domains** 添加你的域名，并按提示在域名服务商处添加 DNS 记录（根域名用 `A` 记录，子域名用 `CNAME`）。
4. 建议把 `index.html` 中的 `og:image` 改为带域名的绝对地址，社交平台分享卡片才能正确显示。

**发布新版本时**

1. 把新的 `Mopad-x.y.z.dmg` 与 `.sha256` 放进 `downloads/`。
2. 更新 `assets/app.js` 顶部的 `CONFIG.version`、`index.html` 中的下载链接与 SHA-256、`vercel.json` 中的 `/download` 目标。

### 许可证

[MIT](LICENSE) © 2026 Zeki

---

## English

Mopad is a small macOS app that makes your Magic Mouse better.

The entire top of the Magic Mouse is a multi-touch surface, yet macOS only lets it scroll and swipe. Mopad brings the trackpad moves that live in your muscle memory — **tap**, **right-click**, **pinch** and **zoom** — to the Magic Mouse, just as they are. It's free and open source.

For a hands-on look at what Mopad can do, visit the [website](https://YOUR-DOMAIN), which features interactive gesture demos.

### Features

| Gesture | Action | Trackpad equivalent |
|---|---|---|
| One-finger tap | Click | Tap to click |
| One-finger double tap | Double-click (follows your system double-click speed) | Double tap |
| Three-finger tap | Secondary click (right-click) | Two-finger click |
| Three-finger pinch | Open Apps — or Mission Control / Spotlight / Show Desktop | Pinch with thumb and three fingers |
| Two-finger spread · pinch | Zoom in · out (native smooth zoom, or ⌘+ / ⌘− shortcut mode) | Pinch to zoom |

- **Accidental-touch protection**: only quick taps count; touches during physical clicks, pointer movement or scrolling aren't clicks; scrolling and full-screen swipes are held for 0.6 s after zooming; pinches tolerate a 0.15 s finger dropout.
- **System mouse settings**: tracking speed, scrolling speed, double-click speed, natural scrolling, secondary click, Smart Zoom, swipe between pages, swipe between full-screen apps and Mission Control — synced both ways with System Settings › Mouse.
- **More**: lives in the menu bar and opens at login; finds the mouse again after reconnecting or waking; checks all three permissions and relaunches itself once granted.

See the [Releases](https://github.com/AuyeungZEKI/Mopad/releases) for details.

### Installation

Download the latest `Mopad-x.y.z.dmg` from the website or [Releases](https://github.com/AuyeungZEKI/Mopad/releases), open it, and drag Mopad into Applications.

1. **First launch**: the app is self-signed and not yet notarized by Apple. **Right-click Mopad in Finder › Open**, or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Mopad.app
   ```
2. **Grant permission**: go to **System Settings › Privacy & Security › Accessibility** and turn on Mopad. It relaunches automatically and is ready once the permission notice disappears.

> The Mopad app interface is currently in Simplified Chinese.

### macOS compatibility

Mopad is made for Macs with **Apple silicon** running **macOS 14** or later. It is tested on macOS 26 with the USB-C Magic Mouse.

### Pricing

Free. Open source under the [MIT License](LICENSE).

### Uninstallation

Turn off "Open at Login" in Mopad, quit it from the menu bar, then move it to the Trash. To remove leftover files:

```bash
rm -rf ~/Library/Application\ Support/Mopad
defaults delete com.zeki.mopad
```

Finally, remove Mopad from the Accessibility list. [AppCleaner](https://freemacsoft.net/appcleaner/) works well too.

### Tips

- **Turn off Smart Zoom when using tap to click**
  The system's Smart Zoom also responds to a one-finger double tap, so double-clicking would zoom as well. Mopad's settings offer a one-click button to turn it off.
- **An app doesn't respond to pinch to zoom**
  Native pinch works by synthesizing trackpad gesture events, which a few apps ignore. Switch the zoom mode to "⌘+ / ⌘− shortcut" — it works almost everywhere.
- **Zooming sometimes switches full-screen apps**
  Turn off "Swipe between full-screen apps" under System Gestures in Mopad.

### Questions

- **Will it affect my trackpad?**
  No. Mopad only listens to the Magic Mouse, by device type.
- **Why does it need Accessibility access?**
  Posting clicks, right-clicks and zooms — and detecting physical clicks or pausing scrolling during a zoom — all require it.
- **Does Mopad collect my data?**
  No. Mopad never goes online and collects no data; touches are processed frame by frame in memory.
- **I granted access but it still says it's missing**
  Select Mopad in the Accessibility list, click "−" to remove it, then use the grant button in Mopad to add it again.
- **Is it on the Mac App Store?**
  No. Reading Magic Mouse touches requires a private macOS framework, which the App Store doesn't allow. Major macOS updates may require an update to Mopad.
- **Does it support Intel Macs?**
  Not yet — a Universal Binary is on the roadmap.

### Roadmap

- [ ] Two-finger swipe left / right = back / forward
- [ ] Custom gesture mapping
- [ ] Universal Binary (Intel support)
- [ ] Developer ID signing and notarization

### How you can contribute

- **Feedback**: share ideas, issues and how the gestures feel in [Issues](https://github.com/AuyeungZEKI/Mopad/issues).
- **Code**: [pull requests](https://github.com/AuyeungZEKI/Mopad/pulls) are welcome. For larger changes, consider opening an issue or a PR that only describes the idea first, so we can discuss it early.
- **Translations**: the website is available in Simplified Chinese and English; more languages are welcome.

### Acknowledgements

Inspired by [BetterTouchTool](https://folivora.ai/), [Jitouch](https://github.com/JitouchApp/Jitouch-project), [MiddleClick](https://github.com/artginzburg/MiddleClick) and [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix).

### Website development & deployment

This repository is the Mopad website — plain static files, no build step.

```
├── index.html            # The page (Chinese & English; open ?lang=en for English)
├── assets/
│   ├── style.css
│   ├── app.js            # Silk background, scroll-driven gesture story, live settings window, language switch
│   ├── icon.png · favicon.png · apple-touch-icon.png · og.png
├── downloads/            # Installer and SHA-256
├── vercel.json           # Download headers, /download and /github short links
└── LICENSE
```

**Preview locally**

```bash
python3 -m http.server 8000   # then open http://localhost:8000
```

**Deploy to Vercel**

1. Push this folder as a GitHub repository.
2. In Vercel, choose **Add New › Project** and import the repository. Set Framework Preset to **Other** and leave the build command and output directory empty.
3. Once deployed, add your domain under **Settings › Domains** and create the DNS records shown (an `A` record for an apex domain, a `CNAME` for a subdomain).
4. Change `og:image` in `index.html` to an absolute URL on your domain so link previews render correctly.

**When releasing a new version**

1. Put the new `Mopad-x.y.z.dmg` and `.sha256` into `downloads/`.
2. Update `CONFIG.version` at the top of `assets/app.js`, the download link and SHA-256 in `index.html`, and the `/download` target in `vercel.json`.

### License

[MIT](LICENSE) © 2026 Zeki

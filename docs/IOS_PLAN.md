# Mineradio iOS / iPad 客户端方案与上线规划

> 维护者：swording-k（iOS 端负责人）｜最后更新：2026-10-26
>
> 本文是 iOS / iPad 客户端的技术方案与下一版上线规划。目标：把 iOS 端做成与桌面「同一个产品的不同客户端」，视觉效果和功能对齐桌面，并解决当前阻塞上线的核心问题。
>
> 结论先行的原则：构建成功 ≠ 功能验收；模拟器通过 ≠ 真机通过；TestFlight 过审 ≠ 全功能可用。本文所有「现状」均基于仓库代码核实，标注「待验收 / 待验证」的尚未得到真机证据。

---

## 0. 背景与定位

- Mineradio 是沉浸式音乐播放器，核心是 `public/` 里的网页 UI 与视觉引擎（歌词舞台、粒子、3D 歌单架、基于节奏的电影镜头）。产品定位要求 **iOS 端视觉与桌面完全一致**。
- **视觉引擎复用、不重写**：那套 canvas/WebGL 视觉引擎是产品灵魂，由原作者/团队维护，iOS 端直接复用（WebView 承载），原生层不重做视觉。
- 四端同源：Windows（Electron）、Mac（Electron）、Android（Kotlin 壳 + H5 视觉 + libnode 跑 JS 音源 + C++ 原生）、Web。iOS 端是其中一端。

### 三端架构对照（决定 iOS 走法）

| 端 | 界面 | 视觉引擎 | 音源逻辑（含汽水签名） | 重活承载 |
| --- | --- | --- | --- | --- |
| Windows/Mac | 网页 | canvas/WebGL | Node（Electron 内） | 整台电脑 |
| Android | Kotlin 原生壳 + 纯横屏 H5 | H5 内的 canvas/WebGL | **内置 libnode 跑原版 JS**（含 `bdms.js` 签名、`SodaCrypto` 解密） | 原生 C++ / 独立进程 / largeHeap |
| **iOS（现状）** | WKWebView 全套壳 + Apple 适配层 | WebView 内 canvas/WebGL | **Swift 重写**（网易/QQ/酷狗部分重写；汽水整轨签名缺失） | 全压在一个 WebView/App 进程 |
| **iOS（目标）** | Swift 原生壳 + 交互 + WebView 承载视觉 | WebView 内 canvas/WebGL（复用） | Swift 原生 + **JavaScriptCore 跑关键 JS（汽水签名）** | 原生接管音频/解密/内存治理 |

**核心判断**：安卓已验证「原生壳 + H5 视觉 + JS 跑音源签名」可行。iOS 应对齐这个思路的 iOS 版——**保留 WebView 承载视觉以保证视觉一致，把重活（音频、解密、内存、交互）下沉到 Swift 原生，把无法重写的字节签名 SDK 放到 JavaScriptCore 里跑**。这样既满足「视觉同等效果」，又能根治性能与汽水播放。

---

## 1. 当前核心问题清单（按优先级）

### P0 — 资源占用 / 闪退 / 黑屏

**现象**：资源容易占满，低配设备闪退、黑屏、提示资源不足。

**根因（已核实）**：
- 整个产品（视觉引擎 + 音频解码 + 歌词 + 全部逻辑）都压在一个 WKWebView 的 WebContent 进程里。`apps/apple/README.md` 记录过 WebContent 内存峰值约 1249 MiB、GPU 进程 highwater 约 303 MiB，老 iPad 会被系统杀进程重启。
- iOS 端目前**只有内存「记录」没有「治理」**：`AppleDiagnostics.swift` 记录内存警告和 host footprint；`OriginalPlayerView.swift` 只监听 `didReceiveMemoryWarning` 写日志。**没有**主动降载、缓存驱逐、进程隔离、整轨解码下沉等治理手段。
- 对照安卓：`largeHeap=true`、壁纸渲染放独立进程 `:wallpaper`、`PerformanceMonitor`（内存/帧率/掉帧/ANR 监控）、`CrashHandler`。iOS 这些几乎都没有对应物。

### P0 — 汽水（Qishui/Soda）播放：整轨签名问题

**现象**：iOS 测试版汽水播不了。用户反馈「能登录但播不了」。

**根因（已核实，分两层，务必区分）**：
1. **登录层**：扫码登录会遇到字节的安全验证挑战（`error_code 2046`）与接口限流（截图「汽水确认接口限流，15 秒后自动重试」）。iOS 端 `QishuiSecurityFlow.swift` + `OfficialAccountLogin.swift` 已处理 MFA 挑战流程。
2. **播放层（真正命门，2026-10-26 核实后修正）**：

   > ⚠ **重大修正**：此前假设「iOS 汽水播不了 = 整轨签名/平台标识没做对」。深入对照安卓源码后发现**不准确**。真实根因如下。

   - **汽水官方已把 `/luna/pc/track_v2`（PC 整轨接口）对第三方接入关闭**（返回 200 空 body）。安卓源码明确注释：`// 汽水官方已将 /luna/pc/track_v2 对第三方接入关闭`、`// 回退到免登录的 seo_track 接口`。
   - 这意味着：**无论把 `device_platform` 设成 windows 还是 mac、无论签名对不对，走 `track_v2` 这条路现在都拿不到整轨**。负责人当年在 Mac 上「改签名就能播」，是那个时间点的情况；之后官方封了这条路。
   - **安卓现在能播，靠的是回退链路**：
     1. `track_v2` 失败 → 回退 `seo_track`（免登录 SEO 接口）；
     2. `seo_track` 返回 `track_player.url_player_info`，这是一个 **VOD GetPlayInfo 签名地址**；
     3. 用它调 `PlayerInfo` 换取**可直接播放的标准 M4A 音源**（带 auth）；
     4. 配合会员权益判定区分 VIP 整轨 / 试听。
   - **iOS 现状缺口**：`QishuiCatalogAPI.swift` 的 `/api/qishui/song/url` 在 `track_v2` 失败后，直接降级到 `publicTrack`（公开试听），**没有 `seo_track → url_player_info → PlayerInfo` 这条回退链**。这才是 iOS「能登录但只能试听 / 播不了」的真正原因——**不是签名问题，是缺了 seo_track 回退播放链路**。
   - 登录层的 `bdms` 签名 iOS 其实已经跑通：`QishuiAuthRuntime.swift` 已用 WKWebView 加载 `security_host.html` + `sdk-glue.js` + `bdms.js`，等 `window.bdms` 就绪。所以「用 WebView 跑 bdms」这条已验证可行，不是本阶段难点。

**iOS 修复方向（照搬安卓已验证的链路）**：在 `QishuiCatalogAPI` 的播放解析里，补上 `track_v2` 失败后的 `seo_track` 回退：取 `track_player.url_player_info` → 请求 PlayerInfo → 得到可播 M4A → 带权益判定返回。对照安卓 `qishui-api.js` 的 `resolveQishuiSeoPlayback` / `handleQishuiSongUrl` / `fetchQishuiSeoTrack` / `fetchQishuiPlayerInfo`。

### P1 — 交互体验（手机端按钮位置 / 可用性差）

**现象**：手机端按钮摆放有问题，使用体验差。

**根因（已核实）**：现状是用「Apple 适配层」(`AppleLayoutSmoke` 等 + `apps/apple/Web/` 里的 JS）去覆盖桌面网页 CSS，在窄屏重新编排控件。桌面 popup/transform 在窄屏残留，触控兼容事件引发 hover 泄漏等问题，`apps/apple/README.md` 的 0.4.2~0.4.6 记录了反复修补。本质是「用网页 CSS 凑触屏布局」，调不干净。安卓的做法是界面用 Kotlin 原生、H5 只做视觉，不靠网页 CSS 适配手机。

### P1 — Spotify 适配（已写未验收）

**现状（已核实）**：iOS 端 Spotify **代码其实较完整**——`SpotifyNativeAPI.swift`（~19KB）、`SpotifyContract.swift`（完整 OAuth PKCE、库/搜索/分页合约）、`apps/apple/Web/apple-spotify.js`（把 spotify 重新注入前端 provider 合约）。但 iOS README 说「这个 Apple 构建里 Spotify 仍缺失」，且 `SpotifyContract.song` 里 `playable: false`。
**结论**：Spotify 不是没做，而是**未接入 / 未验收 / 播放未打通**。需要确认接入状态、补 client_id 配置、验证真实账号播放。安卓也有 `spotify-api.js` 可对照。

### P2 — Mac 客户端汽水登录不上（本次不处理，单独提 Issue）

官网当前 Mac 客户端汽水**登录都过不了**（比播放更靠前的问题），与 iOS 的播放签名是不同问题。按负责人决定：**先提 Issue 挂着，后续有时间再修**，不纳入本次 iOS 上线方案。详见第 6 节。

---

## 2. iOS 目标架构

分层目标：**原生做重活与交互，WebView 只承载视觉引擎，JavaScriptCore 补不可重写的签名 JS。**

```
┌─────────────────────────────────────────────┐
│  Swift 原生外壳 (SwiftUI / UIKit)             │
│   · 导航 / 页面 / 手机端控件布局（原生，不靠网页CSS）│
│   · 内存治理：主动降载 / 缓存驱逐 / 低配降级        │
│   · 崩溃与性能监控（对标安卓 PerformanceMonitor）    │
├─────────────────────────────────────────────┤
│  视觉层：WKWebView 承载原版 canvas/WebGL 引擎      │
│   · 复用 public/ 视觉引擎，保证与桌面视觉一致        │
│   · 仅承载视觉与必要 UI，不再承载重计算             │
├─────────────────────────────────────────────┤
│  音频 / 解密层（Swift 原生）                      │
│   · AVFoundation / AVAudioEngine 播放与会话         │
│   · 汽水 CENC/AES 解密（Swift 重写 SodaCrypto 逻辑）  │
│   · 分段流式解码，避免整段入内存                     │
├─────────────────────────────────────────────┤
│  签名 / 音源逻辑层                               │
│   · JavaScriptCore 执行 bdms.js 产出汽水整轨签名     │
│   · 平台标识可配置（windows/mac/其它）以匹配可播通道  │
│   · 网易/QQ/酷狗/Spotify：沿用已有 Swift 原生实现     │
└─────────────────────────────────────────────┘
```

设计要点：
- **视觉一致**：WebView 继续跑原版引擎，视觉不打折。
- **性能治理**：把音频解码、整轨解密从 WebContent 挪到 Swift，WebView 内存压力大幅下降；叠加主动内存治理。
- **汽水可播**：用 JavaScriptCore 跑 `bdms.js`，绕开「原生重写字节签名 SDK」这个几乎不可能的任务，最大化复用 timing 已趟通的 JS。
- **与 Android 配合点**：不是互抄代码，而是对齐同一套音源/签名逻辑与产品设计。timing 在安卓踩过的接口、签名、限流坑，iOS 直接复用结论。

---

## 3. 分阶段实施计划

分阶段原则：每阶段能独立交付、能单独验收、不把未验收改动混进上线。

### 阶段 A：汽水播放修复 —— 补 seo_track 回退链路（P0，先打通命门）

**目标**：照搬安卓已验证的回退链路，让 iOS 在 `track_v2` 被官方关闭时，仍能通过 `seo_track` 拿到可播 M4A。

- A1 在 `QishuiCatalogAPI` 新增 `seo_track` 请求：对照安卓 `fetchQishuiSeoTrack`，取 `track_player.url_player_info`。
- A2 实现 PlayerInfo 换流：对照安卓 `fetchQishuiPlayerInfo`，用 `url_player_info`（VOD GetPlayInfo 签名地址）换取可播 M4A（含 auth），注意 host/Referer 白名单与大小上限。
- A3 把 `/api/qishui/song/url` 的降级逻辑从「直接试听」改为「track_v2 失败 → seo_track 回退 → 仍失败才试听」，并接入会员权益判定（对照 `qishuiResolveTrial` / `fetchQishuiPlaybackMembership`），避免 VIP 被误标试听。
- A4 单元/fixture 覆盖：track_v2 空响应 → 走 seo_track 的分支；非 VIP 试听；缺登录态拒绝。

**验收**：真实汽水账号、至少一首歌经 seo_track 链路可播（需真机 + 真账号，分开记录证据）。CENC/AES 解密（`SodaCrypto`）仅在 seo_track 返回加密音源时才需要，视实测情况决定是否纳入本阶段。

### 阶段 B：资源占用与闪退治理（P0）

- B1 把音频解码/整轨解密移出 WebContent（阶段 A 已下沉），减掉 WebView 内的整段音频缓冲与整轨分析分配。
- B2 原生内存治理：监听 `didReceiveMemoryWarning` 后主动驱逐歌词纹理池/远端行/缓存；限制 `URLCache`；低配设备（按内存等级）降级视觉预设。
- B3 建 iOS 版性能监控（对标安卓 `PerformanceMonitor`）：内存、帧率、WebContent 终止、启动耗时，仅本地日志。
- B4 WebView 配置优化：评估 `WKProcessPool` 复用、限制并发、释放后台资源。

**验收**：低配设备（如老 iPad / iPhone）长播不被杀进程；内存峰值较现状明显下降（给出 before/after 本地记录）。

### 阶段 C：交互原生化（P1）

- C1 手机端核心控件（播放/进度/音量/音质/歌单入口）用原生布局承载，不再靠网页 CSS 在窄屏凑；视觉区仍是 WebView。
- C2 规整触控：点击/拖拽/双指缩放与手机 HUD 的显隐、安全区适配。
- C3 iPad 布局单独验收，保留现有平板呈现。

**验收**：iPhone/iPad 真机上按钮位置正确、无错位、无误触，手势顺畅。

### 阶段 D：Spotify 接入与验收（P1）

- D1 确认 `SpotifyNativeAPI` 当前为何「缺失」：是未接入前端、还是缺 client_id 配置。
- D2 跑通 OAuth PKCE 登录，验证库/搜索/播放（注意 `playable` 当前为 false）。
- D3 对照安卓 `spotify-api.js` 对齐能力边界。

**验收**：真实 Spotify 账号登录 + 播放可用。

### 阶段 E：上线版打包与 TestFlight（汇总验收）

- E1 汇总各 provider 真实账号验收、长播稳定性、iPhone/iPad UI 验收。
- E2 版本号与 AppIcon、App Store Connect 记录（`com.swordingk.mineradio.apple.preview`，team `NV5R86Q3MS`）。
- E3 honest 验收门槛全绿后再上传；不把模拟器/fixture 结果当真机验收。

---

## 4. 待验证 / 风险点

- **JavaScriptCore 跑 bdms.js**：`bdms.js` 是混淆的字节 SDK，可能依赖浏览器/Node 环境特有对象（`window`、`document`、crypto 等）。JSCore 没有 DOM，需评估要不要补 shim 或用极简 WKWebView 沙箱跑。这是阶段 A 最大不确定项。
- **汽水平台签名策略**：windows/mac/其它标识哪个在 iOS 上可稳定播放，需实测；字节可能按平台风控，存在被限流/封禁风险。
- **整轨解密内存**：解密要避免整段入内存，需分段流式处理，否则 P0 内存问题会从 WebView 转移到原生。
- **合规**：仅个人账号本地播放辅助，不绕过付费/会员/音质破解/内容再分发。签名与解密只用于让用户自己有权限的内容正常播放。
- **密钥安全**：安卓仓库内联了 `key.jks` 和运行时密钥——仅作只读参考，iOS 绝不入库任何签名/证书/密钥。

---

## 5. 与安卓仓库的参考关系

- 安卓仓库已克隆到工作区：`/Users/baojian/Desktop/Mineradio/Mineradio-Android`（公开 `Timingyyds/Mineradio-Android`，tag `v2.2.0.0`），**只读参考**。
- 可直接对照的关键实现：
  - 汽水签名：`app/src/main/nodejs-project-src/qishui-auth-v6/bdms.js`
  - 汽水解密：`app/.../qishui-audio-decryptor/track-decryptor.js`、`SodaCrypto.kt`
  - 音源 JS：`app/.../nodejs-project-src/{qishui-api,qq-vip-api,kugou-api,spotify-api}.js`
  - 性能/崩溃：`PerformanceMonitor.kt`、`crash/CrashHandler.kt`
  - 登录交互：QQ「folia 同款」微信扫码（`qq-wechat-login.js`）

---

## 6. 单独挂起的已知问题（提 Issue，本次不处理）

- **[ISSUE] Mac 客户端汽水登录失败**：官网当前 Mac 客户端汽水连登录都过不了（早于播放的问题）。与 iOS 播放签名是不同问题。优先级低于 iOS 上线，后续单独排期修复。
```

---

## 7. 下一步

从 **阶段 A1** 开始：在 iOS 工程里用 JavaScriptCore 加载安卓 `bdms.js`，验证能否产出有效汽水整轨签名。这是整个汽水播放的命门，也是风险最高的一环，先验证可行性再铺开。

---

## 8. 实施进度（分支 `feat/qishui-signing-poc`）

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| A | 汽水 seo_track 回退、PlayerInfo 域名、封面拼接 | 已提交；真机可播 30 秒试听，整轨需官方客户端签名，iOS 暂无正规路径（待 timing 确认安卓插件做法） |
| B | 真实 deviceMemory → 原版 lowSpec；内存警告逐级降渲染分辨率 + 原版深度缓存裁剪；WebContent 被回收自动恢复 | 已提交；待真机 30 分钟长播验收 |
| C | 原生播放 UI：`NowPlayingModel` 统一状态；iPhone 原生 SwiftUI 控制条取代网页底部栏；锁屏/控制中心「正在播放」与远程命令；后台音频 | 已提交；待真机验收 |
| C2 | 音频从 WebView 迁到原生 AVPlayer（需 JS `Audio` 垫片 + 原生 FFT 喂给原版可视化） | 已完成依赖测绘，未实施；风险最高（AutoMix/无缝衔接/每帧频谱桥接），单独分支、默认关闭推进 |
| D | Spotify | 元数据/歌单可用；官方不提供音频，播放需接入 Spotify iOS SDK + Premium |
| E | 上线打包 | 待 B/C 真机验收 |

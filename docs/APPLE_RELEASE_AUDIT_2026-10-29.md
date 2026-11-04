# Apple 客户端上线前审查（2026-10-29）

## 结论

当前版本比早期移植版已有实质进步：SwiftUI 原生控制条、锁屏/远程命令、网易/QQ/酷狗直连扫码、图片缓存、内存警告降档、页面回收恢复均已加入。不建议在临近上线时推倒改为 Flutter 或重写视觉引擎。

但“原生控制条”不是“原生音频引擎”：音频仍由 WebView 的原版播放器执行。页面进程被回收仍会中断音乐，重载只是恢复措施。现有证据不足以宣称老 iPad 长播稳定或直接发布无风险。

## 基线与回退

- 起点：`6ad369fa6538aeea04d6e159c20c1db112be06d9`，原分支 `feat/qishui-signing-poc`，开始时工作区干净。
- 本轮分支：`codex/release-audit-20261029`。
- 本地备份标签：`backup/pre-codex-audit-20261029`。
- 工作区外完整历史备份：`../.inspect/ios-pre-audit-20261029.bundle`，已通过 `git bundle verify`。
- 要查看原版：先保存当前未提交文件，再 `git switch feat/qishui-signing-poc`。无需 `reset --hard`。
- 没有推送、发布、修改版本号、上传 TestFlight 或安装到用户真机。远程 iOS 仓库实际为公开；本地文档中“私有”描述已过时。

## 本轮已修复

### 页面回收后的播放状态与位置

`apps/apple/Web/apple-mobile.js` 原先无条件打开自动播放，且原版启动模块可能已经按“从头播放”计算过 `pendingPlaybackResumeAt`。结果：暂停状态回收后也触发续播；已存在的恢复快照可能继续使用 0 秒。

现在按快照的 `playing` 决定是否续播，并在临时启用 resume 后重新计算保存位置。普通启动不受影响，不持久修改用户偏好。新增实际执行适配脚本的回归测试，修复前 3 项失败、修复后通过。仍需真机验证系统回收后的端到端音频恢复；快照保存间隔意味着可能有几秒回退。

### 汽水 SEO 音源可播放性

`QishuiCatalogAPI.playerInfo` 原先将 `PlayAuth` 拼在 URL fragment 后，仍返回 `playable: true`。当前 iOS 媒体代理没有解密实现，HTMLAudio 不会因为 fragment 自动解密。

现在过滤带 `PlayAuth`/`SpadeA` 或非空 `EncryptInfo` 的候选，混合列表优先选未加密流；只有加密候选时返回 `unsupported_encryption`，不暴露不可直接播放的链接。保留试听标识和会员筛选。新增经完整 `/api/qishui/song/url` 路由的 fixture，覆盖全加密、嵌套加密标记、混合候选；修复前失败、修复后通过。

这修复了错误的“可播放”声明，**没有实现加密整曲播放，也没有证明真实汽水 VIP 整轨已经可用**。

## 剩余优先项

| 优先级 | 问题 / 代码证据 | 建议与验收 |
|---|---|---|
| P1 上线前 | `NativeControlBar.swift` 拖动期间不暂停 `NowPlayingModel.reveal()` 的隐藏计时；长拖可能移除控件、丢失结束回调 | 加入明确 scrubbing 状态并锁住显隐；真机长拖超过 6 秒验证提交一次 seek |
| P1 上线前 | `OriginalPlayerView.swift` 在 didFinish 才恢复压力等级；首次分配已发生，手动重试重建 Coordinator 又清零等级 | 将降档状态提升到宿主并在页面引擎初始化前注入；反复回收/手动重试保持降档 |
| P1 上线前 | `AppleCoverCache.swift` 用 `session.data` 下载完整响应后才检查 6 MiB；`NowPlayingModel` 使用 UIImage(data:) 未做尺寸受控缩略解码 | 下载过程限字节、限制在途请求、ImageIO 缩略图；大图与快速切歌压测 |
| P2 | 封面磁盘只限 600 个文件、没有总字节预算；每 40 次写才清理 | 增加磁盘总量预算与内存警告清理；不能把文件数等同磁盘容量 |
| P2 | 原生控制条收起不向网页报告可见性，`apple-native-controls.js` 的 reserve 仍按有歌预留高度 | 双向同步实际高度/可见性，验收横竖屏、DIY 与歌单空间 |
| 后续独立分支 | 音频与视觉仍共享 WebContent 生命周期 | 原生 AVPlayer/AVAudioEngine 分阶段试验，先验证频谱、无缝切歌、AutoMix 和后台中断，不能一次替换后宣称等效 |

这些是源码可核实的风险；本轮没有当前真机 CPU/RAM/GPU 峰值或电池消耗测量，不能宣称已经量化性能改善。`AppleDiagnostics` 的 hostFootprintBytes 明确不包含 WebContent/GPU，应结合 Instruments 与系统终止记录分析。

## 汽水与 Spotify 能力结论

### 汽水

iOS 已有登录、目录、PC/Web 取流及 SEO/PlayerInfo 回退，不是“完全不能接”。但是否得到整轨取决于实际接口返回、账号权益、音源加密和本机解码能力。文档中“所有第三方接口均已关闭”与“必须重新做签名”的绝对结论，本轮均没有真实网络证据支持，不能当作已经证实的全平台事实。

建议明确展示“汽水歌单 + 可用音源 / 试听 + 其他已登录平台匹配”。要补原源整曲，需要团队提供当前可工作的客户端版本及脱敏响应结构/播放链路，再按 iOS 实际运行能力验证，不搬入凭据、不绕过权益。

### Spotify

- `SpotifyNativeAPI/SpotifyContract/apple-spotify.js` 已有 OAuth、歌单、搜索等代码。
- `project.yml` 的 `SPOTIFY_CLIENT_ID` 默认仍为空；当前构建配置没有提供可验证的真实授权。
- `apple-direct-login.js` 明确隐藏 Spotify 登录卡与账号胶囊，所以用户看不到入口是主动产品裁剪，并非 Swift 无法适配。
- 不能把歌单检索、其他平台匹配和 Spotify 原音源播放混为一谈。填 Client ID 不会自动获得裸音源。
- 官方 iOS SDK 的 App Remote 控制已安装的 Spotify App，实际播放由 Spotify App 承担；不是把音频交给现有 WebAudio 视觉引擎。参见 [官方 SDK](https://github.com/spotify/ios-sdk)。
- 开发模式有最多 5 名授权用户等限制，广泛发布还需核实团队应用的实际 quota mode，参见 [官方额度说明](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)。

本轮未盲目恢复无配置入口。可分为“歌单导入与跨平台匹配”和“Spotify App Remote 控制”两个明确能力，不应承诺与当前频谱链路完全一致。

## 验证记录

- 原基线完整脚本：62 JavaScript 检查、20 个原生 Swift 套件通过。
- 原基线 Release 模拟器双架构构建通过，产物约 16 MiB；这是模拟器 .app 文件大小，不是下载包大小或运行 RAM。
- 本轮修复后完整检查与 Release 构建结果见下方最终记录。
- 未验证：真实账号端到端播放、真机长播/后台/电话中断、旧 iPad 性能、App Store 当前审核结果。

推荐发布顺序：先修上表 P1 → 最老支持 iPad 与常用 iPhone 各长播 30 分钟、至少 50 次切歌并验证后台/来电/旋转 → 再更新构建号打包。平台不具备的能力应明确显示，不用增加空入口凑数量。

### 最终记录

修复后：65 项 JavaScript 检查、20 个 Swift 原生测试套件全部通过；Release iOS Simulator（arm64/x86_64）构建成功。唯一构建警告为未使用 AppIntents 时跳过元数据抽取。`git diff --check` 通过。上述不等于真机性能/音乐账号验收。

日志保存在工作区外 `../.inspect/release-audit-20261029/`，不提交生成物或私有参考源码。

# 汽水原生媒体链路（2026-10-29）

本轮实现 iOS 过去缺少的授权媒体解码与本机播放中继，参考现有 Android 解码器，保留 GPL 署名。不是再次增加一个平台按钮。

## 行为

- 原生服务显式启用加密候选；目录适配器默认仍拒绝加密，避免其它调用者把原始加密字节交给 HTMLAudio。
- `nativePlaybackAuth` 仅用于本机 Swift 组件之间传递，返回网页前移除。网页拿到的只有临时 UUID 播放票据。
- 普通播放、预取和媒体探测经过原有 `/api/audio` 时识别本机票据；不会把本机地址误送远程媒体代理。
- Swift 解码器支持 Android 对应的完整 sample AES-128-CTR、hex/base64 Spade、M4A/FLAC。合成测试用同一份输入与 Android 参考输出对比。
- 中继禁止重定向和 Cookie，下载逐块落盘，上限 32 MiB，最多一个解码任务与一份磁盘缓存，支持 Range/HEAD。退出登录会撤销票据。
- 保留有效试听地址，不再将其改为空强迫换源。这修复了“有片段但被导向失败的其他平台”的确定缺陷；仍如实显示试听，不延长片段或改变账号权益。

## 验证与边界

70 项 JS 检查与 23 个 Swift 套件通过，包含解码差分、媒体票据、Range、缓存、失效、大小上限、目录能力开关以及原有平台回归。Debug iOS Simulator 构建通过。

没有真实汽水账号音源的端到端验收，因此不宣称用户报告的那首歌曲已恢复完整播放。接口若仅返回片段，解码不会变出整首歌曲；未实现的 fragmented MP4/subsample encryption 布局会拒绝。真实账号仍需检查平台返回、会员权益和播放时长。

Spotify 的团队 Client ID/已登记 iOS 回调尚未提供，不能伪造应用登记；该阻碍与汽水的已实现代码修改分开记录。本轮无账号密码、Cookie、签名音频地址入库，无真机安装或 TestFlight 上传。

开发参考 fixture 生成器在 `apps/apple/scripts/qishui-decoder-fixtures.cjs`，需相邻 Android 参考仓库，仅人工重生成时使用；正常测试使用已嵌入的合成 fixture，不依赖该参考仓库。

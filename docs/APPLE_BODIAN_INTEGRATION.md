# 波点音乐 Apple 接入（2026-10-29）

本轮在 `codex/release-audit-20261029` 上新增 Apple-only 原生服务与网页桥；沿用现有视觉引擎。回退基线仍为 `backup/pre-codex-audit-20261029`。

## 已实现

- Swift `BodianNativeAPI`：固定域名 API、Android 对齐签名和 headers、稳定设备标识、Keychain 保存会话，凭据不传给网页。
- 扫码二维码/轮询/确认/失效/退出，扫码使用波点音乐 App。
- 匿名搜索、权益校验后取流、试听标识、普通歌词、账号歌单与曲目。
- `apple-bodian.js`：平台登录与搜索入口、provider/队列标识、歌单、歌词、播放与预取路由，沿用本机媒体转发。
- 媒体白名单加入实际探测的 img4.kuwo.cn 与 ga-sycdn.kuwo.cn 等指定主机，不开放整个波点 API 为媒体代理。

## 真实网络证据

早先直接 require 安卓模块而没有执行 `setBodianSessionFile`，未生成 device ID，二维码/搜索返回 402。按正式启动流程生成设备标识后，两项均成功。此前不能据此认定波点接口不可用。

当前 Swift 实现也已真实返回：`qrAvailable=true`、`searchCount=2`、`audioURLAvailable=true`。探测使用匿名测试查询，不读取用户已有音乐登录态，也不保存或打印签名音频链接/凭据。

## 边界

真实扫码确认与账号歌单、会员歌曲、真机实际出声与长播尚未验收。普通 LRC 已接，波点逐字歌词解码未实现。不宣称新增平台已达到正式发布标准；Spotify 与汽水整曲的原有缺口也没有因此解决。

测试/构建最终记录在本轮交付中补充。无 TestFlight 上传、无远程推送、无真机安装。

前端 5 项新增回归已通过（包含调用未改写的原版 gapless 取流函数），完整普通 JS 文件测试 62 项通过；原生波点套件通过签名、二维码生命周期、账号凭据隔离、搜索、试听和退出验证。整套测试脚本含额外安全桥检查共 69 项 JS 检查通过。实际 .app 构建与其余原生回归在提交前检查。

最终：69 项 JS 检查、21 个 Swift 套件通过；Debug iOS Simulator 双架构构建成功，打包 bundle 与最新生成资产逐字节相同。编译有既有 Debug 检查器的 nil-coalescing 警告及 AppIntents 未使用提示。未进行真机安装、真实账号登录或 TestFlight 上传。

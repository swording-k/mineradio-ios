# Mac/iOS 平台对照与汽水请求修复

## 直接检查的参照

- 团队 Mac `qishui-api.js: fetchQishuiPcTrackV2` 使用 PC 参数、POST JSON、track_id/media_type/queue_type/scene_name。
- iOS 原来尝试 PC GET、Web POST/GET、SEO。缺少上述 PC POST，现加入首选路径，复用已有会话和域名限制。
- 修正“任意可播放结果就提前返回”：试听不能阻止后续路径提供完整音源。全部失败时保留可用试听以及原有加密不支持诊断。
- 不再把一次接口返回试听描述为“第三方一律只能试听”。

## Spotify

团队 Mac `spotify-api.js: handleSpotifySongUrl` 返回 recommend-match/provider_limited，说明官方 Web API 不提供可交给播放器的音频直链。iOS 同样采用元数据/歌单与跨平台匹配。源码中的 Spotify 图标不等于从 Spotify 直接播放。需要真实配置和账号授权验收，不能用测试代替。

## 清晰度

当前共享渲染器 balanced 档 cap 约 0.98–1.12，远低于 iPhone 14 Pro 的屏幕 DPR。该限制可能使粒子画面比原生文字更软；这只是源码依据，尚非设备实测根因。不直接强制 DPR=3：像素缓冲成本随倍率平方增长，老 iPad 已报告 WebContent 退出。后续应在新设备提高画质的同时，用设备 WebContent/GPU 指标检查稳定性。

## 已验证/待验证

新增 PC POST 请求契约和“试听后仍继续找到完整源”回归通过；原有 QishuiCatalogTests 全部通过。iOS 模拟器编译通过。
真实汽水 VIP 账号是否返回整曲仍未验证。没有读取用户钥匙串凭据或操作实体设备。不能宣称汽水完整播放已修好。

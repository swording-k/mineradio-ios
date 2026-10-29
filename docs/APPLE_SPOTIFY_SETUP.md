# Spotify 用户自行配置（2026-10-29）

iOS 采用 Android 客户端同类流程：每位用户在 Spotify Developer Dashboard 登记自己的应用，在 Mineradio 中填写公开 Client ID，然后在 Spotify 官方页面登录自己的账号并授权。

## 用户步骤

1. 打开 Spotify 登录卡中的开发者后台链接，创建或选择自己的应用。
2. 在 Spotify 应用设置登记回调：`com.swordingk.mineradio.apple://spotify/callback`。App 内可复制。
3. 将 32 位 Client ID 填入 Mineradio，点击“保存并授权”。不输入 Client Secret、账号密码或 Token。
4. 系统授权窗口由 Spotify 承接账号登录，完成后返回 Mineradio。

## 实现

- Apple-only 登录面板恢复 Spotify 入口；原有四个平台和波点继续使用各自适配器。
- `GET/POST /api/spotify/config` 读取/保存公开应用编号，固定 iOS 回调，拒绝任意回调和 Client Secret。
- 公开编号保存到本机偏好；OAuth Token 留在 Keychain，按应用编号隔离。
- 保存同一编号不登出；更换编号取消旧授权/刷新任务并清除旧应用 Token，避免跨应用复用。
- PKCE/state、系统授权、搜索与歌单元数据继续使用已有原生实现。

## 能力边界

这与安卓“填写 Client ID → 官方授权 → 同步歌单/喜欢 → 匹配其它音源播放”的路线对齐，不代表 Spotify 向本客户端提供原始音频流。平台对开发者应用的账号、授权用户及额度要求仍由 Spotify 决定。

用户尚未提供自己的有效 Client ID，因此本轮不声称真实 OAuth、真实账号歌单或歌曲播放验收通过。不再把等待团队 Client ID 当作代码实现的前置阻碍。

验证：71 项 JS 检查、Spotify Swift 套件、Debug iOS Simulator 构建通过。测试覆盖非法配置不提交、配置持久化、固定回调、同 ID 保留会话、更换 ID 作废旧授权与刷新、原 OAuth/歌单边界。用户的真实开发者应用授权与歌曲匹配仍待实际账号验证。这些改动在本地源码，不会自动进入此前上传的 TestFlight 构建。

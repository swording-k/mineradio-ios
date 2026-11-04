# App Review 真机录屏脚本

对应商店版本 1.0，用户确认提交构建为 0.4.6 (17)。日期：2026-11-04。

## 本次要求的含义

截图为 Guideline 2.1 信息补充请求，没有明确说唯一原因是没有账号，也没有列出某次崩溃的复现过程。
苹果要求：最新正式操作系统的实体设备录屏，从启动 App 开始，展示正常用户流程；另补用途/受众、设置和访问方式、第三方服务、地区差异、相关授权材料。
注册/删号、UGC 举报屏蔽、付费内容是存在时才展示。不要为了录屏新增虚假账号、虚假支付或仅审核员可见的假功能。视频不能替代审核员实际访问功能。

## 录制前

- 用真实 iPhone 或 iPad，更新至设备可用的最新正式系统；记录设备型号、系统版本。若设备不支持最新系统，备注如实说明，尽量换支持最新系统的设备录。
- 安装 TestFlight 0.4.6 (17)。录后续本地开发包不能证明这份构建的行为。
- 打开勿扰、隐藏通知。不要录账号密码、短信验证码、Cookie 或 Token；扫码确认用另一个设备完成。不要把个人登录凭据当审核素材。
- 用 iOS 控制中心的“屏幕录制”，可开启麦克风。旁白可中文，配英文步骤说明更便于审核。
- 选已实测稳定的音乐平台、你有权播放的示例曲目；示例音乐仅为演示，不表示获得公开分发授权。
- 尽量连续录制约 3–5 分钟。保留真实等待过程，不用宣传片、模拟器或后期伪造 UI 替代。

## 时间线与旁白

| 时间 | 操作 | 可直接照读 |
|---|---|---|
| 0:00–0:15 | 在主屏幕开始录制，点 Mineradio 图标启动 | 这是 Mineradio 的 iOS 真机演示，构建版本为 0.4.6，构建号 17。它是一款以粒子特效、歌词和专辑画面为特色的可视化音乐播放器。 |
| 0:15–0:40 | 展示首页和首次引导；若出现解锁入口，点击头像并输入“世界和平” | 这里是首次使用引导。如果当前构建显示这个入口，输入“世界和平”进入平台连接界面。这是应用入口口令，不会创建音乐平台账号，也不会授予会员权益。 |
| 0:40–1:30 | 打开已验证的平台登录页，展示二维码或实际登录方式；另一个设备确认，回来展示登录完成 | 音乐功能连接用户自己的第三方平台账号。这次演示使用［实际平台名］。确认后可以访问该账号有权使用的歌单和歌曲。 |
| 1:30–2:05 | 打开自己的歌单，选择一首可播歌曲，等待进度持续前进 | 现在打开歌单并播放一首有权限的歌曲。画面展示真实播放进度、歌词和专辑视觉。 |
| 2:05–2:35 | 暂停、继续、下一首；如支持则拖动进度 | 这里可以暂停、继续、切歌，并调节播放进度。每个操作后等待实际响应。 |
| 2:35–3:15 | 打开 DIY，切换一项实际存在的粒子/背景效果，关闭设置，进入/退出沉浸 | 视觉设置可以调整播放画面。这里展示粒子效果和沉浸式播放，播放控制需要时可以再次唤出。 |
| 3:15–3:40 | 横竖屏切换；展示歌单开启与关闭 | 这是横竖屏下的布局与歌单操作。若当前版本出现错位或无法关闭，应先修复再提交，不能剪掉后声称正常。 |
| 3:40–4:10 | 回账户页断开这次连接，展示退出结果 | 这里断开第三方音乐平台连接。这只退出 Mineradio 内的连接，不会删除第三方平台账号。 |
| 4:10–4:30 | 展示支持/隐私入口（如果构建有），结束录制 | 隐私政策和支持网址也已提供在审核备注中。 |

## 适用时追加展示

- App 自建注册：如果构建确实支持创建自己的账号，要展示注册和 App 内账号删除。第三方退出不等于删号。
- 评论：如果构建开放查看/发布评论，展示其实际内容流程和举报、屏蔽、处理入口。当前源代码有评论显示和部分平台发送，未检索到配套举报/屏蔽实现；不能在备注中直接写无 UGC。
- 支付：如果无应用内购买、打赏或付费解锁，如实说明没有；不要为了这段通用要求新增购买。若展示平台会员内容，说明权益来自原平台，不声称 Mineradio 提供免费会员。
- 本地文件：仅在构建 17 真正支持导入时展示，并给审核员提供可合法使用的样例；不要宣称源码存在就代表提交包支持。
- Spotify、汽水、波点：凡构建中可访问的入口都要说明，不用只录一个正常平台来掩盖其余失效入口。

## 提交素材

把视频上传到审核员无需登录、无需申请权限就可访问的位置，确认海外访问条件。将链接放在 App 审核信息的备注和本次回复里；如果当前回复界面允许视频附件，可一并提供。此视频是审核证明，不是商店产品页的 App Preview 广告片。

账号功能仍需提供实际可用的审核访问方法。仅口令“世界和平”、操作视频、或“请登录您自己的网易云账号”，都不能保证审核员能够访问歌单播放功能。

## 本轮发现的待处理项

1. 构建 17 的评论入口是否实际开放需真机核实。若开放，补齐适用的 UGC 处理机制，或移除相关功能后新建构建；不能只写备注绕过。
2. 开源代码许可证不是音乐平台 API 或曲库内容授权。苹果截图第 6 项需按实际提供证据，不写“因为用户有会员，所以我们有平台授权”。
3. 录屏不需要重新构建；代码功能修复需要新构建。图标、引导和汽水后续修改不会自动进入已经上传的构建 17。

## 审核备注草稿（方括号需按实际填完再提交）

Submitted app version: 1.0. Submitted build: 0.4.6 (17).

1. Physical-device demonstration
Video: [publicly accessible recording URL]
Device: [model], OS: [version]. The recording starts at the Home Screen and shows app launch, setup, third-party sign-in, playlist browsing, playback controls, visualization settings, orientation changes, and disconnection.

2. Purpose and audience
Mineradio is a visual music player for iPhone and iPad. It combines music playback with particle effects, lyrics, and album artwork for listeners who want a customizable visual listening experience.

3. Setup and access
If the entry passphrase is displayed, tap the profile entry and enter 世界和平 (copy exactly). This is an app entry passphrase, not a third-party music account or a subscription.
[Describe the actual reviewer access method and provide the necessary authorized demo credentials/sample files through the appropriate private review fields. Do not include personal credentials in the video or a public link.]

4. External services
[Confirm all services actually exposed in build 17. Current source contains integrations for NetEase Cloud Music, QQ Music, Kugou Music, Qishui Music, Spotify and Bodian Music; source presence does not establish which ones are in this binary.]
Music services supply their own authentication, catalogs, and playback entitlements. Spotify integration uses metadata/library access and available authorized source matching; do not describe this as Spotify audio streaming unless actually implemented and verified.
[Confirm whether any payment, analytics, remote AI, or other external services are used by the submitted build.]

5. Regions
Music availability and sign-in depend on the music provider, region, account and subscription. [Specify the actual App Store distribution regions and any app-level regional restrictions.] Do not claim identical worldwide music availability without verification.

6. Third-party material and applicable flows
[Attach applicable platform/content authorization evidence, or accurately explain what is and is not authorized. Open-source code licensing does not by itself authorize a music catalog or use of a third-party service.]
[Confirm whether build 17 offers account creation, comments/other user-generated content, and paid functionality. Where applicable, describe and demonstrate account deletion, reporting/blocking and paid-access flows.]

Privacy policy: https://swording-k.github.io/mineradio-ios/privacy.html
Support: https://swording-k.github.io/mineradio-ios/

This draft is not ready to submit until the bracketed facts and access method have been completed.

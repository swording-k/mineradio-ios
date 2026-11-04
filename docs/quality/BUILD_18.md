# 1.0 (18) 待验收构建

日期：2026-11-04。用于用户本机检查，不标记稳定 Release。

## 构建入口

当前目录：`/Users/baojian/Desktop/Mineradio/Mineradio-iOS`

分支：`fix/phone-guide-viewport-20261030`

Xcode 项目：`apps/apple/MineradioApple.xcodeproj`，scheme `MineradioApple`。

`project.yml` 是版本配置来源：marketing version 1.0、build 18。生成的 Info.plist 与项目不跟踪，其他电脑用 XcodeGen 生成后再打开。网页资源由构建脚本自动打包，不需手动覆盖网页。

## 包含与验证

包含此前 iPhone 登录/布局调整，以及本轮首次引导可见区域约束、官方绿色 MR 图标、汽水 PC POST 请求和完整音源优先选择。

首次引导 6 项定位测试通过，模拟器编译通过，并读取构建产物确认版本为 1.0 (18)。此前汽水目录回归通过。

这不等于手机安装通过或所有音乐平台实测通过；不包含 App Store 上传或审核通过证据。

## 手机验收重点

- 首次启动和教学各步骤；iPhone 横竖屏的歌单关闭、播放条唤出、DIY 和双指缩放。
- 登录、歌单、切歌、后台音频与长时间播放，确认没有从头播放或页面进程重启。
- 汽水完整音源仍需真实账号确认；Spotify 尚需有效授权与音源匹配验证。
- 上架前确认评论等 UGC 功能的举报/屏蔽处理，以及审核员实际访问方式。

商店现有 1.0 对应旧二进制 0.4.6 (17)；新版二进制版本改为 1.0，以与商店版本对齐。不要覆盖旧 archive，不自动撤回旧审核或自动上传。

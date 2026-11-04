# Mineradio 隐私政策

适用产品：Mineradio iPhone / iPad 客户端  
开发与联系：Kun Yang（swording-k）  
生效及更新日期：2026 年 10 月 29 日

本政策说明 Mineradio 在音乐平台连接、播放、音乐可视化和本地设置中如何处理信息。不同音乐平台及 Apple、GitHub 等服务各自的隐私政策同样适用于你直接使用的相应服务。

## 1. 本机处理与保存的信息

为提供你主动使用的功能，客户端可能在设备上处理和保存：

- 音乐平台的授权令牌、登录 Cookie 或会话信息，用于维持你授权的登录状态。相应凭据主要由原生适配器及系统钥匙串保存；官方登录页面也可能使用其自身 Cookie。不要向开发者发送密码、Cookie、令牌或 Client Secret。
- 平台返回的用户标识、昵称、头像、会员状态、歌单与歌曲元数据，用于显示账号、音乐库和播放权限。会员与内容权限由音乐平台决定。
- 搜索记录、播放队列、最近播放的歌曲与恢复进度、内置歌单、自定义歌词或封面、视觉与设备偏好，用于保存本机使用状态。
- 封面、歌词、媒体及节奏分析等缓存，用于播放和减少重复加载。支持的具体缓存随功能和版本而变化。
- 本机性能与故障诊断，如内存警告、页面进程退出、播放时间、渲染统计。当前实现保留本地诊断；未设置自动上传给开发者的统计或广告跟踪服务。
- 部分平台适配所需的本地设备标识，用于请求兼容和登录会话；该标识可能随对应请求发送给音乐平台，不是用于跨 App 广告跟踪的 IDFA。
- 如果你自行配置 Spotify，公开 Client ID 会保存在本机偏好中；它是应用公开标识，不是账号密码。OAuth 凭据另行存放，网页界面不会收到原生适配器保存的 Token。

上述信息主要用于你设备上的功能。当前客户端不设置用于集中收集这些音乐账号和播放记录的开发者自建后台，也不出售这些信息。

## 2. 联网请求与第三方服务

使用联网功能时，客户端会向你选择的音乐平台、其授权服务和内容分发网络发送完成请求所必需的信息，例如搜索关键词、歌曲或歌单标识、分页参数、会话凭据和平台请求所需的设备参数。服务方还会正常接收网络通信产生的 IP 地址、请求时间、设备或浏览器请求头等信息。

目前代码包含网易云音乐、QQ 音乐、酷狗音乐、汽水音乐、Spotify 和波点音乐等适配。某项适配存在于代码中不保证其所有功能、地区、账号或内容始终可用。你授权哪个平台，相应请求就受该平台的服务规则与隐私政策约束。登录不授予额外版权、会员或付费内容权益。

部分显示资源（如远端封面、字体）、官方授权页面以及你主动打开的帮助链接可能来自第三方；访问这些资源也会产生相应网络请求。音乐平台可能在不同国家或地区处理信息，具体范围以该平台的披露为准。

客户端内的本机服务仅监听回环地址，用于原生适配器与内嵌播放器通信；它本身不是供其他用户访问的远端服务器。

## 3. 系统权限

- 照片添加权限：仅在你选择保存登录二维码时申请，用于把生成的二维码保存到相册；该权限不用于读取或批量上传你的照片。
- 文件选择：你主动选择自定义封面、歌词或支持的本地文件时，应用为所选功能读取相关文件。
- 麦克风、摄像头等网页或可选功能若在所用版本中启用，应以系统实际权限提示为准；仅在你主动使用并授权后访问。你可以在系统设置撤销权限。未启用的功能不应被理解为已默认访问这些传感器。
- 本地网络提示（如调试或连接自选服务时出现）：以你主动选择的连接为目的；正常设备内回环通信不意味着向局域网公开音乐账号。

拒绝某项权限可能使对应功能不可用，不会因此自动授予其他权限。

## 4. 保留、退出和删除

本地偏好、历史与缓存会保留至你清理相应内容、应用按缓存策略淘汰或你删除相关本地数据。账号凭据通常保留至退出账号或授权失效。不同平台或系统浏览器的登录状态可能需要在对应服务中单独退出或撤销授权。

你可以在应用中退出相应平台账号，并在音乐平台的账号设置中撤销授权。清理本机数据前建议先退出各音乐账号。删除 App 会删除其沙盒数据，但系统钥匙串或系统浏览器的数据可能按系统机制保留，不能把卸载视为对所有第三方会话的撤销。

如需了解本机数据清理方式，或对你主动发送给我们的支持资料请求访问、更正或删除，请通过下方邮箱联系。开发者无法直接删除音乐平台持有的账号数据，你需向对应平台申请。

## 5. 问题反馈与联系

你主动通过邮箱或 GitHub 反馈时，我们会接收你提交的联系信息、描述、截图或日志，用于回复和排查问题；请先移除密码、Cookie、Token、二维码会话及其他不必要的私人内容。不要在公开 GitHub Issue 中发布这些内容。

GitHub Issue 是公开的，邮件由邮件服务商处理。这些渠道的信息会按解决问题和履行适用义务所需的期限保留；你可联系开发者提出删除请求。

邮箱：swordingk@gmail.com  
反馈：https://github.com/swording-k/mineradio-ios/issues

## 6. 安全与政策更新

客户端使用系统钥匙串等机制保护相应凭据，并限制本机接口与媒体请求范围。任何存储与网络传输都无法保证绝对安全；请使用系统和音乐平台提供的账号安全措施。

如果后续新增开发者后台、广告、统计、云同步或改变数据用途，我们会在使用这些新功能前按适用要求更新说明及必要的权限或同意流程。本页面会标明更新日期。

## 7. 未成年人

本产品并非专门面向儿童提供的服务。未成年人应在监护人指导下使用音乐平台及其账号，并遵守适用年龄要求。如你认为在支持渠道向我们提交了不应保留的未成年人信息，请联系开发者处理。

## Website and English summary

This policy covers the Mineradio iPhone/iPad client. Music credentials, preferences, playback information and caches are primarily processed locally. When you connect to a music provider, required account/request information is sent to that provider and its infrastructure. Current app diagnostics remain local; no developer-operated advertising or analytics backend is configured. Information you voluntarily submit by email or public GitHub issues is used for support. Contact swordingk@gmail.com for privacy questions. This documentation website is hosted by GitHub Pages, whose infrastructure may process visitor request information under GitHub's privacy statement.

本说明网站托管于 GitHub Pages。访问本站会由 GitHub 等基础设施处理正常的网站请求信息，详见 https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement 。

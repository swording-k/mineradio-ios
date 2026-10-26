# iOS / iPad independent repository rules

- 本目录是 iOS / iPad 独立本地仓库，2026-10-26 从 Apple 开发工作目录复制，保留提交历史和当时未提交的开发内容。
- 后续 iOS / iPad 开发以 `/Users/baojian/Desktop/Mineradio-iOS` 为入口；主客户端位于 `apps/apple`，共享网页资产与打包脚本仍保留在仓库根目录。
- 用户要求以后以 GitHub 私有仓库管理。本仓库目前没有 remote；仅连接用户指定的私有仓库，不推到公开社区版或原上游。保留现有 LICENSE 与第三方署名。
- 构建以 `apps/apple/README.md` 和 `apps/apple/project.yml` 为准。根目录 README 及部分下方规则继承自桌面仓库，应结合本节理解；桌面发布状态不代表 iOS 验收状态。
- 原工作目录 `/Users/baojian/.codex/worktrees/ipad-client/Mineradio` 保留作迁移回退。不要在两个目录交替开发；旧目录后续修改不会自动同步到本仓库。

---

# Mineradio repository rules

- 默认用简体中文说明结论，保留英文代码标识。
- 先阅读 `docs/DEVELOPMENT.md` 和 `docs/RELEASE_STATUS.md`。GitHub Issue / PR
  保存问题与验收记录；Release 及对应 tag 保存真实对外版本。
- 一个共享 `main`，按 Issue 建短期分支；不要维护长期 Mac / Windows 分叉。
  平台差异进入能力适配层。共享文件修改必须检查 Windows 与 macOS 的影响。
- 每个独立 bug / 功能关联 Issue，提交须说明目的；PR 记录根因、平台影响、
  已跑检查和未完成验证。未验收问题保持 open，不能随代码合并自动关闭。
- Mac 本地测试、Windows CI、安装包构建和原生交互验证是不同证据，分别报告。
  不把平台模拟、交叉编译、ARM VM 或上游已发布称为 Windows x64 实机通过。
- 用户最新明确授权官网提供已修复汽水播放的 community.3 Mac 社区预览包。
  保留已知限制，不标记稳定版；Windows 继续链接原作者 v2.2.0，未做本社区实机验收。
- 官网使用实际录屏；处理账号遮隐、裁切、静音与压缩需记录来源。不要展示虚构
  产品 UI，也不要把开发版演示说成公开包已通过的功能。保留 GPL 和上游署名。
- 不提交用户账号、Cookie、授权音源链接或测试登录数据；不在公开 CI 中接入个人账号。

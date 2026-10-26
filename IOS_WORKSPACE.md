# Mineradio iOS / iPad 工作目录

本目录为完整、独立的 Git 仓库，可直接加入 Codex 项目。

- 路径：`/Users/baojian/Desktop/Mineradio-iOS`
- 客户端源码与构建说明：`apps/apple/README.md`
- XcodeGen 配置：`apps/apple/project.yml`
- 当前基线：`dfb2e73`，分支 `codex/apple-team-alignment`，包含迁移时未提交的修改和新增文件。
- 保留全部已有历史，以及客户端依赖的根目录网页资产与构建脚本。
- 未复制可重新生成的依赖、构建缓存和安装产物；开发环境按客户端 README 准备。
- 目前没有远程地址。以后连接 GitHub 私有仓库；本次没有创建或上传远程仓库。
- 原工作目录保留作回退，后续以本桌面目录为开发入口。

同系列仓库：

| 目录 | 用途 | 远程 |
| --- | --- | --- |
| `/Users/baojian/Desktop/Mineradio` | 开源社区版 / 原上游参考 | `swording-k/Mineradio`，上游 `XxHuberrr/Mineradio-paused` |
| `/Users/baojian/Desktop/Mineradio-mac-team` | 团队 Mac 私有版 | `chyzsnb-commits/mr` |
| `/Users/baojian/Desktop/Mineradio-iOS` | iPhone / iPad 开发 | 尚未连接，未来使用私有仓库 |

## 远程备份准备（2026-10-26）

- 建议远程名称：`chyzsnb-commits/mineradio-ios`，设为 Private。该名称仅为建议，尚未创建。
- 当前 CLI 与 GitHub 连接器均登录 `swording-k`。该账号对团队 `mr` 有 WRITE 权限，但不能在另一位个人用户账号下创建新仓库。
- 仓库主人创建空私有仓库（不初始化 README / LICENSE / .gitignore），邀请 `swording-k` 并授予写权限后，再配置本目录的 origin 并上传。
- 本地保存一次迁移与开发中快照；快照包含尚未验收的改动，不代表新版本已测试通过。原工作目录的未提交状态保留。
- 上传前已对当前源码进行常见私钥和访问令牌格式检查，未命中；运行数据、账号文件及构建产物仍按现有忽略规则排除。

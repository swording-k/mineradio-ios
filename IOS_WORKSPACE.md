# Mineradio iOS / iPad 工作目录

本目录为完整、独立的 Git 仓库，可直接加入 Codex 项目。

- 路径：`/Users/baojian/Desktop/Mineradio-iOS`
- 客户端源码与构建说明：`apps/apple/README.md`
- XcodeGen 配置：`apps/apple/project.yml`
- 历史基线：`dfb2e73`；迁移及开发中改动已保存为 `7b28e20`。以 `main` 为共享主分支，后续按任务建立短期分支。
- 保留全部已有历史，以及客户端依赖的根目录网页资产与构建脚本。
- 未复制可重新生成的依赖、构建缓存和安装产物；开发环境按客户端 README 准备。
- 远程：`https://github.com/swording-k/mineradio-ios`，Private。用户 `swording-k` 为主开发人与仓库所有者。
- 原工作目录保留作回退，后续以本桌面目录为开发入口。

同系列仓库：

| 目录 | 用途 | 远程 |
| --- | --- | --- |
| `/Users/baojian/Desktop/Mineradio` | 开源社区版 / 原上游参考 | `swording-k/Mineradio`，上游 `XxHuberrr/Mineradio-paused` |
| `/Users/baojian/Desktop/Mineradio-mac-team` | 团队 Mac 私有版 | `chyzsnb-commits/mr` |
| `/Users/baojian/Desktop/Mineradio-iOS` | iPhone / iPad 开发 | `swording-k/mineradio-ios`（Private） |

## 远程协作（2026-10-26）

- 用户已明确决定使用自己的 `swording-k` 账号创建私有仓库，不再等待其他个人账号创建。
- 邀请协作者可在 GitHub 仓库 Settings → Collaborators 中办理；本次没有邀请他人。
- 以 `main` 为默认分支，并保留 `codex/apple-team-alignment` 开发快照分支与全部祖先历史；旧桌面版本标签未作为 iOS 标签上传。
- 继承的 `.github/workflows` 是桌面构建及网站发布流程，已调整为手动触发，避免 iOS 仓库自动执行不相关发布。
- 本次为源码备份，含开发中未验收改动；没有声称通过新的功能测试，也未发布 TestFlight 或安装包。

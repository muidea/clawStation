# Windows 宿主进程支持进度

更新时间：`2026-03-28`

## 1. 本轮范围

本轮只实现并验证以下能力：

1. 支持 `Windows + host_process + host_cli` 的已有实例接入。
2. 支持该场景下的向导内接入校验。
3. 支持该场景下的 Gateway 自动发现、设备授权、Control UI 配置。

本轮明确不做：

1. Windows 新实例部署。
2. Windows deploy / upgrade / rollback / probe 全托管运维。
3. Windows 容器控制面支持。

## 2. 当前进度

### 2.1 已完成

1. `clawops` 的宿主机 CLI Windows 包装改为 PowerShell 主路径，并补常见 `openclaw / node` 路径引导。
2. `operation.adopt` 已增加 `targetPlatform` 入参，并按平台分流 SSH 探活与远端 HTTP 探测。
3. 向导已开放 `Windows` 目标平台选择。
4. 向导已限制：
   - `Windows` 只允许“已有实例接入”
   - `Windows` 只走 `host_process`
5. 默认部署根目录已支持 Windows 风格自动值。
6. 已补充前后端单测，覆盖：
   - Windows 默认路径
   - Windows 向导校验限制
   - Windows adopt / host CLI 关键命令生成
7. “打开原界面” 已按平台收敛处理：
   - `Windows + host_process` 不再强依赖 `gateway.ensureControlUiOrigins`
   - 改为直接使用已发现的 Gateway token 打开原界面
   - 保持 Linux / container 现有 Control UI 配置同步逻辑不变

### 2.2 待验证

1. `clawconsole` 前端单测回归通过。
2. `clawops` Rust 单测回归通过。
3. 本地联调至少验证一条：
   - Windows 目标机已有 OpenClaw
   - SSH 可连
   - 向导内完成接入、自动发现、自动认证
4. 需继续确认一条：
   - Windows 目标机“打开原界面”可稳定成功

## 3. 风险记录

1. Windows 远端执行当前依赖 PowerShell 可用，这是本轮的主路径假设。
2. Windows 侧 `openclaw` 的实际安装位置仍可能有环境差异，本轮只覆盖常见用户级与系统级 Node/npm 路径。
3. 当前“已有实例接入”仍默认使用 `127.0.0.1:18789`，未额外扩展 Windows 专属端口引导。
4. Windows `openclaw config set gateway.controlUi.*` 在不同安装方式下行为仍可能不一致，因此当前对 `Windows + host_process` 采取最小变更旁路策略，避免影响既有 Linux/container 能力。

## 4. 下一步

1. 完成自动化测试和一次 Windows 目标机实机联调。
2. 根据联调结果决定是否继续做：
   - Windows host_process 的 probe/logs 运维动作
   - Windows 全托管 driver 抽象
3. 若 Windows 后续确认需要持久化 `gateway.controlUi.allowedOrigins`，再单独补 Windows 专属安全写配置路径，不与本轮访问打通耦合。

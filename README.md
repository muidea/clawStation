# ClawStation Workspace

`clawStation/` 是聚合工作区仓库，用来统一管理桌面产品 `ClawStation` 及其两个子模块：

* `clawconsole/`
  * GitHub: `git@github.com:muidea/clawConsole.git`
  * 桌面端实现仓库，负责 Tauri + React 前端与桌面运行时
* `clawops/`
  * GitHub: `git@github.com:muidea/clawOps.git`
  * 运维执行引擎仓库，负责 SSH / Docker / deploy / probe / lifecycle / rollback 等后台能力

## Naming

命名约定如下：

* 产品名：`ClawStation`
* 聚合仓库目录：`clawStation/`
* 子仓库目录：`clawconsole/`、`clawops/`

这意味着：

* 用户可见名称、窗口标题、打包产物统一使用 `ClawStation`
* 代码路径、submodule 路径、Git 仓库名继续使用 `clawconsole` / `clawops`

## Submodules

首次克隆后执行：

```bash
git clone git@github.com:muidea/clawStation.git
cd clawStation
git submodule update --init --recursive
```

如果子模块已有更新，执行：

```bash
git submodule update --remote --recursive
```

## Build

基础检查：

```bash
make check
make test
```

本地调试构建：

```bash
make build
make run
```

Windows 验证包：

```bash
make package-windows
```

产物位置：

* 调试输出：`output/debug/`
* 发布输出：`output/release/`
* Windows 包：`output/ClawStation-windows-x86_64-gnu.zip` 或 `output/ClawStation-windows-x86_64-msvc.zip`
* Windows staging 目录：`output/windows-gnu/` 或 `output/windows-msvc/`

## Managed Instance Rules

当前实例托管能力按实例来源区分：

* 全新部署实例
  * 支持 `deploy`、`probe`、`restart`、`rollback`
* 非全新部署的托管实例
  * 仅支持 `deploy`、`probe`
  * 不暴露 `restart`、`rollback`

## Layout

```text
clawStation/
├── clawconsole/   # desktop app submodule
├── clawops/       # ops engine submodule
├── docs/          # workspace-level docs
├── packaging/     # packaging metadata
└── Makefile       # workspace build entry
```

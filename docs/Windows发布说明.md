# ClawStation Windows 发布说明

## 1. 文档目的
本文档用于统一当前 `ClawStation + ClawOps` 的 Windows 构建、发布和验证包约定，避免 `gnu` / `msvc`、`debug` / `release`、本地验证包 / CI 产物之间出现口径不一致。

## 2. 当前结论

### 2.1 唯一保留的 Windows 目标
当前仓库仅保留：

* `x86_64-pc-windows-gnu`

当前不再保留：

* `x86_64-pc-windows-msvc`

结论：

* Windows 编译路径统一走 `gnu`
* Windows 发布包统一走 `gnu`
* GitHub Actions 中只保留 `windows-gnu` 工作流

### 2.2 唯一保留的验证包类型
后续对外提供的 Windows 验证包，默认统一为：

* `release` 版本 zip 包

当前不再把 `debug` 包作为默认验证交付物。

## 3. 当前标准产物

### 3.1 标准 zip 名称
当前标准发布物命名为：

* `ClawStation-windows-x86_64-gnu.zip`

本地手工验证时允许追加日期、说明后缀，例如：

* `ClawStation-windows-x86_64-gnu-release-20260328.zip`

但基础命名口径必须保持 `ClawStation + windows + x86_64 + gnu`。

### 3.2 zip 内最小内容
标准 Windows zip 至少应包含：

* `clawstation.exe`
* `clawops.exe`
* `WebView2Loader.dll`

说明：

* `clawstation.exe` 为桌面端主程序
* `clawops.exe` 为后台运维执行引擎，必须和 `clawstation.exe` 放在同目录
* `WebView2Loader.dll` 需要随包提供，但系统仍需安装 Microsoft Edge WebView2 Runtime

## 4. 当前构建入口

### 4.1 clawconsole
当前保留的 Windows 构建入口：

* `make tauri-build-windows`
* `make tauri-build-windows-gnu`
* `make tauri-build-windows-gnu-release`
* `npm run tauri:build:windows`
* `npm run tauri:build:windows-gnu`

约束：

* `make tauri-build-windows` 与 `npm run tauri:build:windows` 都必须指向 `x86_64-pc-windows-gnu`
* 不再保留任何 `windows-msvc` 脚本

### 4.2 clawops
当前保留的 Windows 构建入口：

* `make build-windows`
* `make build-windows-gnu`
* `make build-windows-gnu-release`

约束：

* `make build-windows` 直接等价于 `make build-windows-gnu`
* 不再保留任何 `build-windows-msvc` 目标

## 5. 当前 CI 发布入口
当前 GitHub Actions 仅保留：

* `.github/workflows/windows-gnu-package.yml`

该工作流负责：

1. 拉取 `clawconsole` 与 `clawops`
2. 构建 `x86_64-pc-windows-gnu` release 产物
3. 组装 Windows zip 包
4. 上传 `ClawStation-windows-x86_64-gnu.zip`

## 6. 本地发布步骤
如果在本地手工生成 Windows release 验证包，按以下顺序执行：

### 6.1 构建 clawconsole
```bash
cd ./clawconsole
make tauri-build-windows-gnu-release
```

### 6.2 构建 clawops
```bash
cd ./clawops
make build-windows-gnu-release
```

### 6.3 组装 zip
从以下路径取文件并打包：

* `clawconsole/src-tauri/target/x86_64-pc-windows-gnu/release/clawstation.exe`
* `clawconsole/src-tauri/target/x86_64-pc-windows-gnu/release/WebView2Loader.dll`
* `clawops/target/x86_64-pc-windows-gnu/release/clawops.exe`

## 7. 系统前置条件
Windows 运行时仍依赖以下系统组件：

* Microsoft Edge WebView2 Runtime
* 系统 OpenSSH 相关命令，如 `ssh`、`ssh-keygen`

如果是在 Windows 本机做 `gnu` 交叉构建，还需准备：

* MinGW-w64 toolchain

## 8. 明确禁止项
以下做法视为偏离当前发布规范：

* 新增或恢复 `msvc` 的构建脚本、Makefile 目标或 workflow
* 默认提供 `debug` 包作为验证包
* 发布 zip 中遗漏 `clawops.exe`
* 发布 zip 命名继续使用 `msvc`

## 9. 涉及文件
当前与该约定直接相关的文件包括：

* `clawconsole/Makefile`
* `clawconsole/package.json`
* `clawconsole/scripts/tauri-build-windows.mjs`
* `clawops/Makefile`
* `.github/workflows/windows-gnu-package.yml`
* `packaging/windows-README.txt`

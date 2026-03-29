# ClawStation Windows 发布与安装说明

## 1. 当前正式发布资产

当前正式支持的 Windows 产品包只有：

* `ClawStation-windows-x86_64-gnu.zip`

这是用于安装和验证的唯一标准交付物。

## 2. 包内内容

标准 zip 至少包含：

* `clawstation.exe`
* `clawops.exe`
* `WebView2Loader.dll`

说明：

* `clawstation.exe` 是桌面端主程序
* `clawops.exe` 是配套后台执行程序
* `WebView2Loader.dll` 随包提供，但系统仍需安装 Microsoft Edge WebView2 Runtime

## 3. 安装方式

1. 下载 `ClawStation-windows-x86_64-gnu.zip`
2. 解压到本地目录
3. 保持 `clawstation.exe` 和 `clawops.exe` 在同一目录
4. 双击运行 `clawstation.exe`

## 4. 运行要求

Windows 运行环境至少需要：

* Microsoft Edge WebView2 Runtime
* 系统可用的 OpenSSH 相关命令

## 5. 发布口径

当前对外发布遵循以下规则：

* 正式支持的发布资产只有 `ClawStation-windows-x86_64-gnu.zip`
* GitHub Release 里的产品资产由 CI 构建并上传
* 发布脚本默认只负责生成 release notes、推送分支和 tag
* tag 推送后，由 GitHub Actions 负责生成并上传正式产品包
* 发布流程中不包含本地编译步骤

## 6. 推荐发布流程

推荐的正式发布流程如下：

1. 完成版本号、文档和代码提交
2. 推送对应分支
3. 执行发布脚本创建并推送版本 tag
4. 等待 GitHub Actions 生成 `ClawStation-windows-x86_64-gnu.zip`
5. 在 GitHub Release 页面核对 release notes 和最终资产

## 7. 关于 GitHub Source code

GitHub Release 页面可能仍会显示：

* `Source code (zip)`
* `Source code (tar.gz)`

这些文件是 GitHub 平台基于 tag 自动生成的源码快照，不是正式产品发布资产。

正式支持的安装与验证交付物仍然只有：

* `ClawStation-windows-x86_64-gnu.zip`

# ClawStation

`ClawStation` 仓库当前定位为产品发布仓库。

对外主要提供两类内容：

* 预编译后的产品安装包
* 面向使用者的安装与帮助文档

当前默认发布资产：

* `ClawStation-windows-x86_64-gnu.zip`

当前默认帮助文档：

* [安装与使用说明](./docs/使用说明.md)
* [Windows 发布与安装说明](./docs/Windows发布说明.md)

## 快速开始

1. 从 GitHub Release 下载 `ClawStation-windows-x86_64-gnu.zip`
2. 解压后保持 `clawstation.exe` 与 `clawops.exe` 在同一目录
3. 确认系统已安装 Microsoft Edge WebView2 Runtime
4. 双击运行 `clawstation.exe`

## 发布说明

当前 GitHub Release 只以预编译资产作为正式交付物。

说明：

* 正式支持的发布资产只有 `ClawStation-windows-x86_64-gnu.zip`
* GitHub 页面中自动显示的 `Source code (zip)` / `Source code (tar.gz)` 为平台生成的源码快照
* 这些源码快照不属于正式产品交付物

## 文档边界

本仓库根目录只保留对外帮助文档和发布相关说明。

更细的设计材料如需保留，会收敛到对应子项目内部，不作为发布仓库对外文档的一部分。

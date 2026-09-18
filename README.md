# FRP for ImmortalWrt / OpenWrt

[![Build and validate](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml/badge.svg)](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml)

用于编译固件时更新内置的 `frpc` / `frps`，自动跟踪 [FRP 官方稳定版](https://github.com/fatedier/frp/releases/latest)。

沿用 ImmortalWrt master 官方 LuCI 和 UCI 配置，支持 TOML，保留 INI 兼容模式。

已验证 ImmortalWrt 25.12-SNAPSHOT x86/64 实机升级，服务端显示 FRPC **v0.71.0 在线**。[验证范围](docs/VALIDATION.md)

## 使用

在固件源码根目录操作。

**1. 添加源**

在 `feeds.conf.default` 中，把这一行放在官方 `packages` 源之前；如果使用 `feeds.conf`，则修改该文件。

```text
src-git frp_custom https://github.com/itwxf0818/openwrt-frp.git;main
```

**2. 更新 feeds**

```sh
./scripts/feeds update -a
./scripts/feeds install -a
```

已有源码安装过旧 FRP 的，首次接入时再执行一次，切换来源并保留编译选项：

```sh
bash ./feeds/frp_custom/scripts/install-feed.sh
```

**3. 照常编译固件**

保留原来的 `frpc` / `frps` 和 LuCI 选项，继续原有编译流程。后续更新 feeds 即可获取本源的新版本。

## 配置

当前 ImmortalWrt master 的常用设置继续在原 LuCI 页面填写。已有完整 INI 文件或旧版 INI 附加配置，按[配置说明](docs/CONFIGURATION.md)选择对应模式。

本仓库提供编译用的源码 feed 和 Releases 安装包，不附带新的 LuCI 页面。

## 安装包下载

[Releases](https://github.com/itwxf0818/openwrt-frp/releases) 按 `v上游版本-软件包修订` 命名，例如 `v0.71.0-3`。旧的 `v0.71.0-r3` 保留为历史源码发布。

安装包使用 **ImmortalWrt 25.12.2 SDK** 构建，每种架构分别提供 frpc / frps：

| 软件包架构 | 构建目标 |
| --- | --- |
| `x86_64` | x86/64 |
| `aarch64_cortex-a53` | mediatek/filogic |
| `arm_cortex-a7_neon-vfpv4` | ipq40xx/generic |
| `mipsel_24kc` | ramips/mt7621 |

文件名示例：`frpc_0.71.0-r3_x86_64.apk`。先在设备执行 `apk --print-arch` 核对软件包架构，同时确认固件系列匹配。APK 不能用于 opkg/IPK 系统；不要改后缀或强制安装。其他固件继续通过 feed 编译。

升级前备份配置，并阅读[旧 LuCI / INI 配置说明](docs/CONFIGURATION.md)。新装默认关闭，需先配置。安装包由 SDK 构建验证；目前实机反馈覆盖 x86_64，其余架构尚待实机验证。每次发布附 `SHA256SUMS` 与构建来源记录。

## 自动更新

每天北京时间 **07:00** 检查上游稳定版。没有新版时只检查，不重复构建。发现新版后，更新版本和源码校验值，测试及七组 SDK 构建全部通过后自动提交，并发布到 [Releases](https://github.com/itwxf0818/openwrt-frp/releases)，例如 `v0.71.1-1`。

通常在下次定时检查后，加上构建时间完成更新；GitHub 调度或下载可能延迟。验证失败时不提交、不发布。也可在 Actions → Update FRP → Run workflow 手动检查。Releases 提供源码及通过验证的安装包；路由器不会自动升级。

若提交成功但 Release 发布失败，可在对应运行页面选择 Re-run failed jobs 重试；默认分支已发生其他变更时会停止，需人工核对。

[构建状态](https://github.com/itwxf0818/openwrt-frp/actions) · [验证记录](docs/VALIDATION.md) · [源码与兼容基准](docs/SOURCES.md)

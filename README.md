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

本仓库是编译用的源码 feed；不提供路由器软件包管理器的订阅地址，也不附带新的 LuCI 页面。

## 自动更新

每天北京时间 **07:00** 检查上游稳定版。没有新版时只检查，不重复构建。发现新版后，更新版本和源码校验值，测试及四组 SDK 构建全部通过后自动提交，并发布到 [Releases](https://github.com/itwxf0818/openwrt-frp/releases)，例如 `v0.71.1-r1`。

通常在下次定时检查后，加上构建时间完成更新；GitHub 调度或下载可能延迟。验证失败时不提交、不发布。也可在 Actions → Update FRP → Run workflow 手动检查。Releases 提供源码，路由器需重新编译、升级后才会使用新版。

若提交成功但 Release 发布失败，可在对应运行页面选择 Re-run failed jobs 重试；默认分支已发生其他变更时会停止，需人工核对。

[构建状态](https://github.com/itwxf0818/openwrt-frp/actions) · [验证记录](docs/VALIDATION.md) · [源码与兼容基准](docs/SOURCES.md)

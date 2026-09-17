# 验证记录

验证日期：2026-09-17。本文记录本地验证与 SDK 集成测试结果。后续提交的构建状态见 [GitHub Actions](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml)。

## 当前 master 适配（0.71.0-r3）

默认采用官方 master UCI→TOML 逻辑，保留原生 INI/TOML 和显式旧 UCI→INI 模式。代码提交 `549f4b328b116979f708e93e005342edca8cb3a6`，[完整构建 #35188437245](https://github.com/itwxf0818/openwrt-frp/actions/runs/35188437245) 已全部通过。

本地和 CI 已验证客户端及服务端的现代字段映射、列表/映射参数、TLS、代理配置、缺失附加文件、无效端口，以及原有 INI 回归测试。生成的 TOML 通过真实 FRP 校验；INI/TOML 实际隧道与四类 CPU 交叉编译已通过。另用 OpenWrt 实际 UCI shell 函数加载官方 master 默认配置，生成的两组 TOML 均通过 FRP 校验，procd 仍使用测试替身。

| r3 SDK 构建 | 结果 |
| --- | --- |
| ImmortalWrt master snapshot x86/64 | 通过 |
| ImmortalWrt master snapshot mediatek/filogic（ARM64） | 通过 |
| ImmortalWrt 25.12.2 x86/64 | 通过 |
| OpenWrt snapshot x86/64 | 通过 |

已下载并检查本轮 ImmortalWrt master x86 产物，包含 frpc/frps 0.71.0-r3 APK 和 SDK/feed 来源记录。SDK 为官方 snapshot `immortalwrt-sdk-x86-64_gcc-14.4.0_musl.Linux-x86_64.tar.zst`，SHA256 为 `7de81f3f74f78bc8195ead9ae887d6caa1c1834ab92d1d6c4393f6267d882fe7`。尚未在用户设备上执行升级、LuCI 页面操作或服务重启测试；SDK 构建成功不等于这些实机测试已完成。

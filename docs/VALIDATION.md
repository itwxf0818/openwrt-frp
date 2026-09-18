# 验证记录

验证日期：2026-09-17。本文记录本地验证与 SDK 集成测试结果。后续提交的构建状态见 [GitHub Actions](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml)。

## 实机升级反馈

2026-09-17，用户在 ImmortalWrt 25.12-SNAPSHOT x86/64 环境编译并升级固件，反馈刷机成功。升级前提供的 manifest 确认 `frpc 0.71.0-r3`；rootfs 中的启动脚本、兼容脚本与仓库一致，原 LuCI 客户端页面包仍包含在固件中。

升级后用户提供的服务端截图显示两台 ImmortalWrt 客户端版本为 **v0.71.0**，状态均为 **Online**。这确认了所展示客户端能够运行新版并连接服务端；尚未收到逐项代理访问、再次重启恢复或长期稳定性测试结果，不代表全部设备及配置均已验证。记录不包含设备标识、IP、域名或认证信息。

## 直接添加 feed 的目录修复

原仓库将 Makefile 放在根目录，ImmortalWrt 25.12 的扫描规则会把 Makefile 内容误识别成包路径，导致 `target pattern contains no '%'`。此前 SDK 测试先将文件放入临时 `frp/` 子目录，未覆盖用户直接添加 Git 源的目录结构；此前的 SDK 成功记录不能证明旧目录结构可直接添加为 feed。

现在将软件包及运行文件放入 `frp/`，SDK 沿用同一目录结构。新增回归测试对仓库文件执行官方包发现规则，确认只发现 `frp`，并重现旧根目录结构的失败。切换脚本也验证了不带参数时选择 `frp/`，并保留原编译配置。FRP 版本及运行文件内容不变。

修复提交 `386257fd8b1b321901f0a14d2fb5eb3623b2d0ce` 的[完整构建](https://github.com/itwxf0818/openwrt-frp/actions/runs/35191253702)已通过，包括源码检查及四组 SDK 构建。

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


## 多架构安装包发布（2026-09-18）

提交 `776992a` 的[完整发布构建](https://github.com/itwxf0818/openwrt-frp/actions/runs/35297677694)已通过：源码检查、INI/TOML 运行测试、四类 CPU 交叉编译，以及七组官方 SDK 构建。

SDK 覆盖 ImmortalWrt snapshot x86/64、mediatek/filogic，OpenWrt snapshot x86/64，以及 ImmortalWrt 25.12.2 的 x86/64、mediatek/filogic、ipq40xx/generic、ramips/mt7621。各任务先验证 SDK 密钥兼容性和小包签名，再编译并严格验证 frpc/frps APK 签名。

[发布 v0.71.0-3](https://github.com/itwxf0818/openwrt-frp/releases/tag/v0.71.0-3)包含稳定版 SDK 生成的 8 个 APK、4 个公钥、构建来源归档及 SHA256SUMS，共 14 个附件。已核对全部 APK 文件名和校验清单中的 13 个文件摘要与 GitHub 资产摘要一致。安装包名称为 `frpc_0.71.0-r3_架构.apk` / `frps_0.71.0-r3_架构.apk`。

此前失败来自 SDK 签名工具及 OpenSSL/LibreSSL 配置、参数差异，已修复；未修改设备端 FRP 启动和配置逻辑。以上验证不代表四类架构都已完成实机安装测试。

# 验证记录

验证日期：2026-09-17。本文记录本地验证与 SDK 集成测试结果。后续提交的构建状态见 [GitHub Actions](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml)。

## INI / ImmortalWrt 25.12 兼容更新（0.71.0-r2）

对应最终代码提交 `2dac8d0c73e981ba5d6e996e5b563deebb8cbf85`，[完整构建 #35186153160](https://github.com/itwxf0818/openwrt-frp/actions/runs/35186153160) 已全部通过。

- 以官方 `openwrt-25.12` 的 `init` / `conf` 结构为兼容基准，继续生成 INI；不修改上游 FRP，也不替换 LuCI。
- 本地与 CI 已通过：默认关闭、文件路径检查、示例口令拦截、配置验证失败、旧 UCI 转 INI、代理名称、禁用代理、附加 INI、环境变量与 procd 参数、完整 INI/TOML 入口、早期 `main` 配置兼容，以及官方 LuCI 固定读取的 `instance1` 实例名。
- 两种格式均以真实 `frpc` / `frps` 完成 token 认证、TLS 连接和 HTTP 转发；Linux 四类 CPU 交叉编译通过。CI 在源码构建后再次用真实 FRP 校验启动脚本生成的 INI。
- 另在本地将 OpenWrt 的实际 UCI shell 函数与官方 25.12 默认 frpc/frps 配置组合验证：生成的 INI 均通过 FRP 检查，用户和组参数传递正确；procd 与 chown 使用测试替身，不代表设备上已运行。
- SDK 使用各自官方工具链和 feed，全部生成 frpc/frps 0.71.0-r2 APK，并上传构建来源记录。

| 最终提交的 SDK 验证 | 结果 |
| --- | --- |
| ImmortalWrt 25.12.2 x86/64 | 通过 |
| ImmortalWrt snapshot x86/64 | 通过 |
| ImmortalWrt snapshot mediatek/filogic（ARM64） | 通过 |
| OpenWrt snapshot x86/64 | 通过 |

已下载并核对最终 25.12.2 产物：包含两个 0.71.0-r2 APK、SDK URL/hash、feed 提交、feed 配置和编译配置。SDK 为官方 `immortalwrt-sdk-25.12.2-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst`，SHA256 为 `4d4631f134c2f27215a91aa7ef5bf9a01ea96c2450d3b8a5c38048c32462ac60`。

尚未在真实路由器上测试刷机、服务重启和升级配置保留；也未覆盖第三方 LuCI 的不同配置格式。上游 INI 弃用警告属于预期输出，自动更新必须通过 INI 隧道测试才能合入。

## 首版 SDK 集成验证（0.71.0-r1）

[完整构建 #35178720548](https://github.com/itwxf0818/openwrt-frp/actions/runs/35178720548) 已全部通过，对应代码提交 `7b3dbd0ce6228015df573ac8261684a10e223e22`。

| 构建环境 | 结果 | 产物 |
| --- | --- | --- |
| ImmortalWrt snapshot x86/64 | 通过 | frpc / frps 0.71.0-r1 APK |
| ImmortalWrt snapshot mediatek/filogic（ARM64） | 通过 | frpc / frps 0.71.0-r1 APK |
| OpenWrt snapshot x86/64 | 通过 | frpc / frps 0.71.0-r1 APK |

软件包与 SDK URL/hash、feed 提交及编译配置可在该次工作流的 Artifacts 中获取。此结果验证了软件包构建，不代表已完成路由器刷机、旧版 LuCI 配置迁移或稳定版固件兼容性测试。

本次修复了 SDK 工作目录被递归扫描的问题，并将同名 feed 的切换封装为 `scripts/install-feed.sh`。切换脚本会保留 `.config`，新增回归测试覆盖了切换成功与安装失败时的配置恢复行为。

## 本地验证结果

| 检查 | 结果 |
| --- | --- |
| 官方稳定 Release 核实 | v0.71.0 |
| 官方 tag 源码包独立下载、SHA256 计算 | 通过，与 OpenWrt 当前配方一致 |
| 包元数据、TOML 语法、默认禁用开关、LF/BOM 检查 | 通过 |
| 更新器回归测试 | 5 项通过：拒绝预览版/异常标签、数字排序、最小修改、禁止降级/同版重算、下载失败不写入 |
| 两组 init 启动逻辑测试 | 通过：默认关闭、缺失文件、相对路径、示例 token、verify 失败均正确处理；合法配置传入 procd mock |
| ShellCheck 0.11.0 | 两个 init、SDK 脚本、init 测试脚本通过；明确允许 BusyBox ash 的 local 扩展 |
| actionlint 1.7.12 | 两个 GitHub Actions 工作流及其内嵌 shell 检查通过 |
| Windows amd64 原生源码编译 | frpc、frps 均通过；Go 1.27.1，CGO_ENABLED=0，noweb |
| 上游官方配置验证 | 两个示例 TOML 均通过对应 `frpc/frps verify` |
| 实际隧道测试 | 本机启动 frps/frpc，经 token 认证与 TLS 建立连接，成功将 HTTP 请求转发到本地服务并验证返回内容 |
| Linux amd64 交叉编译 | frpc、frps 均通过 |
| Linux arm64 交叉编译 | frpc、frps 均通过 |
| Linux arm / GOARM=7 交叉编译 | frpc、frps 均通过 |
| Linux mipsle / GOMIPS=softfloat 交叉编译 | frpc、frps 均通过 |

交叉编译使用相同的官方源码与 noweb 标签。Go 模块通过镜像下载以解决本机网络停滞，保留正常 Go 校验机制。未修改 FRP 源码。

## 验证范围

- **完整 OpenWrt / ImmortalWrt SDK 打包**：已在 GitHub Actions 的 Linux 环境中完成上述三组 snapshot 构建。
- **真实路由器 procd、重启、升级配置保留测试**：需要匹配的固件和设备；mock 不等于实机。
- **持续集成与自动更新**：SDK 构建结果以各次工作流为准；定时版本提交链路需在发现新稳定版时验证。
- **旧稳定分支和所有 CPU/设备的兼容性**：未验证；不能从四类 CPU 的纯 Go 交叉编译推断所有软件包 ABI 兼容。

## 持续集成流程

首次 push 到 main 或手动运行 Build and validate：

1. 静态检查、5 项更新器测试、两组 init 行为测试及 feed 切换回归测试。
2. 校验源码 hash，以 go.mod 指定的 Go 版本构建并运行真实本机隧道测试。
3. Linux amd64 / arm64 / arm / mipsle 纯 Go 交叉编译。
4. 官方 SDK 矩阵：ImmortalWrt 25.12.2 x86/64，加上 ImmortalWrt x86/64、ImmortalWrt mediatek/filogic、OpenWrt x86/64 三组 snapshot，编译并打包 frpc/frps。
5. 上传成功生成的软件包和 SDK/feed 来源记录。

定时更新调用同一套完整验证，全部通过才提交 Makefile。若 snapshot、Go 工具链、下载服务或包框架发生变化，工作流可能失败；此时应依据日志修复，验证通过前不提交版本更新。

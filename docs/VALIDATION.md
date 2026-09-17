# 首版验证记录

验证日期：2026-09-17。此文记录首版交付状态，不代表以后每次提交的 CI 结果。

## 已实际完成

| 检查 | 结果 |
| --- | --- |
| 官方稳定 Release 核实 | v0.71.0 |
| 官方 tag 源码包独立下载、SHA256 计算 | 通过，与 OpenWrt 当前配方一致 |
| 包元数据、TOML 语法、默认禁用开关、LF/BOM 检查 | 通过 |
| 更新器回归测试 | 5 项通过：拒绝预览版/异常标签、数字排序、最小修改、禁止降级/同版重算、下载失败不写入 |
| 两组 init 启动逻辑测试 | 通过：默认关闭、缺失文件、相对路径、示例 token、verify 失败均正确处理；合法配置传入 procd mock |
| ShellCheck 0.11.0 | 两个 init、SDK 脚本、init 测试脚本通过；明确允许 BusyBox ash 的 local 扩展 |
| actionlint 1.7.12 | 两个 GitHub Actions 工作流及其内嵌 shell 检查通过 |
| Windows 上传助手 | PowerShell 语法解析通过，未执行真实上传 |
| Windows amd64 原生源码编译 | frpc、frps 均通过；Go 1.27.1，CGO_ENABLED=0，noweb |
| 上游官方配置验证 | 两个交付 TOML 均通过对应 `frpc/frps verify` |
| 实际隧道测试 | 本机启动 frps/frpc，经 token 认证与 TLS 建立连接，成功将 HTTP 请求转发到本地服务并验证返回内容 |
| Linux amd64 交叉编译 | frpc、frps 均通过 |
| Linux arm64 交叉编译 | frpc、frps 均通过 |
| Linux arm / GOARM=7 交叉编译 | frpc、frps 均通过 |
| Linux mipsle / GOMIPS=softfloat 交叉编译 | frpc、frps 均通过 |

交叉编译使用相同的官方源码与 noweb 标签。Go 模块通过镜像下载以解决本机网络停滞，保留正常 Go 校验机制。未修改 FRP 源码。

## 尚未完成，不能视作已通过

- **完整 OpenWrt / ImmortalWrt SDK 打包**：本机为 Windows，没有可用 Linux/WSL 或 Docker SDK 环境，因此没有在本机生成可安装的 ipk/apk。
- **真实路由器 procd、重启、升级配置保留测试**：需要匹配的固件和设备；mock 不等于实机。
- **GitHub Actions 线上执行及定时提交**：当前没有可调用的 GitHub connector；文件仍在本地。需要上传后第一次运行。
- **旧稳定分支和所有 CPU/设备的兼容性**：未验证；不能从四类 CPU 的纯 Go 交叉编译推断所有软件包 ABI 兼容。

## 上传后自动执行

首次 push 到 main 或手动运行 Build and validate：

1. 静态检查、5 项更新器测试、两组 init 行为测试。
2. 校验源码 hash，以 go.mod 指定的 Go 版本构建并运行真实本机隧道测试。
3. Linux amd64 / arm64 / arm / mipsle 纯 Go 交叉编译。
4. 官方 snapshot SDK 矩阵：ImmortalWrt x86/64、ImmortalWrt mediatek/filogic、OpenWrt x86/64，真正编译和打包 frpc/frps。
5. 上传成功生成的软件包和 SDK/feed 来源记录。

定时更新调用同一套完整验证，全部通过才提交 Makefile。若 snapshot、Go 工具链、下载服务或包框架发生变化，工作流可能失败；此时应依据日志修复，不能跳过验证自动提交。

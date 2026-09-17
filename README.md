# FRP for OpenWrt / ImmortalWrt

[![Build and validate](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml/badge.svg)](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml)

面向 OpenWrt 与 ImmortalWrt 的 FRP 软件包源，用于在固件编译时替换内置旧版 `frpc` / `frps`，持续跟踪上游稳定版本。

基于 [fatedier/frp](https://github.com/fatedier/frp)，兼容旧版 LuCI/UCI 与 INI，支持原生 TOML，并使用 procd 管理进程。稳定版更新经自动化验证后合入，当前软件包版本见 [Makefile](Makefile)。

本仓库用于固件源码树或 SDK 的 feed/package 集成，不提供 opkg/apk 二进制订阅源。

## 快速导航

- [Feed 集成](#feed-集成) · [构建要求](#构建要求)
- [客户端配置](#客户端配置) · [服务端配置](#服务端配置)
- [自动更新](#自动更新) · [构建与验证](#构建与验证)
- [验证记录](docs/VALIDATION.md) · [仓库发布](docs/UPLOAD.md)

## Feed 集成

将本源排在官方 `packages` 源之前，首次安装 feeds 时会优先选用本源的 FRP。已启用的 `frpc` / `frps` 编译选项可以沿用。

**1. 添加源**

在源码根目录的 `feeds.conf.default` 中，将以下一行放在官方 `packages` 源之前，保留其他源配置不变。若使用独立的 `feeds.conf`，则修改该文件。

```text
src-git frp_custom https://github.com/itwxf0818/openwrt-frp.git;main
```

**2. 更新并安装 feeds**

```sh
./scripts/feeds update -a
./scripts/feeds install -a
```

全新源码、尚未安装过 feeds 时，完成以上两步即可按原流程编译固件，无需运行切换脚本或单独编译 FRP。

<details>
<summary>已有源码安装过旧 FRP：额外切换一次</summary>

调整源的顺序不会自动替换已经存在的旧包链接。完成上述 feeds 更新后，执行一次：

```sh
bash ./feeds/frp_custom/scripts/install-feed.sh
```

脚本会移除旧包的 feed 链接、安装本源，并保留原有编译配置。切换成功后，保持本源排在官方 `packages` 源之前，后续照常更新 feeds、编译固件即可，无需每次运行此脚本。若其他脚本又切回旧源，可重新执行。

</details>

> 已使用旧版官方 `luci-app-frpc` / `luci-app-frps` 时，可保留 `init` / `conf` 结构的 UCI 设置，由本包继续生成 INI。升级后检查服务日志和实际连接，详见[兼容说明](#服务管理与配置迁移)。

## 特性

| 项目 | 说明 |
| --- | --- |
| 软件包 | `frpc`、`frps`，可以独立选择、同时安装 |
| FRP 配置 | `/etc/frp/frpc.toml`、`/etc/frp/frps.toml` |
| UCI 开关 | `/etc/config/frpc`、`/etc/config/frps`，只管理开关和配置路径 |
| 服务 | `/etc/init.d/frpc`、`/etc/init.d/frps`，启动前执行官方 `verify` |
| 日志 | 输出至系统日志，可用 `logread` 查看 |
| 默认状态 | UCI 开关关闭；示例 token 未修改会拒绝启动；无自动开放防火墙规则 |
| 精简构建 | 使用上游 `noweb` 标签，不内嵌 FRP 自带的网页静态资源，不需要 Node.js |
| 版本更新 | 只跟踪官方 latest 稳定 Release；构建通过后提交版本和 SHA256 |

本包更新 FRP 核心和启动脚本，不附带 LuCI 页面或 FRP 内置网页资源。旧版官方 LuCI 的 UCI 配置可继续使用，也可指定完整 INI/TOML 文件。当前不适配 ImmortalWrt master 新 LuCI 的全部 TOML 专用选项。

## 构建要求

- Linux 上的 OpenWrt / ImmortalWrt 源码树或 SDK，并已准备官方要求的构建依赖。
- 标准 `packages` feed，且目录为 `feeds/packages`，包含 `lang/golang/golang-package.mk`。
- FRP 0.71.0 的 `go.mod` 要求 **Go ≥ 1.25.0**。构建使用 `packages` feed 提供的 Go 主机工具链。
- CI 构建矩阵包括 ImmortalWrt 25.12.2 x86/64，以及三个 snapshot SDK：ImmortalWrt x86/64、ImmortalWrt mediatek/filogic（ARM64）、OpenWrt x86/64。每次构建保留 SDK 与 feed 来源记录。
- 旧版固件分支需确认 Go 工具链满足上游要求。版本不足时，应按对应分支规范更新 Go 构建支持，或固定兼容的 FRP 版本。
- 目标设备需具备足够的内存与存储空间，资源需求以实际构建产物和运行负载为准。

<details>
<summary>其他方式：独立软件包集成</summary>

## 独立软件包集成

也可将仓库直接放入 `package/frp`，与 Feed 集成方式二选一。准备依赖并移除默认 FRP 的安装链接后执行：

```sh
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds uninstall frp
git clone https://github.com/itwxf0818/openwrt-frp.git package/frp
make menuconfig
make defconfig
make package/frp/compile -j2 V=s
```

已有 `package/frp` 目录时，需先确认其来源并保留本地修改。后续更新：

```sh
git -C package/frp pull --ff-only
```

此方式同样依赖 `feeds/packages/lang/golang`，无需额外添加 `frp_custom` feed。

</details>

## 已有 LuCI / INI 配置

使用旧版 ImmortalWrt 官方 LuCI（`luci-app-frpc` / `luci-app-frps`）时，保留原有软件包选择和 `/etc/config/frpc` / `/etc/config/frps` 即可。启动脚本读取 `config init`、`config conf 'common'` 及代理节，生成 `/var/etc/frpc.ini` / `/var/etc/frps.ini`，校验后启动。

- **页面填写的设置**：仍从原 UCI 配置读取，不需要手动改成 TOML。
- **附加 INI**：保留原 `init` 节中的 `list conf_inc` 和代理节的 `list _` 原始配置行。
- **已保存的完整 INI**：可在 `init` 节设置 `option config_file '/etc/frp/frpc.ini'`（服务端对应 `frps.ini`）。此时直接读取文件，忽略 UCI 的 `conf` 节，页面中的代理设置不再参与生成。若设置了运行用户，需确保该用户能读取配置文件并访问其父目录。
- **新安装**：默认关闭，先填写配置，再将 `init` 节的 `enabled` 设为 `1`。原官方配置没有此开关时沿用原服务启动方式，不会强制关闭已配置服务。

FRP 0.71.0 仍能读取 INI，但上游已将它列为弃用格式；新功能不保证支持 INI。自动更新会验证 INI 配置和实际隧道，失败时不会自动合入新版本。

日志中的 `ini format is deprecated` 是弃用提示，不表示启动失败；服务状态与隧道是否正常仍以连接日志和实际访问结果为准。

### 官方 LuCI 的变化

核对日期：2026-09-17。ImmortalWrt **`openwrt-25.12` 的官方 LuCI 和启动脚本仍采用 UCI → INI**，本阶段以此为兼容基准；`openwrt-23.05` 的启动脚本与其一致。`master` 的 LuCI 和启动脚本已采用 **UCI → TOML**。更新本 feed 不会自动更新 LuCI，也不能以开发分支的变化推断某个固件版本已经更新。

本阶段优先兼容旧版官方页面，保留 INI 运行方式。若使用 master 新 LuCI 的 TOML 专用功能，应使用与其配套的官方生成器；本包当前可通过完整 TOML 文件使用上游新功能。第三方同名 LuCI 插件可能使用不同配置结构，不能仅凭页面名称认定兼容。FRP 上游自身的网页面板与 OpenWrt LuCI 是不同组件。来源见[核对记录](docs/SOURCES.md#ini--luci-兼容基准)。

## 客户端配置

客户端连接至已部署的 `frps` 服务端。两端版本需兼容；路由器作为客户端通常无需开放入站端口。

编辑 `/etc/frp/frpc.toml`，按部署环境设置服务端地址、认证口令及代理端口。`serverAddr` 使用主机名或 IP 地址，不含协议前缀。

```toml
serverAddr = "frp.example.com"
serverPort = 7000
auth.method = "token"
auth.token = "替换为你生成的长随机口令，并与服务端保持一致"
transport.tls.enable = true
log.to = "console"
log.level = "info"

[[proxies]]
name = "my-web"
type = "tcp"
localIP = "192.168.1.100"
localPort = 8080
remotePort = 6000
```

然后执行：

```sh
chmod 600 /etc/frp/frpc.toml
frpc verify -c /etc/frp/frpc.toml
uci set 'frpc.@init[0].config_file=/etc/frp/frpc.toml'
uci set 'frpc.@init[0].enabled=1'
uci commit frpc
/etc/init.d/frpc enable
/etc/init.d/frpc restart
logread -e frpc
```

UCI `enabled=1` 控制服务是否允许运行，`init.d enable` 控制开机启动。初始 UCI 状态为关闭，即使安装时已创建启动链接，服务也不会自动运行。

## 服务端配置

服务端通常部署在具备公网入口的主机上。在 OpenWrt / ImmortalWrt 上部署时，配置步骤如下：

1. 设置 `/etc/frp/frps.toml` 中的认证口令，与客户端保持一致。
2. 默认 `bindAddr` 和 `proxyBindAddr` 都是 `127.0.0.1`，只供本机访问。需要外部连接时，明确改为需要监听的地址；监听所有 IPv4 地址使用 `0.0.0.0`。
3. `allowPorts` 限定客户端可申请的代理端口；示例仅允许 6000。
4. 根据实际网络，在路由器防火墙/公网服务器安全组中放行控制端口与代理端口。本包不会自动开放它们。

```sh
chmod 600 /etc/frp/frps.toml
frps verify -c /etc/frp/frps.toml
uci set 'frps.@init[0].config_file=/etc/frp/frps.toml'
uci set 'frps.@init[0].enabled=1'
uci commit frps
/etc/init.d/frps enable
/etc/init.d/frps restart
logread -e frps
```

示例启用 TLS 加密和 token 认证；如需验证服务端证书身份，应按 [FRP TLS 文档](https://gofrp.org/en/docs/features/common/network/network-tls/) 配置可信 CA/证书。认证口令与私钥应在部署环境中管理，不纳入版本控制。

## 服务管理与配置迁移

```sh
/etc/init.d/frpc restart   # 修改 INI/TOML 后重启使其生效
/etc/init.d/frpc stop      # 停止当前进程
/etc/init.d/frpc disable   # 取消开机启动
uci set 'frpc.@init[0].enabled=0'
uci commit frpc
```

服务端使用对应的 `frps` 命令。reload 通过重启进程加载配置，期间现有隧道连接会中断。UCI 变更支持 procd reload 触发；直接编辑 INI/TOML 后需执行 restart。

默认配置以 OpenWrt `conffiles` 声明，正常升级时由包管理器保留；如果有 `.opkg-dist` / `.apk-new` 等新配置文件，需比较后合并。保留清单包括两个 UCI 文件、`/etc/frp/frpc.toml` / `frps.toml`、`/etc/frp/frpc.ini` / `frps.ini` 和 `frpc.d` / `frps.d` 目录；其他自定义路径需自行纳入备份。

升级前备份 `/etc/config/frpc`、`/etc/config/frps` 和 `/etc/frp`。旧版官方 `init` / `conf` 配置可原样保留；不要用仓库默认文件覆盖已有配置。生成的 INI 使用受限权限，并保留 `init` 的用户、组、日志、环境变量和进程重启选项；指定的自定义账户需在系统中存在。

本源早期版本的 `config frpc 'main'` / `config frps 'main'` 也继续支持，仍读取该节的 `enabled` 和 `config_file`。这一模式优先于旧 UCI 生成方式；这些安装应继续使用原 `main` 节管理，不执行上面的 `@init[0]` 示例。切换回旧 LuCI 时，应先备份，再去掉 `main` 节并恢复原 `init` / `conf` 配置。

附加 INI 和 TOML 不能混合拼接。旧配置中特殊字段是否仍被新 FRP 接受，以 `verify`、启动日志与实际连接为准；自动化测试不能代替实际设备升级测试。

本项目与官方 feed 使用相同包名。同版本切换来源时，需重新构建固件或显式重新安装目标来源的软件包。安装产物应与固件系列、架构、libc 及包格式匹配；snapshot 产物的兼容范围以对应 SDK 为准。

## 自动更新

`Update FRP` 每天北京时间 10:23（UTC 02:23）检查上游 `releases/latest`，也支持在 [Actions](https://github.com/itwxf0818/openwrt-frp/actions/workflows/update-frp.yml) 手动触发。定时执行可能因 GitHub 调度延迟。

1. 拒绝 draft、prerelease 和非 `v数字.数字.数字` 标签；按数字比较，避免降级。
2. 下载 `codeload.github.com/fatedier/frp/tar.gz/v版本`，计算 SHA256，并确认源码包含正确的 Go module。
3. 生成候选 Makefile，修改 `PKG_VERSION` / `PKG_HASH`，将 `PKG_RELEASE` 重置为 1。
4. 在同一次运行中调用完整构建：静态检查、更新器回归测试、INI/TOML 原生隧道测试、四类 CPU 交叉编译、四组官方 SDK 软件包构建。
5. 全部验证通过、且默认分支在构建期间未发生变更时，由 GitHub Actions bot 提交 Makefile。更新范围仅限源码包版本与校验信息。

验证在版本提交前完成，并与更新任务处于同一次工作流中，避免依赖 `GITHUB_TOKEN` 提交后的 push 触发行为。构建产物可在对应运行页面的 Artifacts 中获取。

GitHub latest 是上游指定的最新稳定 Release，不扫描所有标签排序，也不会追踪预览版。同一版本标签若被重新打包，不会自动信任新 hash；已有构建会因 hash 不匹配而失败，留给维护者调查。

### 维护说明

- 使用仓库内置 `GITHUB_TOKEN`，无需个人访问令牌。检查和构建只有读取权限，提交 job 才获得 `contents: write`。
- 如果组织策略禁止写入，或默认分支保护不允许机器人直接提交，提交步骤会失败并保留日志，不会绕过保护。维护者可审阅已验证的候选 Makefile，再用 PR 更新。
- Actions 在长期无活动的公开仓库可能暂停定时任务；留意 GitHub 邮件/Actions 页面，必要时重新启用。
- SDK 使用官方稳定版和 snapshot，通过 HTTPS 获取同源 SHA256 清单校验完整性。产物包含 SDK URL/hash、feed commit 和构建配置，便于重现与诊断。需要严格长期重现时应保存 SDK 和完整 feed commit 对应源码。
- 上游 API、工具链或 SDK 变更导致验证失败时，自动更新将暂停提交并保留日志。Dependabot 每月检查 Actions 依赖更新。
- Actions 产物保留 14 天，候选 Makefile 保留 7 天；不自动发布二进制 Release。

## 构建与验证

Python 3.11+，脚本只用标准库：

```sh
python3 scripts/check.py
python3 -m unittest discover -s tests -v
bash tests/test_init.sh
python3 scripts/fetch-source.py
```

`fetch-source.py` 校验后写入 `work/source`，要求这个目录为空，避免旧源码混入。使用合适版本 Go：

```sh
mkdir -p work/bin
cd work/source
CGO_ENABLED=0 go build -trimpath -tags noweb -o ../bin/ ./cmd/frpc ./cmd/frps
cd ../..
python3 scripts/smoke.py work/bin
```

Ubuntu 上安装与 CI 相同的依赖后，可运行完整 SDK 验证：

```sh
bash scripts/build-sdk.sh immortalwrt x86/64
```

每次使用干净工作目录运行 SDK 构建。SDK 成功后 `dist/` 中有 `.ipk` 或 `.apk` 及来源记录。ARM / MIPS 原始 Go 交叉编译仅检查编译可行性，软件包兼容性与设备运行情况仍需通过 SDK 和实机验证。

| 现象 | 处理 |
| --- | --- |
| 提示找不到 golang-package.mk | 更新标准 packages feed，确认名称是 packages |
| 提示需要更高版本 Go | 检查 feed 的 Go 主机工具链版本；使用匹配的较新构建分支 |
| 构建版本与预期不符 | 确认本源位于 `packages` 源之前；已有旧包链接时运行一次 `bash feeds/frp_custom/scripts/install-feed.sh`，并排查重复包定义 |
| 下载 hash 不一致 | 先检查上游/镜像/SDK 是否轮换；不要用 `skip` 绕过校验 |
| 服务没有进程 | 检查 UCI enabled、main 节、示例 token 和 `frpc/frps verify` 输出 |
| 登录或端口注册失败 | 检查服务地址、token、TLS、allowPorts、防火墙和日志 |
| 定时任务没有启动 | 首次上传须包含 `.github`；检查 Actions 是否启用及默认分支是否为 main |
| 更新提交失败 | 查看分支保护、写权限，或是否有人在构建期间提交；排除后手动重跑 |

## 项目结构与参考

```text
Makefile                   一个源码构建生成 frpc/frps 两个软件包
files/                     两组 procd/UCI、共用兼容逻辑、TOML 示例
scripts/                   检查上游、源码/SDK 下载、构建、隧道验证
tests/                     更新器与服务脚本回归测试
.github/workflows/         构建与定时更新
docs/                      发布说明、验证记录、参考来源
```

详细来源与差异见 [SOURCES.md](docs/SOURCES.md)。本项目遵循 Apache-2.0，FRP 本身也采用 Apache-2.0；SDK/Go 构建框架仍受其各自许可证约束。本项目没有打包这些构建框架或旧项目源码。

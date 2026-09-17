# OpenWrt / ImmortalWrt FRP 软件源

[![Build and validate](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml/badge.svg)](https://github.com/itwxf0818/openwrt-frp/actions/workflows/build.yml)

为 OpenWrt / ImmortalWrt 编译 `frpc` 客户端和 `frps` 服务端。跟踪 [fatedier/frp 官方稳定版](https://github.com/fatedier/frp/releases/latest)，从源码编译，不下载其他平台的 FRP 二进制来冒充路由器软件包。

首版基线：**FRP 0.71.0**，2026-09-17 核实。后续实际版本以本仓库 [Makefile](Makefile) 为准。支持原生 **TOML** 配置和 **procd** 服务管理，第一阶段不提供 LuCI。

## 不懂编程，从这里开始

1. 把本项目完整上传到 `itwxf0818/openwrt-frp`，方法见 [上传说明](docs/UPLOAD.md)。务必包含 `.github` 文件夹。
2. 打开仓库 **Actions → Build and validate**。首次上传会自动检查并编译；全部绿色才表示这次 SDK 构建通过。初次可能需要几十分钟至两小时以上。
3. **Actions → Update FRP → Run workflow** 可以手动检查新版本。以后每天北京时间约 **10:23** 自动检查，GitHub 可能延迟调度。
4. 将下面的 feed 集成步骤交给你的 ImmortalWrt 固件编译流程。这个仓库是“编译固件时使用的源码源”，不能当成路由器里 opkg/apk 的二进制订阅地址。

本地交付的验证范围见 [验证记录](docs/VALIDATION.md)。Actions 尚未运行时，不能把项目描述成已通过 SDK 或真机测试。

## 提供的功能与边界

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

`noweb` 与 LuCI 是两回事：前者省去 FRP 自带的网页面板资源，后者是 OpenWrt 的管理页面。不要期待本项目提供任何一种网页配置界面。没有自动转换旧 INI/UCI 代理条目的功能。

## 构建环境要求

- Linux 上的 OpenWrt / ImmortalWrt 源码树或 SDK，并已准备官方要求的构建依赖。
- 标准 `packages` feed，且目录为 `feeds/packages`，包含 `lang/golang/golang-package.mk`。
- FRP 0.71.0 的 `go.mod` 要求 **Go ≥ 1.25.0**。实际使用的是 OpenWrt feed 构建的主机 Go，而非电脑上随手安装的 Go。
- 第一版 CI 面向当前 snapshot SDK：ImmortalWrt x86/64、ImmortalWrt mediatek/filogic（ARM64）、OpenWrt x86/64。SDK 和 feed 会变化，因此保存构建来源信息方便排查。
- 对较旧稳定固件分支（例如仍携带 Go 1.24 的分支），不保证直接编译最新 FRP。需要维护者按该分支规则升级兼容的整个 Go 构建支持，或固定较旧 FRP；不要只改一个 Go 版本号或把不同固件的二进制包混装。
- Go 支持不代表路由器内存和闪存一定足够；以具体设备构建结果为准。

## 方法一：作为 feed 集成（推荐）

以下命令在 **OpenWrt / ImmortalWrt 源码根目录**执行。先在 `feeds.conf.default` 末尾加一行（不要重复添加）：

```text
src-git frp_custom https://github.com/itwxf0818/openwrt-frp.git;main
```

然后：

```sh
./scripts/feeds update -a
./scripts/feeds install -a
# 官方 packages 也有 frp，必须最后指定使用本仓库的版本。
./scripts/feeds install -f -p frp_custom frp

readlink -f package/feeds/frp_custom/frp
grep '^PKG_VERSION:=' feeds/frp_custom/Makefile
make menuconfig
```

在菜单中选择：

```text
Network → Web Servers/Proxies → frpc / frps
```

`<*>` 表示打进固件；`<M>` 表示仅生成软件包。只需客户端时，选 `frpc` 即可。

```sh
make defconfig
make package/feeds/frp_custom/frp/download V=s
make package/feeds/frp_custom/frp/compile -j2 V=s
```

之后可以照常编译完整固件。每次重新 `feeds install -a` 后，建议再执行最后那条 `install -f -p frp_custom frp`，确认选中的仍是本源。不要同时启用另一份直接放在 `package/frp` 中的包定义。

有些构建树使用独立 `feeds.conf`，此时应修改它，而不是被它覆盖的 `feeds.conf.default`。

## 方法二：直接放入 package 目录

与方法一二选一。先准备标准依赖，再解除默认 frp 的 feed 链接，不删除官方源文件：

```sh
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds uninstall frp
git clone https://github.com/itwxf0818/openwrt-frp.git package/frp
make menuconfig
make defconfig
make package/frp/compile -j2 V=s
```

如果 `package/frp` 已经存在，先检查其来源和本地修改，不要覆盖它。以后更新本项目：

```sh
git -C package/frp pull --ff-only
```

这一方式也要求 `feeds/packages/lang/golang` 存在。不要再同时添加 `frp_custom` feed。

## 路由器上配置 frpc 客户端

先在有公网入口的服务器准备好兼容版本的 `frps`。路由器作为客户端一般无需开放入站端口。

编辑 `/etc/frp/frpc.toml`，下面的地址、端口和 token 必须换成你自己的；`serverAddr` 只填主机名/IP，不带 `https://`：

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
uci set frpc.main.enabled='1'
uci commit frpc
/etc/init.d/frpc enable
/etc/init.d/frpc restart
logread -e frpc
```

这里有两个开关：UCI `enabled=1` 允许启动；`init.d enable` 允许开机启动。首次安装的软件包可能已创建开机链接，但 UCI 默认关闭，仍不会启动 FRP 进程。

## 配置 frps 服务端

通常服务端运行在公网服务器，路由器只安装 frpc。如果确实要在路由器运行 frps：

1. 修改 `/etc/frp/frps.toml` 中的 token，与客户端一致。
2. 默认 `bindAddr` 和 `proxyBindAddr` 都是 `127.0.0.1`，只供本机访问。需要外部连接时，明确改为需要监听的地址；监听所有 IPv4 地址使用 `0.0.0.0`。
3. `allowPorts` 限定客户端可申请的代理端口；示例仅允许 6000。
4. 根据实际网络，在路由器防火墙/公网服务器安全组中放行控制端口与代理端口。本包不会自动开放它们。

```sh
chmod 600 /etc/frp/frps.toml
frps verify -c /etc/frp/frps.toml
uci set frps.main.enabled='1'
uci commit frps
/etc/init.d/frps enable
/etc/init.d/frps restart
logread -e frps
```

示例启用 TLS 加密和 token 认证；如需验证服务端证书身份，应按 [FRP TLS 文档](https://gofrp.org/en/docs/features/common/network/network-tls/) 配置可信 CA/证书。不要把 token、真实配置或私钥提交到 GitHub。

## 日常管理、升级与旧包迁移

```sh
/etc/init.d/frpc restart   # 修改 TOML 后重启使其生效
/etc/init.d/frpc stop      # 停止当前进程
/etc/init.d/frpc disable   # 取消开机启动
uci set frpc.main.enabled='0'
uci commit frpc
```

服务端把命令中的 `frpc` 换为 `frps`。reload 会停止并重新启动进程，已有隧道连接会短暂断开；没有承诺无损热更新。UCI 改动支持 procd reload 触发，手工编辑 TOML 后请明确 restart。

默认配置以 OpenWrt `conffiles` 声明，正常升级时由包管理器保留；如果有 `.opkg-dist` / `.apk-new` 等新配置文件，需比较后合并。自定义 `config_file` 指向的其他文件请自行纳入备份，不在默认两个 TOML 文件的保留清单内。

从官方包、kuoruan 旧包或 LuCI 配置迁移前，先备份 `/etc/config/frpc`、`/etc/config/frps`、`/etc/frp`。本包只读取 `main` 节的 `enabled` 与 `config_file`，不会读取旧的 UCI proxy 配置列表。手动建立本文的 UCI 节和 TOML，校验成功后再启用；不要继续使用会覆盖这些文件的旧 LuCI 页面。

这是独立维护的同名包，切换来源时可能出现“版本相同”的情况；同版本切换应通过重编固件或确认来源后显式重新安装处理。只安装与你的固件系列、架构、libc 和包格式匹配的产物；snapshot CI 产物不保证适用于现有稳定版固件。

## 自动追踪上游如何工作

`Update FRP` 每天检查 GitHub 的 `releases/latest`：

1. 拒绝 draft、prerelease 和非 `v数字.数字.数字` 标签；按数字比较，避免降级。
2. 下载 `codeload.github.com/fatedier/frp/tar.gz/v版本`，计算真正的 SHA256，并确认源码包含正确的 Go module。
3. 生成候选 Makefile，修改 `PKG_VERSION` / `PKG_HASH`，将 `PKG_RELEASE` 重置为 1。
4. 在同一次运行中调用完整构建：静态检查、更新器回归测试、原生隧道测试、四类 CPU 交叉编译、三组官方 SDK 软件包构建。
5. **只有全部通过**且默认分支自检查开始后没有变化，才由 GitHub Actions bot 提交 Makefile；不强推，不自动改路由器配置、不自动给路由器升级。

这里有意在提交前完成验证：使用 `GITHUB_TOKEN` 的机器人提交通常不会再触发另一轮 push 工作流，不能依赖“先提交再等另一个流程来构建”。新的包产物就在这次 `Update FRP` 的运行页面中。

GitHub latest 是上游指定的最新稳定 Release，不扫描所有标签排序，也不会追踪预览版。同一版本标签若被重新打包，不会自动信任新 hash；已有构建会因 hash 不匹配而失败，留给维护者调查。

### 权限与长期维护

- 使用仓库内置 `GITHUB_TOKEN`，无需个人访问令牌。检查和构建只有读取权限，提交 job 才获得 `contents: write`。
- 如果组织策略禁止写入，或默认分支保护不允许机器人直接提交，提交步骤会失败并保留日志，不会绕过保护。维护者可审阅已验证的候选 Makefile，再用 PR 更新。
- Actions 在长期无活动的公开仓库可能暂停定时任务；留意 GitHub 邮件/Actions 页面，必要时重新启用。
- SDK 使用官方 snapshot，通过 HTTPS 获取同源 SHA256 清单校验完整性；这不是额外签名验证。产物包含 SDK URL/hash、feed commit 和构建配置，便于重现与诊断。需要严格长期重现时应保存 SDK 和完整 feed commit 对应源码。
- 不保证未来上游 API、Go、SDK 或 Actions 永不变化。失败会停止发布，维护者应查看日志。Dependabot 每月检查 Actions 依赖更新。
- Actions 产物保留 14 天，候选 Makefile 保留 7 天；不自动发布二进制 Release。

## 本地验证与故障排查

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

每次使用干净工作目录运行 SDK 构建。SDK 成功后 `dist/` 中有 `.ipk` 或 `.apk` 及来源记录。ARM / MIPS 原始 Go 交叉编译仅检查编译可行性，不等于这些 CPU 的 OpenWrt 包和真机测试通过。

| 现象 | 处理 |
| --- | --- |
| 提示找不到 golang-package.mk | 更新标准 packages feed，确认名称是 packages |
| 提示需要更高版本 Go | 检查 feed 的 Go 主机工具链版本；使用匹配的较新构建分支 |
| 编出来的仍是旧 FRP | 最后执行 `feeds install -f -p frp_custom frp`，排查 package 目录中的重复包 |
| 下载 hash 不一致 | 先检查上游/镜像/SDK 是否轮换；不要用 `skip` 绕过校验 |
| 服务没有进程 | 检查 UCI enabled、main 节、示例 token 和 `frpc/frps verify` 输出 |
| 登录或端口注册失败 | 检查服务地址、token、TLS、allowPorts、防火墙和日志 |
| 定时任务没有启动 | 首次上传须包含 `.github`；检查 Actions 是否启用及默认分支是否为 main |
| 更新提交失败 | 查看分支保护、写权限，或是否有人在构建期间提交；排除后手动重跑 |

## 项目结构与参考

```text
Makefile                   一个源码构建生成 frpc/frps 两个软件包
files/                     两组 procd、UCI、TOML
scripts/                   检查上游、源码/SDK 下载、构建、隧道验证
tests/                     更新器与服务脚本回归测试
.github/workflows/         构建与定时更新
docs/                      上传说明、验证记录、参考来源
```

详细来源与差异见 [SOURCES.md](docs/SOURCES.md)。本项目遵循 Apache-2.0，FRP 本身也采用 Apache-2.0；SDK/Go 构建框架仍受其各自许可证约束。本项目没有打包这些构建框架或旧项目源码。

# 配置说明

## 已有 LuCI / INI 配置

使用当前 ImmortalWrt master 官方 LuCI（`luci-app-frpc` / `luci-app-frps`）时，保留原有软件包选择和 `/etc/config/frpc` / `/etc/config/frps`。启动脚本默认读取 UCI，生成 `/var/etc/frpc.toml` / `/var/etc/frps.toml`，通过上游 FRP 校验后启动。页面中的常用设置无需手工转换。

- **页面填写的设置**：采用已核实 master 官方的字段映射，支持新版数组、映射、认证、TLS 和代理设置。服务使用页面识别的 `instance1` 实例。
- **附加 TOML**：按官方约定放在 `/etc/frp/frpc.d/` 或 `/etc/frp/frps.d/`，以 `.toml` 结尾，再由 `init` 节的 `list conf_inc` 引用。
- **已保存的完整 INI**：可在 `init` 节设置 `option config_file '/etc/frp/frpc.ini'`（服务端对应 `frps.ini`）。此时直接读取文件，忽略 UCI 的 `conf` 节，页面中的代理设置不再参与生成。若设置了运行用户，需确保该用户能读取配置文件并访问其父目录。
- **新安装**：默认关闭，先填写配置，再将 `init` 节的 `enabled` 设为 `1`。原官方配置没有此开关时沿用原服务启动方式，不会强制关闭已配置服务。

<details>
<summary>继续使用旧 UCI→INI，包括 INI 附加文件</summary>

在 `init` 节设置 `option uci_format 'ini'`，可继续使用旧的 `conf_inc` INI 文件和 `list _` 原始 INI 行。以客户端为例：

```sh
uci set 'frpc.@init[0].uci_format=ini'
uci commit frpc
/etc/init.d/frpc restart
```

服务端对应 `frps`。该模式读取旧版 UCI 字段，不覆盖 master 的全部新增功能。切回 master 默认方式时，将 `uci_format` 改为 `toml`，并同步处理 INI 专用附加配置。不能将 INI 内容直接拼接到 TOML。

</details>

FRP 0.71.0 仍能读取 INI，但上游已将它列为弃用格式；新功能不保证支持 INI。自动更新会验证 INI 配置和实际隧道，失败时不会自动合入新版本。

日志中的 `ini format is deprecated` 是弃用提示，不表示启动失败；服务状态与隧道是否正常仍以连接日志和实际访问结果为准。

### 官方 LuCI 的变化

核对日期：2026-09-17。当前 **master 已采用 UCI→TOML**；25.12 和更早的 master 可能仍采用 UCI→INI。以实际安装的 LuCI 和 feeds 提交为准，不能只看固件名称。当前版本以已核实的 master 官方脚本为基准，并显式保留 INI 兼容模式。

更新本 feed 不会自动更新 LuCI。第三方同名插件可能采用不同配置结构；FRP 自身的网页面板也与 LuCI 不同。官方生成脚本采用固定提交，后续 master 新增字段时需同步核对，不能据此承诺兼容未来所有页面版本。

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

升级前备份 `/etc/config/frpc`、`/etc/config/frps` 和 `/etc/frp`；不要用仓库默认文件覆盖已有配置。标准 UCI 设置由 master 逻辑转换；若仍使用 INI 专用附加内容，先选择 `uci_format=ini`。生成配置使用受限权限，并保留 `init` 的用户、组、日志、环境变量和进程重启选项；指定的自定义账户需在系统中存在。

本源早期版本的 `config frpc 'main'` / `config frps 'main'` 也继续支持，仍读取该节的 `enabled` 和 `config_file`。这一模式优先于旧 UCI 生成方式；这些安装应继续使用原 `main` 节管理，不执行上面的 `@init[0]` 示例。切换回旧 LuCI 时，应先备份，再去掉 `main` 节并恢复原 `init` / `conf` 配置。

附加 INI 和 TOML 不能混合拼接。旧配置中特殊字段是否仍被新 FRP 接受，以 `verify`、启动日志与实际连接为准；自动化测试不能代替实际设备升级测试。

本项目与官方 feed 使用相同包名。同版本切换来源时，需重新构建固件或显式重新安装目标来源的软件包。安装产物应与固件系列、架构、libc 及包格式匹配；snapshot 产物的兼容范围以对应 SDK 为准。

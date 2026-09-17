# 核实来源（2026-09-17）

1. [FRP 最新稳定 Release](https://github.com/fatedier/frp/releases/latest)：核实为 v0.71.0。
2. [v0.71.0 源码](https://github.com/fatedier/frp/tree/v0.71.0)、[go.mod](https://github.com/fatedier/frp/blob/v0.71.0/go.mod)、[Makefile](https://github.com/fatedier/frp/blob/v0.71.0/Makefile)：Go 1.25.0，官方支持 noweb 标签和分别构建 frpc/frps。
3. [OpenWrt FRP 配方](https://github.com/openwrt/packages/blob/master/net/frp/Makefile)：核实为 0.71.0，源码 SHA256 与本项目独立下载计算结果一致。
4. [ImmortalWrt FRP 配方](https://github.com/immortalwrt/packages/blob/master/net/frp/Makefile)：核实时为 0.70.1；因此本项目明确处理同名 feed 覆盖。
5. [Go package 构建框架](https://github.com/openwrt/packages/blob/master/lang/golang/golang-package.mk)：使用 GO_PKG、GO_PKG_BUILD_PKG、GO_PKG_TAGS、GO_ARCH_DEPENDS；以标准 golang/host 为构建依赖。采用绝对 feed include 路径以兼容独立仓库。
6. [ImmortalWrt golang/host 配方](https://github.com/immortalwrt/packages/blob/master/lang/golang/golang/Makefile)：当前通过默认 Go 版本元包选择实际主机工具链。
7. [ImmortalWrt feed 配置](https://github.com/immortalwrt/immortalwrt/blob/master/feeds.conf.default)：标准 packages feed 和 feeds 机制。
8. [kuoruan/openwrt-frp](https://github.com/kuoruan/openwrt-frp)：参考独立软件源的组织方式，核实其配方为 0.57.0。本项目重新编写配置、服务脚本和自动化，没有复制旧版 UCI→INI 转换逻辑，也不据此声称兼容所有旧配置。
9. [ImmortalWrt SDK](https://downloads.immortalwrt.org/snapshots/targets/x86/64/)、[OpenWrt SDK](https://downloads.openwrt.org/snapshots/targets/x86/64/)：动态 snapshot，下载时校验 sha256sums 并保存来源。

源码包 URL：`https://codeload.github.com/fatedier/frp/tar.gz/v0.71.0`

SHA256：`1dd367d6d822a7fce1d3012fce0a6e778bc90c454e2c7baa0eb1e6de6054c61b`

上述 master、latest、snapshot 链接会变化。固定的 FRP tag/hash 和每次 CI 保存的来源记录才对应具体构建。
# INI / LuCI 兼容基准

核对于 2026-09-17。本包以旧官方 `init` / `conf` UCI 结构实现兼容，不修改 FRP 上游解析器，也不捆绑 LuCI。

- [ImmortalWrt 23.05 frpc 启动脚本](https://github.com/immortalwrt/packages/blob/openwrt-23.05/net/frp/files/frpc.init)：UCI 回调生成 INI、附加配置及 procd 参数的参考。
- [ImmortalWrt 当前 frpc 启动脚本](https://github.com/immortalwrt/packages/blob/8509f551edb7beb4a6324afca4d84b2bea404b66/net/frp/files/frpc.init)：开发分支已转换成 TOML。
- [ImmortalWrt 当前 LuCI 页面](https://github.com/immortalwrt/luci/blob/830486a7e412a83f233e9c18bd1eb3668212c799/applications/luci-app-frpc/htdocs/luci-static/resources/view/frpc.js)：仍保存 UCI，但包含新 TOML 功能；本包不宣称完整兼容此页面。
- [FRP 0.71.0 配置加载源码](https://github.com/fatedier/frp/blob/v0.71.0/pkg/config/load.go)：仍有客户端和服务端 legacy INI 加载入口。

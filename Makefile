# SPDX-License-Identifier: Apache-2.0
include $(TOPDIR)/rules.mk

PKG_NAME:=frp
PKG_VERSION:=0.71.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/fatedier/frp/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=1dd367d6d822a7fce1d3012fce0a6e778bc90c454e2c7baa0eb1e6de6054c61b

PKG_MAINTAINER:=itwxf0818
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/fatedier/frp
GO_PKG_BUILD_PKG:=github.com/fatedier/frp/cmd/frpc github.com/fatedier/frp/cmd/frps
GO_PKG_TAGS:=noweb
GO_PKG_LDFLAGS:=-s -w
GO_PKG_LDFLAGS_X:=github.com/fatedier/frp/pkg/util/version.version=$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
# Absolute feed path works both as a separate feed and under package/frp.
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/frp/default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  URL:=https://github.com/fatedier/frp
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Package/frpc
  $(call Package/frp/default)
  TITLE:=FRP client (native TOML, without web assets)
endef

define Package/frps
  $(call Package/frp/default)
  TITLE:=FRP server (native TOML, without web assets)
endef

define Package/frpc/description
  Fast reverse proxy client. Native TOML configuration and procd supervision.
  Services are disabled until explicitly configured and enabled via UCI.
endef

define Package/frps/description
  Fast reverse proxy server. Native TOML configuration and procd supervision.
  Services are disabled until explicitly configured and enabled via UCI.
endef

define Package/frpc/conffiles
/etc/config/frpc
/etc/frp/frpc.toml
endef

define Package/frps/conffiles
/etc/config/frps
/etc/frp/frps.toml
endef

define Package/frp/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config $(1)/etc/frp
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/$(2) $(1)/usr/bin/$(2)
	$(INSTALL_BIN) ./files/$(2).init $(1)/etc/init.d/$(2)
	$(INSTALL_CONF) ./files/$(2).config $(1)/etc/config/$(2)
	$(INSTALL_CONF) ./files/$(2).toml $(1)/etc/frp/$(2).toml
endef

define Package/frpc/install
	$(call Package/frp/install,$(1),frpc)
endef

define Package/frps/install
	$(call Package/frp/install,$(1),frps)
endef

$(eval $(call GoBinPackage,frpc))
$(eval $(call GoBinPackage,frps))
$(eval $(call BuildPackage,frpc))
$(eval $(call BuildPackage,frps))

include $(TOPDIR)/rules.mk

PKG_NAME:=json-sh
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/routerwrt/json.sh.git
PKG_SOURCE_VERSION:=master
PKG_MIRROR_HASH:=skip

PKG_MAINTAINER:=RouterWRT
PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/json-sh
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Tiny POSIX shell JSON parser
  URL:=https://github.com/routerwrt/json.sh
endef

define Package/json-sh/description
 Tiny POSIX shell JSON parser for RouterWRT.
endef

define Build/Compile
endef

define Package/json-sh/install
	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/lib/json.sh $(1)/lib/json.sh
endef

$(eval $(call BuildPackage,json-sh))

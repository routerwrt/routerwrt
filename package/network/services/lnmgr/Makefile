include $(TOPDIR)/rules.mk

PKG_NAME:=lnmgr
PKG_VERSION:=0.1
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/routerwrt/lnmgr.git
PKG_SOURCE_VERSION:=master
PKG_MIRROR_HASH:=skip

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/lnmgr
  SECTION:=net
  CATEGORY:=Network
  TITLE:=RouterWRT Link Manager
endef

define Package/lnmgr/description
 Deterministic, event-driven link manager for Linux.
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/lnmgr/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lnmgrd $(1)/usr/sbin/lnmgrd

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lnmgr $(1)/usr/bin/lnmgr
endef

$(eval $(call BuildPackage,lnmgr))

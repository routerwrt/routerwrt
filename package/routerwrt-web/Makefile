include $(TOPDIR)/rules.mk

PKG_NAME:=routerwrt-web
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk


#
# Common package metadata
#
define Package/routerwrt-web/Default
  SECTION:=admin
  CATEGORY:=Administration
  SUBMENU:=RouterWRT
endef


#
# Core RouterWRT web UI
#
define Package/routerwrt-web
  $(call Package/routerwrt-web/Default)
  TITLE:=RouterWRT lightweight web interface
endef

define Package/routerwrt-web/description
 Lightweight HTML/CSS/JavaScript web interface for RouterWRT.
endef


#
# Logs app
#
define Package/routerwrt-web-app-logs
  $(call Package/routerwrt-web/Default)
  TITLE:=RouterWRT Logs app
  DEPENDS:=+routerwrt-web
endef


#
# Firmware upgrade app
#
define Package/routerwrt-web-app-firmware
  $(call Package/routerwrt-web/Default)
  TITLE:=RouterWRT Firmware Upgrade app
  DEPENDS:=+routerwrt-web
endef


#
# USB app
#
define Package/routerwrt-web-app-usb
  $(call Package/routerwrt-web/Default)
  TITLE:=RouterWRT USB app
  DEPENDS:=+routerwrt-web
endef


#
# Prepare compiled sources.
#
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef


#
# Compile backend helpers.
#
define Build/Compile
	$(TARGET_CC) \
		$(TARGET_CFLAGS) \
		$(TARGET_CPPFLAGS) \
		$(TARGET_LDFLAGS) \
		-Os \
		-Wall \
		-Wextra \
		-o $(PKG_BUILD_DIR)/upgrade.cgi \
		$(PKG_BUILD_DIR)/upgrade.c
endef


#
# Core GUI
#
define Package/routerwrt-web/install
	#
	# Static web UI
	#
	$(INSTALL_DIR) $(1)/www

	$(INSTALL_DATA) \
		./files/www/index.html \
		$(1)/www/index.html

	$(INSTALL_DATA) \
		./files/www/style.css \
		$(1)/www/style.css

	$(INSTALL_DATA) \
		./files/www/core.js \
		$(1)/www/core.js


	#
	# Core CGI
	#
	$(INSTALL_DIR) $(1)/www/cgi-bin

	$(INSTALL_BIN) \
		./files/www/cgi-bin/status.sh \
		$(1)/www/cgi-bin/status.sh


	#
	# App registry fragments live here.
	#
	$(INSTALL_DIR) \
		$(1)/usr/share/routerwrt/apps.d


	#
	# Registry generator.
	#
	$(INSTALL_DIR) $(1)/usr/sbin

	$(INSTALL_BIN) \
		./files/usr/sbin/routerwrt-web-update \
		$(1)/usr/sbin/routerwrt-web-update


	#
	# Provide a valid empty registry.
	#
	printf '%s\n' \
		'export const apps = [];' \
		> $(1)/www/apps.js
endef


#
# Logs app
#
define Package/routerwrt-web-app-logs/install
	#
	# Frontend
	#
	$(INSTALL_DIR) \
		$(1)/www/apps/logs

	$(INSTALL_DATA) \
		./files/www/apps/logs/page.js \
		$(1)/www/apps/logs/page.js


	#
	# Backend
	#
	$(INSTALL_DIR) \
		$(1)/www/cgi-bin

	$(INSTALL_BIN) \
		./files/www/cgi-bin/dmesg.sh \
		$(1)/www/cgi-bin/dmesg.sh


	#
	# App registry entry
	#
	$(INSTALL_DIR) \
		$(1)/usr/share/routerwrt/apps.d

	printf '%s\n' \
		'["logs","📜","Logs","/logs","/apps/logs/page.js"]' \
		> $(1)/usr/share/routerwrt/apps.d/logs
endef


#
# Firmware app
#
define Package/routerwrt-web-app-firmware/install
	#
	# Frontend
	#
	$(INSTALL_DIR) \
		$(1)/www/apps/firmware

	$(INSTALL_DATA) \
		./files/www/apps/firmware/page.js \
		$(1)/www/apps/firmware/page.js


	#
	# Compiled CGI backend
	#
	$(INSTALL_DIR) \
		$(1)/www/cgi-bin

	$(INSTALL_BIN) \
		$(PKG_BUILD_DIR)/upgrade.cgi \
		$(1)/www/cgi-bin/upgrade.cgi


	#
	# App registry entry
	#
	$(INSTALL_DIR) \
		$(1)/usr/share/routerwrt/apps.d

	printf '%s\n' \
		'["firmware","⬆️","Firmware","/firmware","/apps/firmware/page.js"]' \
		> $(1)/usr/share/routerwrt/apps.d/firmware
endef


#
# USB app
#
define Package/routerwrt-web-app-usb/install
	#
	# Frontend
	#
	$(INSTALL_DIR) \
		$(1)/www/apps/usb

	$(INSTALL_DATA) \
		./files/www/apps/usb/page.js \
		$(1)/www/apps/usb/page.js


	#
	# App registry entry
	#
	$(INSTALL_DIR) \
		$(1)/usr/share/routerwrt/apps.d

	printf '%s\n' \
		'["usb","🔌","USB","/usb","/apps/usb/page.js"]' \
		> $(1)/usr/share/routerwrt/apps.d/usb
endef


#
# Rebuild apps.js after installation.
#
# IPKG_INSTROOT is historically named, but is also useful during
# image-root installation. On a live system it is normally empty.
#
define Package/routerwrt-web-app-logs/postinst
#!/bin/sh

ROOT="$${IPKG_INSTROOT:-}"

if [ -x "$${ROOT}/usr/sbin/routerwrt-web-update" ]; then
	"$${ROOT}/usr/sbin/routerwrt-web-update" "$${ROOT}"
fi

exit 0
endef


define Package/routerwrt-web-app-firmware/postinst
#!/bin/sh

ROOT="$${IPKG_INSTROOT:-}"

if [ -x "$${ROOT}/usr/sbin/routerwrt-web-update" ]; then
	"$${ROOT}/usr/sbin/routerwrt-web-update" "$${ROOT}"
fi

exit 0
endef


define Package/routerwrt-web-app-usb/postinst
#!/bin/sh

ROOT="$${IPKG_INSTROOT:-}"

if [ -x "$${ROOT}/usr/sbin/routerwrt-web-update" ]; then
	"$${ROOT}/usr/sbin/routerwrt-web-update" "$${ROOT}"
fi

exit 0
endef


#
# Rebuild registry after an app is removed on a live system.
#
define Package/routerwrt-web-app-logs/postrm
#!/bin/sh

if [ -x /usr/sbin/routerwrt-web-update ]; then
	/usr/sbin/routerwrt-web-update
fi

exit 0
endef


define Package/routerwrt-web-app-firmware/postrm
#!/bin/sh

if [ -x /usr/sbin/routerwrt-web-update ]; then
	/usr/sbin/routerwrt-web-update
fi

exit 0
endef


define Package/routerwrt-web-app-usb/postrm
#!/bin/sh

if [ -x /usr/sbin/routerwrt-web-update ]; then
	/usr/sbin/routerwrt-web-update
fi

exit 0
endef


$(eval $(call BuildPackage,routerwrt-web))
$(eval $(call BuildPackage,routerwrt-web-app-logs))
$(eval $(call BuildPackage,routerwrt-web-app-firmware))
$(eval $(call BuildPackage,routerwrt-web-app-usb))

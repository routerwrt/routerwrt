ifneq ($(CONFIG_USE_APK),)
  DEFAULT_PACKAGES +=
else
  DEFAULT_PACKAGES += opkg
endif

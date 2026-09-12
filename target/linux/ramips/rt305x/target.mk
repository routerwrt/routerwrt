#
# Copyright (C) 2009 OpenWrt.org
#

SUBTARGET:=rt305x
BOARDNAME:=RT3x5x/RT5350 based boards
FEATURES+=ramdisk small_flash
CPU_TYPE:=24kc

DEFAULT_PACKAGES +=

define Target/Description
	Build firmware images for Ralink RT3x5x/RT5350 based boards.
endef


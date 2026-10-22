# SPDX-License-Identifier: GPL-2.0-or-later
include $(TOPDIR)/rules.mk

PKG_NAME:=it87-it8613
PKG_VERSION:=1
PKG_RELEASE:=2
PKG_LICENSE:=GPL-2.0-or-later
PKG_LICENSE_FILES:=COPYING
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define KernelPackage/hwmon-it87-it8613
  SUBMENU:=Hardware Monitoring Support
  TITLE:=IT8613E fan speed monitoring (read-only)
  URL:=https://github.com/hermanho/openwrt-it87
  DEPENDS:=@TARGET_x86_64 +kmod-hwmon-core +kmod-hwmon-vid +kmod-i2c-core +kmod-thermal
  CONFLICTS:=kmod-hwmon-it87
  PROVIDES:=kmod-hwmon-it87
  FILES:=$(PKG_BUILD_DIR)/it87.ko
  AUTOLOAD:=$(call AutoProbe,it87)
  KCONFIG:=
endef

define KernelPackage/hwmon-it87-it8613/description
 Read-only IT8613E fan tachometer support backported to Linux 6.12.74.
 Does not expose IT8613 voltage, temperature or PWM control interfaces.
 Conflicts with the stock kmod-hwmon-it87 package because both own it87.ko.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" modules
endef

$(eval $(call KernelPackage,hwmon-it87-it8613))

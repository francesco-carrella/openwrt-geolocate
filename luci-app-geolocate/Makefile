include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-geolocate
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=Francesco Carrella <francesco.carrella@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-geolocate
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI interface for Geolocate
  DEPENDS:=+geolocate +luci-base
  PKGARCH:=all
endef

define Package/luci-app-geolocate/description
  Web interface for the geolocate package.
  Provides overview map, settings, and tracker integration management.
endef

define Build/Compile
endef

define Package/luci-app-geolocate/install
	$(CP) ./root/* $(1)/
	$(INSTALL_DIR) $(1)/www
	$(CP) ./htdocs/* $(1)/www/
endef

$(eval $(call BuildPackage,luci-app-geolocate))

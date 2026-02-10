include $(TOPDIR)/rules.mk

PKG_NAME:=geolocate
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Francesco Carrella <francesco.carrella@gmail.com>
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=../LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/geolocate
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Geolocation for OpenWrt (WiFi/Cell)
  DEPENDS:=+curl +jsonfilter +ubus +rpcd +iwinfo +luci-lib-jsonc +lua
  PKGARCH:=all
endef

define Package/geolocate/conffiles
/etc/config/geolocate
endef

define Package/geolocate/description
  Determines the router's location using WiFi access points and cell towers.
  Supports BeaconDB, Google Geolocation API, and Unwired Labs.
  Forwards position to Traccar, OwnTracks, Home Assistant, and others.
  No GPS hardware required.
endef

define Build/Compile
endef

define Package/geolocate/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/geolocate-daemon $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/usr/lib/geolocate
	$(INSTALL_BIN) ./files/usr/lib/geolocate/outputs.sh $(1)/usr/lib/geolocate/
	$(CP) ./files/usr/lib/geolocate/output $(1)/usr/lib/geolocate/

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/usr/libexec/rpcd/geolocate $(1)/usr/libexec/rpcd/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/geolocate $(1)/etc/config/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/geolocate $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-geolocate $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,geolocate))

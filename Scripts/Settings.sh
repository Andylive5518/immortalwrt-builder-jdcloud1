#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

set -e

LUCI_COLLECTIONS=$(find ./feeds/luci/collections/ -type f -name "Makefile" 2>/dev/null)
if [ -n "$LUCI_COLLECTIONS" ]; then
    sed -i "/attendedsysupgrade/d" $LUCI_COLLECTIONS
    sed -i "s/luci-theme-bootstrap/luci-theme-${WRT_THEME:-bootstrap}/g" $LUCI_COLLECTIONS
fi

LUCI_SYSTEM=$(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" 2>/dev/null)
if [ -n "$LUCI_SYSTEM" ]; then
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/${WRT_IP:-192.168.10.1}/g" $LUCI_SYSTEM
fi

LUCI_STATUS=$(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" 2>/dev/null)
if [ -n "$LUCI_STATUS" ]; then
    sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ ${WRT_MARK:-OWRT}-${WRT_DATE:-unknown}')/g" $LUCI_STATUS
fi

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80 211.uc"
if [ -f "$WIFI_SH" ]; then
    sed -i "s/BASE_SSID='.*'/BASE_SSID='${WRT_SSID:-OWRT}'/g" "$WIFI_SH"
    sed -i "s/BASE_WORD='.*'/BASE_WORD='${WRT_WORD:-12345678}'/g" "$WIFI_SH"
elif [ -f "$WIFI_UC" ]; then
    sed -i "s/ssid='.*'/ssid='${WRT_SSID:-OWRT}'/g" "$WIFI_UC"
    sed -i "s/key='.*'/key='${WRT_WORD:-12345678}'/g" "$WIFI_UC"
    sed -i "s/country='.*'/country='CN'/g" "$WIFI_UC"
    sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" "$WIFI_UC"
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_FILE" ]; then
    sed -i "s/192\.168\.[0-9]*\.[0-9]*/${WRT_IP:-192.168.10.1}/g" "$CFG_FILE"
    sed -i "s/hostname='.*'/hostname='${WRT_NAME:-OWRT}'/g" "$CFG_FILE"
fi

echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
if [ -n "$WRT_THEME" ]; then
    echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
    echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config
fi

if [ -n "$WRT_PACKAGE" ]; then
    printf "%s\n" "$WRT_PACKAGE" >> ./.config
fi

DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
    echo "CONFIG_FEED_nss_packages=n" >> ./.config
    echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
    if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
        echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
    else
        echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
    fi
    if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
        echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
        find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(60 18\|80 74\).dtsi/ipq\1-nowifi.dtsi/g' {} + 2>/dev/null || true
        echo "qualcommax set up nowifi successfully!"
    fi
    echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config
fi

echo "Settings applied successfully!"
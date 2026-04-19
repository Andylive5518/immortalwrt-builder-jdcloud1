#!/bin/bash
# SPDX-license-identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="${GITHUB_WORKSPACE:-.}/wrt/package/"

# Helper function to check if directory exists with pattern matching
dir_exists() {
    local pattern="$1"
    for dir in "$PKG_PATH"*; do
        [[ -d "$dir" && "$(basename "$dir")" == *"$pattern"* ]] && return 0
    done
    return 1
}

#预置HomeProxy数据
if dir_exists "homeproxy"; then
    echo " "

    HP_RULE="surge"
    HP_PATH="homeproxy/root/etc/homeproxy"

    rm -rf ./"$HP_PATH"/resources/*

    git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./"$HP_RULE"/
    cd ./"$HP_RULE"/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

    echo "$RES_VER" | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
    awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
    sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
    mv -f ./{china_*,gfw_list}.{ver,txt} ../"$HP_PATH"/resources/

    cd .. && rm -rf ./"$HP_RULE"/

    cd "$PKG_PATH" && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if dir_exists "luci-theme-argon"; then
    echo " "

    cd ./luci-theme-argon/

    sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon 2>/dev/null || true

    cd "$PKG_PATH" && echo "theme-argon has been fixed!"
fi

#修改argone主题字体和颜色
if dir_exists "luci-theme-argone"; then
    echo " "

    cd ./luci-theme-argone/

    sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argone-config/root/etc/config/argone 2>/dev/null || true

    cd "$PKG_PATH" && echo "theme-argone has been fixed!"
fi

#修改aurora菜单式样
if dir_exists "luci-app-aurora-config"; then
    echo " "

    cd ./luci-app-aurora-config/

    sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/ -type f -name "*aurora" 2>/dev/null) 2>/dev/null || true

    cd "$PKG_PATH" && echo "theme-aurora has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
    echo " "

    sed -i 's/START=.*/START=85/g' "$NSS_DRV"

    cd "$PKG_PATH" && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
    echo " "

    sed -i 's/START=.*/START=86/g' "$NSS_PBUF"

    cd "$PKG_PATH" && echo "qca-nss-pbuf has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile" 2>/dev/null)
if [ -n "$RUST_FILE" ] && [ -f "$RUST_FILE" ]; then
    echo " "

    for rust_makefile in $RUST_FILE; do
        sed -i 's/ci-llvm=true/ci-llvm=false/g' "$rust_makefile"
    done

    cd "$PKG_PATH" && echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
    echo " "

    sed -i '/ntfs-3g-utils /d' "$DM_FILE"

    cd "$PKG_PATH" && echo "diskman has been fixed!"
fi

#修复luci-app-netspeedtest相关问题
if dir_exists "luci-app-netspeedtest"; then
    echo " "

    cd ./luci-app-netspeedtest/

    sed -i '$a\exit 0' ./netspeedtest/files/99_netspeedtest.defaults 2>/dev/null || true
    sed -i 's/ca-certificates/ca-bundle/g' ./speedtest-cli/Makefile 2>/dev/null || true

    cd "$PKG_PATH" && echo "netspeedtest has been fixed!"
fi

# 修复cups编译失败 - 改用主源自 cups (small8 版本存在 PKG_MD5SUM + 已废弃的 configure 选项问题)
# 在 feeds install 之后，如果 ./package/cups 来自 small8，则删除并从主源重新安装
if [ -d "./package/cups" ]; then
    PKG_CUPS_ORIGIN=$(readlink ./package/cups 2>/dev/null || echo "")
    if echo "$PKG_CUPS_ORIGIN" | grep -q "small8\|jell"; then
        echo "  [修复] 检测到 small8 cups，准备替换为主源 cups"
        rm -rf ./package/cups
        ./scripts/feeds install cups luci-app-cupsd cups-utils libcups 2>/dev/null || true
        echo "  [完成] cups 已替换为主源版本"
    fi
fi

# 修复tcping编译失败 - 替换small8仓库的tcping Makefile
TCPING_PKG="./feeds/small8/tcping/Makefile"
if [ -f "$TCPING_PKG" ]; then
    echo "  [修复] 检测到 small8 tcping，准备替换为 passwall 版本"
    if curl -fsSL -o "$TCPING_PKG" "https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall-packages/refs/heads/main/tcping/Makefile"; then
        echo "  [完成] tcping 已替换为 passwall 版本"
    else
        echo "  [错误] tcping 下载失败"
    fi
fi

# 修复包版本号问题 (符合APK规范)
fix_pkg_version() {
    local pkg_name="$1"
    local pkg_file="$2"
    [ ! -f "$pkg_file" ] && return

    echo "  [修复] ${pkg_name} 版本号"

    grep -q 'PKG_SOURCE_VERSION:=' "$pkg_file" && sed -i '/PKG_SOURCE_VERSION:=/d' "$pkg_file"
    grep -q 'PKG_VERSION:=v' "$pkg_file" && sed -i 's/PKG_VERSION:=v/PKG_VERSION:=/g' "$pkg_file"
    grep -qE 'PKG_VERSION:=.*-[0-9]$' "$pkg_file" && sed -i 's/PKG_VERSION:=\(.*\)-\([0-9]\)/PKG_VERSION:=\1/g' "$pkg_file"
    grep -q 'PKG_RELEASE:=r[0-9]' "$pkg_file" && sed -i 's/PKG_RELEASE:=r\([0-9]\)/PKG_RELEASE:=\1/g' "$pkg_file"
    grep -qE '^PKG_RELEASE:=$' "$pkg_file" && sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' "$pkg_file"
}

fix_pkg_version "luci-app-store" "$(find . -path '*/luci-app-store/Makefile' -type f 2>/dev/null | head -1)"
fix_pkg_version "naiveproxy" "$(find . -path '*/naiveproxy/Makefile' -type f 2>/dev/null | head -1)"

echo "All fixes completed!"
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
    ARGON_CFG="$PKG_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"
    sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/; t; s/'/'/; t" "$ARGON_CFG" 2>/dev/null || true
    echo "theme-argon has been fixed!"
fi

#修改argone主题字体和颜色
if dir_exists "luci-theme-argone"; then
    echo " "
    ARGONE_CFG="$PKG_PATH/luci-theme-argone/luci-app-argone-config/root/etc/config/argone"
    sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/; t; s/'/'/; t" "$ARGONE_CFG" 2>/dev/null || true
    echo "theme-argone has been fixed!"
fi

#修改aurora菜单式样
if dir_exists "luci-app-aurora-config"; then
    echo " "
    AURORA_ROOT="$PKG_PATH/luci-app-aurora-config/root"
    [ -d "$AURORA_ROOT" ] && find "$AURORA_ROOT" -type f -name "*aurora" -exec sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" {} + 2>/dev/null || true
    echo "theme-aurora has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
    echo " "
    sed -i 's/START=.*/START=85/g' "$NSS_DRV" \
        || echo "  [错误] qca-nss-drv 启动顺序修改失败"
    echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
    echo " "
    sed -i 's/START=.*/START=86/g' "$NSS_PBUF" \
        || echo "  [错误] qca-nss-pbuf 启动顺序修改失败"
    echo "qca-nss-pbuf has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile" 2>/dev/null)
if [ -n "$RUST_FILE" ] && [ -f "$RUST_FILE" ]; then
    echo " "
    for rust_makefile in $RUST_FILE; do
        sed -i 's/ci-llvm=true/ci-llvm=false/g' "$rust_makefile" \
            || echo "  [错误] rust Makefile 修改失败: $rust_makefile"
    done
    echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
    echo " "
    sed -i '/ntfs-3g-utils /d' "$DM_FILE" \
        || echo "  [错误] diskman Makefile 修改失败"
    echo "diskman has been fixed!"
fi

#修复luci-app-netspeedtest相关问题
if dir_exists "luci-app-netspeedtest"; then
    echo " "
    NETSPEEDTEST_DEFAULTS="$PKG_PATH/luci-app-netspeedtest/netspeedtest/files/99_netspeedtest.defaults"
    NETSPEEDTEST_SPD_MK="$PKG_PATH/luci-app-netspeedtest/speedtest-cli/Makefile"
    [ -f "$NETSPEEDTEST_DEFAULTS" ] && sed -i '$a\exit 0' "$NETSPEEDTEST_DEFAULTS" 2>/dev/null || true
    [ -f "$NETSPEEDTEST_SPD_MK" ] && sed -i 's/ca-certificates/ca-bundle/g' "$NETSPEEDTEST_SPD_MK" 2>/dev/null || true
    echo "netspeedtest has been fixed!"
fi

# 修复cups编译失败 - 改用主源自 cups (small8 版本存在 PKG_MD5SUM + 已废弃的 configure 选项问题)
if [ -d "./package/cups" ]; then
    PKG_CUPS_ORIGIN=$(readlink ./package/cups 2>/dev/null || echo "")
    if echo "$PKG_CUPS_ORIGIN" | grep -q "small8\|jell"; then
        echo "  [修复] 检测到 small8 cups，准备替换为主源 cups"
        rm -rf ./package/cups
        ./scripts/feeds install cups luci-app-cupsd cups-utils libcups 2>/dev/null || echo "  [错误] cups feeds install 失败"
        echo "  [完成] cups 已替换为主源版本"
    fi
fi

# 修复 tcping 源码格式：服务器上是 .tar.gz，Makefile 里写的是 .tar.zst（hash 也对应 zst）
TCPING_HASH_OLD="36776bf64c41d0c2c2aeb79525499532831133f7b5e174fc51e9e2d7202d5776"
TCPING_HASH_NEW="c703481d1751adf051dd3391c4dccdadc6dfca7484e636222b392e1213312e02"
for TCPING_PKG in "./package/passwall-packages/tcping/Makefile" "./feeds/passwall_packages/tcping/Makefile"; do
    if [ -f "$TCPING_PKG" ]; then
        if grep -q "$TCPING_HASH_OLD" "$TCPING_PKG"; then
            echo "  [修复] tcping hash (zst -> gz)"
            sed -i "/^PKG_SOURCE_VERSION:=.*/a PKG_SOURCE:=tcping-\$(PKG_VERSION).tar.gz" "$TCPING_PKG" \
                || echo "  [错误] tcping PKG_SOURCE 插入失败"
            sed -i "s|$TCPING_HASH_OLD|$TCPING_HASH_NEW|g" "$TCPING_PKG" \
                || echo "  [错误] tcping hash 替换失败"
        else
            echo "  [跳过] tcping hash 无需修复（hash 已是最新的）"
        fi
    fi
done

# 修复 trojan-plus hash 不匹配问题（镜像源上文件存在但 hash 与 Makefile 不符）
TROJAN_HASH_OLD="0bc832390044668dc163e9fec3c6cf7ac3037dc30a706e94292d974446c43d97"
TROJAN_HASH_NEW="adad9914b2c1cffa0f8c2b10610f7119f77090ae5259872af0b82d2547500100"
for TROJAN_PKG in "./package/passwall-packages/trojan-plus/Makefile" "./feeds/passwall_packages/trojan-plus/Makefile"; do
    if [ -f "$TROJAN_PKG" ]; then
        if grep -q "$TROJAN_HASH_OLD" "$TROJAN_PKG"; then
            echo "  [修复] trojan-plus hash"
            sed -i "s|$TROJAN_HASH_OLD|$TROJAN_HASH_NEW|g" "$TROJAN_PKG" \
                || echo "  [错误] trojan-plus hash 替换失败"
        else
            echo "  [跳过] trojan-plus hash 无需修复（hash 已是最新的）"
        fi
    fi
done

# 修复 dockerman 包版本号问题
fix_pkg_version() {
    local pkg_name="$1"
    local pkg_file="$2"
    if [ ! -f "$pkg_file" ]; then
        echo "  [跳过] ${pkg_name} 未找到文件，跳过"
        return
    fi
    echo "  [修复] ${pkg_name} 版本号"
    local err=0
    grep -q 'PKG_SOURCE_VERSION:=' "$pkg_file" && sed -i '/PKG_SOURCE_VERSION:=/d' "$pkg_file" \
        || { echo "  [错误] ${pkg_name} PKG_SOURCE_VERSION 删除失败"; err=1; }
    grep -q 'PKG_VERSION:=v' "$pkg_file" && sed -i 's/PKG_VERSION:=v/PKG_VERSION:=/g' "$pkg_file" \
        || { echo "  [错误] ${pkg_name} PKG_VERSION 格式修正失败"; err=1; }
    grep -q 'PKG_RELEASE:=r[0-9]' "$pkg_file" && sed -i 's/PKG_RELEASE:=r\([0-9]\)/PKG_RELEASE:=\1/g' "$pkg_file" \
        || { echo "  [错误] ${pkg_name} PKG_RELEASE 格式修正失败"; err=1; }
    grep -qE '^PKG_RELEASE:=$' "$pkg_file" && sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' "$pkg_file" \
        || { echo "  [错误] ${pkg_name} PKG_RELEASE 默认值设置失败"; err=1; }
    [ "$err" -eq 0 ] && echo "  [完成] ${pkg_name} 版本号已修正"
}

fix_pkg_version "dockerman" "$(find . -path '*/luci-app-dockerman/Makefile' -type f 2>/dev/null | head -1)"
# 修复 luci-lib-docker 版本号: 去除 v 前缀 (apk 不接受 version:v0.3.4-r1 格式)
fix_pkg_version "luci-lib-docker" "$(find . -path '*/luci-lib-docker/Makefile' -type f 2>/dev/null | head -1)"

# luci-app-store 修复: 版本格式动态修正
LUCI_STORE_FILE=$(find . -path '*/luci-app-store/Makefile' -type f 2>/dev/null | head -1)
if [ -n "$LUCI_STORE_FILE" ] && [ -f "$LUCI_STORE_FILE" ]; then
    echo "  [修复] luci-app-store 版本号"
    CUR_VER=$(grep '^PKG_VERSION:=' "$LUCI_STORE_FILE" | sed 's/^PKG_VERSION:=[ ]*//')
    CUR_REL=$(grep '^PKG_RELEASE:=' "$LUCI_STORE_FILE" | sed 's/^PKG_RELEASE:=[ ]*//')
    BASE_VER="${CUR_VER%-1}"
    sed -i "s/^PKG_VERSION:=$CUR_VER/PKG_VERSION:=$BASE_VER/g" "$LUCI_STORE_FILE" \
        || { echo "  [错误] luci-app-store PKG_VERSION 修正失败"; }
    sed -i "s/^PKG_RELEASE:=$CUR_REL/PKG_RELEASE:=1/g" "$LUCI_STORE_FILE" \
        || { echo "  [错误] luci-app-store PKG_RELEASE 修正失败"; }
fi

# 修复 opkg Makefile 降级到上一版本（服务器暂无新版本包）
OPKG_MAKEFILE="./package/system/opkg/Makefile"
if [ -f "$OPKG_MAKEFILE" ]; then
    if grep -q "PKG_SOURCE_DATE:=2025-11-05" "$OPKG_MAKEFILE"; then
        echo "  [修复] opkg 版本降级"
        sed -i 's|PKG_SOURCE_DATE:=2025-11-05|PKG_SOURCE_DATE:=2024-10-16|' "$OPKG_MAKEFILE" \
            || { echo "  [错误] opkg PKG_SOURCE_DATE 修改失败"; }
        sed -i 's|PKG_SOURCE_VERSION:=80503d94e356476250adaf1f669ee955ec26de76|PKG_SOURCE_VERSION:=38eccbb1fd694d4798ac1baf88f9ba83d1eac616|' "$OPKG_MAKEFILE" \
            || { echo "  [错误] opkg PKG_SOURCE_VERSION 修改失败"; }
        sed -i 's|PKG_MIRROR_HASH:=41fb2c79ce6014e28f7dd0cd8c65efe803986278f2587d1d4681883d8847d87c|PKG_MIRROR_HASH:=de58ff1c99c14789f9ba8946623c8c1e58d022e7e2a659d6f97c6fde54f2c4f4|' "$OPKG_MAKEFILE" \
            || { echo "  [错误] opkg PKG_MIRROR_HASH 修改失败"; }
    else
        echo "  [跳过] opkg 无需降级（版本已是最新的或已修复）"
    fi
fi

# naiveproxy 修复: 版本格式及源码地址动态修正
# naiveproxy 特殊模式: PKG_VERSION 末尾 -1 实为版本标识而非 release
#   例如 147.0.7727.49-1 → base=147.0.7727.49, pkg_release=1
#   APK 拼接结果: 147.0.7727.49-1 (valid)
#   GitHub tag 需要完整版本号: v147.0.7727.49-1
# NAIVE_FILE=$(find . -path '*/naiveproxy/Makefile' -type f 2>/dev/null | head -1)
# if [ -n "$NAIVE_FILE" ] && [ -f "$NAIVE_FILE" ]; then
#     echo "  [修复] naiveproxy 版本号及源码地址"
#     CUR_VER=$(grep '^PKG_VERSION:=' "$NAIVE_FILE" | sed 's/^PKG_VERSION:=[ ]*//')
#     CUR_REL=$(grep '^PKG_RELEASE:=' "$NAIVE_FILE" | sed 's/^PKG_RELEASE:=[ ]*//')
#     BASE_VER="${CUR_VER%-1}"
#     sed -i "s/^PKG_VERSION:=$CUR_VER/PKG_VERSION:=$BASE_VER/g" "$NAIVE_FILE"
#     sed -i "s/^PKG_RELEASE:=$CUR_REL/PKG_RELEASE:=1/g" "$NAIVE_FILE"
#     sed -i "s|v\$(PKG_VERSION)|v${BASE_VER}-1|g" "$NAIVE_FILE"
# fi

echo "All fixes completed!"

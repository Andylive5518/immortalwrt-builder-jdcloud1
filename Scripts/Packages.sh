#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# Enhanced with feeds mechanism and batch processing (inspired by wrt_release)

set -e

# ============================================================================
# 第一部分：冲突包批量删除 (借鉴外部作者的 remove_unwanted_packages)
# ============================================================================

REMOVE_CONFLICT_PACKAGES() {
    echo ">>> 开始批量删除冲突包..."
    
    # LuCI 应用冲突包
    local LUCI_CONFLICTS=(
        "luci-app-passwall"
        "luci-app-ddns-go"
        "luci-app-rclone"
        "luci-app-ssr-plus"
        "luci-app-vssr"
        "luci-app-daed"
        "luci-app-dae"
        "luci-app-alist"
        "luci-app-homeproxy"
        "luci-app-haproxy-tcp"
        "luci-app-openclash"
        "luci-app-mihomo"
        "luci-app-appfilter"
        "luci-app-msd_lite"
        "luci-app-unblockneteasemusic"
    )
    
    # 网络包冲突
    local NET_CONFLICTS=(
        "haproxy" "xray-core" "xray-plugin" "dns2socks" "alist" "hysteria"
        "mosdns" "adguardhome" "ddns-go" "naiveproxy" "shadowsocks-rust"
        "sing-box" "v2ray-core" "v2ray-geodata" "v2ray-plugin" "tuic-client"
        "chinadns-ng" "ipt2socks" "tcping" "trojan-plus" "simple-obfs" "shadowsocksr-libev"
        "dae" "daed" "mihomo" "geoview" "tailscale" "open-app-filter" "msd_lite"
    )
    
    # 批量删除 LuCI 应用
    for pkg in "${LUCI_CONFLICTS[@]}"; do
        if [ -d "./feeds/luci/applications/$pkg" ]; then
            rm -rf "./feeds/luci/applications/$pkg"
            echo "  [删除] feeds/luci/applications/$pkg"
        fi
        if [ -d "./feeds/luci/themes/$pkg" ]; then
            rm -rf "./feeds/luci/themes/$pkg"
            echo "  [删除] feeds/luci/themes/$pkg"
        fi
    done
    
    # 批量删除网络包
    for pkg in "${NET_CONFLICTS[@]}"; do
        if [ -d "./feeds/packages/net/$pkg" ]; then
            rm -rf "./feeds/packages/net/$pkg"
            echo "  [删除] feeds/packages/net/$pkg"
        fi
    done
    
    # 批量删除工具包
    if [ -d "./feeds/packages/utils/cups" ]; then
        rm -rf "./feeds/packages/utils/cups"
        echo "  [删除] feeds/packages/utils/cups"
    fi
    
    # 批量删除 jell/small8 feed 中的冲突包
    local SMALL8_CONFLICTS=(
        "ppp" "firewall" "dae" "daed" "daed-next" "libnftnl" "nftables" 
        "dnsmasq" "luci-app-alist" "alist" "opkg" "smartdns" "luci-app-smartdns" "easytier"
    )
    
    for pkg in "${SMALL8_CONFLICTS[@]}"; do
        if [ -d "./feeds/small8/$pkg" ]; then
            rm -rf "./feeds/small8/$pkg"
            echo "  [删除] feeds/small8/$pkg"
        fi
    done
    
    # 删除 iStore
    if [ -d "./package/istore" ]; then
        rm -rf "./package/istore"
        echo "  [删除] package/istore"
    fi
    
    echo ">>> 冲突包批量删除完成"
}

# ============================================================================
# 第二部分：Feeds 机制支持 (借鉴外部作者的 feeds.sh)
# ============================================================================

ADD_THIRD_PARTY_FEEDS() {
    echo ">>> 添加第三方 feeds..."
    
    # 检查 feeds.conf 是否存在
    if [ ! -f "feeds.conf.default" ]; then
        echo "  [警告] feeds.conf.default 不存在，跳过 feed 添加"
        return
    fi
    
    # 添加 small8 (jell) feed - 包含 40+ 插件
    if ! grep -q "small8\|jell" feeds.conf.default; then
        echo "src-git small8 https://github.com/kenzok8/jell" >> feeds.conf.default
        echo "  [添加] small8 feed (jell)"
    fi
    
    # 添加 PassWall feed
    if ! grep -q "openwrt-passwall\|passwall" feeds.conf.default; then
        echo "src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall;main" >> feeds.conf.default
        echo "  [添加] passwall feed"
    fi
    
    # 更新 feeds
    ./scripts/feeds update -a
    echo "  [完成] feeds 更新"
}

# ============================================================================
# 第三部分：安装第三方插件 (保留原有逻辑 + 增强)
# ============================================================================

UPDATE_() {
    local PKG_NAME="$1"
    local PKG_REPO="$2"
    local PKG_BRANCH="$3"
    local PKG_SPECIAL="$4"
    local PKG_LIST=("$PKG_NAME" "${5:-}")
    local REPO_NAME="${PKG_REPO#*/}"
    
    echo " "
    echo ">>> 安装插件: $PKG_NAME"
    
    for NAME in "${PKG_LIST[@]}"; do
        [ -z "$NAME" ] && continue
        local FOUND_DIRS
        FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
        
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                [ -n "$DIR" ] && rm -rf "$DIR" && echo "  [删除] $DIR"
            done <<< "$FOUND_DIRS"
        fi
    done
    
    # 捕获 git 输出以便调试
    local GIT_OUTPUT
    if ! GIT_OUTPUT=$(git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/${PKG_REPO}.git" 2>&1); then
        echo "  [错误] 克隆失败: https://github.com/${PKG_REPO}.git"
        echo "  [详情] $GIT_OUTPUT"
        return 1
    fi
    echo "  [完成] 从 $PKG_REPO 安装"
    done
    
    if ! git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/${PKG_REPO}.git"; then
        echo "  [错误] 克隆失败: https://github.com/${PKG_REPO}"
        return 1
    fi
    
    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        find "./$REPO_NAME"/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \; 2>/dev/null || true
        rm -rf "./$REPO_NAME"
        echo "  [完成] 从 monorepo 提取 $PKG_NAME"
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        mv -f "$REPO_NAME" "$PKG_NAME"
        echo "  [完成] 重命名为 $PKG_NAME"
    else
        echo "  [完成] 直接克隆"
    fi
}

# ============================================================================
# 第四部分：Feeds 安装函数 (借鉴外部作者的 install_small8)
# ============================================================================

INSTALL_FROM_FEEDS() {
    echo ">>> 从 feeds 安装第三方包..."
    
    # 从 small8/jell 安装代理插件集合
    ./scripts/feeds install -p small8 -f \
        xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
        naiveproxy shadowsocks-rust sing-box v2ray-core v2ray-geodata geoview v2ray-plugin \
        tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs \
        v2dat mosdns luci-app-mosdns adguardhome luci-app-adguardhome ddns-go \
        luci-app-ddns-go taskd luci-lib-xterm luci-lib-taskd luci-app-store quickstart \
        luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest netdata luci-app-netdata \
        lucky luci-app-lucky luci-app-openclash luci-app-homeproxy luci-app-amlogic nikki luci-app-nikki \
        oaf open-app-filter luci-app-oaf \
        msd_lite luci-app-msd_lite cups luci-app-cupsd p910nd luci-app-p910nd
    echo "  [完成] 从 small8 安装插件"
}

# ============================================================================
# 第五部分：版本自动更新 (借鉴外部作者的 update_package)
# ============================================================================

UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-false}
    
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")
    
    if [ -z "$PKG_FILES" ]; then
        echo "  [跳过] $PKG_NAME not found!"
        return 0
    fi
    
    echo -e "\n>>> $PKG_NAME 版本更新..."
    
    for PKG_FILE in $PKG_FILES; do
        local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
        local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")
        
        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
        local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
        local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
        local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")
        
        local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")
        
        local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
        local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
        local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)
        
        echo "  旧版本: $OLD_VER $OLD_HASH"
        echo "  新版本: $NEW_VER $NEW_HASH"
        
        if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "  [更新] $PKG_FILE 版本已更新!"
        else
            echo "  [跳过] $PKG_NAME 已是最新版本"
        fi
    done
}

# ============================================================================
# 主流程：按顺序执行
# ============================================================================

main() {
    echo "=========================================="
    echo "第三方插件安装脚本 (增强版)"
    echo "=========================================="
    
    cd $GITHUB_WORKSPACE/wrt/ 2>/dev/null || cd ./wrt/ 2>/dev/null || cd . || exit 1
    
    # Step 1: 批量删除冲突包
    REMOVE_CONFLICT_PACKAGES
    
    # Step 2: 添加第三方 feeds
    ADD_THIRD_PARTY_FEEDS
    
    # Step 3: 从 feeds 安装插件
    INSTALL_FROM_FEEDS
    
    # Step 4: 安装自定义插件 (直接 clone)
    echo ""
    echo ">>> 安装自定义插件..."
    
    # 主题
    UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
    UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
    UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
    
    # 代理
    UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
    UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
    UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
    UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
    
    # 网络工具
    UPDATE_PACKAGE "smartdns" "pymumu/luci-app-smartdns" "master" "pkg"
    UPDATE_PACKAGE "adguardhome" "AUKipsey/luci-app-adguardhome" "main" "pkg"
    UPDATE_PACKAGE "pbr" "AsaraKitty/luci-app-pbr" "master"
    UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf"
    UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
    UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
    UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
    UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
    UPDATE_PACKAGE "gecoosac" "laipeng668/luci-app-gecoosac" "main"
    UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
    UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox speedtest"
    UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
    UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
    UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
    UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
    UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
    UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"
    
    # Step 5: 自动更新版本 (可选，针对 sing-box)
    # UPDATE_VERSION "sing-box"
    
    echo ""
    echo "=========================================="
    echo "插件安装完成!"
    echo "=========================================="
}

# 如果直接运行此脚本，执行主流程
# 如果被 source 导入，则导出函数供外部调用
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
else
    export -f REMOVE_CONFLICT_PACKAGES
    export -f ADD_THIRD_PARTY_FEEDS
    export -f INSTALL_FROM_FEEDS
    export -f UPDATE_PACKAGE
    export -f UPDATE_VERSION
fi
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
    
    # 批量删除工具包 (cups 已改用主源，small8 版本存在编译问题)
    # if [ -d "./feeds/packages/utils/cups" ]; then
    #     rm -rf "./feeds/packages/utils/cups"
    #     echo "  [删除] feeds/packages/utils/cups"
    # fi
    
    # 批量删除 jell/small8 feed 中的冲突包
    local SMALL8_CONFLICTS=(
        "ppp" "firewall" "dae" "daed" "daed-next" "libnftnl" "nftables" 
        "dnsmasq" "luci-app-alist" "alist" "opkg" "smartdns" "luci-app-smartdns" "easytier"
        "cups" "luci-app-cupsd" "p910nd" "luci-app-p910nd"
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
    
    # # 添加 PassWall feed
    # if ! grep -q "openwrt-passwall\|passwall" feeds.conf.default; then
    #     echo "src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall;main" >> feeds.conf.default
    #     echo "  [添加] passwall feed"
    # fi
    
    # 更新 feeds
    ./scripts/feeds update -a
    echo "  [完成] feeds 更新"
}

# ============================================================================
# 第三部分：安装第三方插件 (保留原有逻辑 + 增强)
# ============================================================================

UPDATE_PACKAGE() {
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
        set +e
        FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
        set -e
        
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                [ -n "$DIR" ] && rm -rf "$DIR" && echo "  [删除] $DIR"
            done <<< "$FOUND_DIRS"
        fi
    done
    
    echo "  [信息] 克隆: https://github.com/${PKG_REPO}.git"
    set +e
    git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/${PKG_REPO}.git" 2>&1
    CLONE_RESULT=$?
    set -e
    
    if [ $CLONE_RESULT -ne 0 ]; then
        echo "  [错误] 克隆失败 (exit code: $CLONE_RESULT)"
        return 1
    fi
    echo "  [完成] 从 $PKG_REPO 安装"
    
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
        lucky luci-app-lucky luci-app-openclash luci-app-homeproxy nikki luci-app-nikki \
        oaf open-app-filter luci-app-oaf msd_lite luci-app-msd_lite \
        luci-theme-argon luci-app-argon-config luci-theme-argone luci-app-argone-config luci-theme-aurora \
        luci-app-passwall luci-app-passwall2 luci-app-smartdns \
        luci-app-diskman luci-app-easytier luci-app-openlist2 \
        luci-app-partexp luci-app-qbittorrent luci-app-vnt
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
        
        local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/./g; s/^\.|\.$//g')
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
# 第六部分：修复第三方包问题 (luci-app-store 版本号格式修复)
# ============================================================================

FIX_PACKAGE_ISSUES() {
    echo ">>> 修复第三方包问题..."
    
    # 修复 luci-app-store 版本号格式
    # 错误版本: 0.1.32-1-r66 (包含 r66 导致版本号无效)
    # 修复为: PKG_VERSION:=0.1.32, PKG_RELEASE:=1
    local LUCI_APP_STORE_MAKEFILE=$(find ./ ../feeds/ -path "*/luci-app-store/Makefile" 2>/dev/null | head -1)
    
    if [ -n "$LUCI_APP_STORE_MAKEFILE" ] && [ -f "$LUCI_APP_STORE_MAKEFILE" ]; then
        echo "  [修复] luci-app-store 版本号格式"
        
        # 检查是否需要修复 (版本号包含 r 或超出标准格式)
        local CURRENT_VERSION=$(grep -Po "PKG_VERSION:=\K.*" "$LUCI_APP_STORE_MAKEFILE" || echo "")
        
        if [[ "$CURRENT_VERSION" =~ r ]]; then
            local VER_NUM=$(echo "$CURRENT_VERSION" | sed -E 's/-[0-9]+-r[0-9]+//g')
            local RELEASE_NUM=$(echo "$CURRENT_VERSION" | grep -oP '(?<=-)[0-9]+(?=-r)' || echo "1")

            sed -i "s|PKG_VERSION:=.*|PKG_VERSION:=$VER_NUM|" "$LUCI_APP_STORE_MAKEFILE"
            sed -i "s|PKG_RELEASE:=.*|PKG_RELEASE:=$RELEASE_NUM|" "$LUCI_APP_STORE_MAKEFILE" 2>/dev/null || \
                sed -i "/PKG_VERSION/a PKG_RELEASE:=$RELEASE_NUM" "$LUCI_APP_STORE_MAKEFILE"

            echo "    版本: $CURRENT_VERSION -> $VER_NUM (release: $RELEASE_NUM)"
        fi

        local CURRENT_RELEASE=$(grep -Po "PKG_RELEASE:=\K.*" "$LUCI_APP_STORE_MAKEFILE" || echo "")
        if [[ "$CURRENT_RELEASE" =~ ^r ]]; then
            local RELEASE_NUM=$(echo "$CURRENT_RELEASE" | sed 's/^r//')
            sed -i "s|PKG_RELEASE:=.*|PKG_RELEASE:=$RELEASE_NUM|" "$LUCI_APP_STORE_MAKEFILE"
            echo "    PKG_RELEASE: $CURRENT_RELEASE -> $RELEASE_NUM"
        fi
    fi
    
    echo "  [完成] 包问题修复"
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
    
    # Step 4: 修复第三方包问题 (版本号格式等)
    FIX_PACKAGE_ISSUES
    
    # Step 5: 安装 small8 没有的自定义插件
    echo ""
    echo ">>> 安装自定义插件 (small8 没有的)..."
    # 主题
    # UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
    UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
    # 其他
    UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox speedtest"
    UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
    
    # Step 6: 自动更新版本 (可选，针对 sing-box)
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
    export -f FIX_PACKAGE_ISSUES
fi
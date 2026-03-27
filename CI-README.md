# OpenWRT-CI 编译项目说明

> 基于 GitHub Actions 的 OpenWRT 自动化云编译系统

---

## 目录

- [项目概述](#项目概述)
- [源码来源](#源码来源)
- [支持平台](#支持平台)
- [自定义插件](#自定义插件)
- [核心脚本](#核心脚本)
- [配置说明](#配置说明)
- [CI/CD 工作流](#cicd-工作流)
- [固件特性](#固件特性)

---

## 项目概述

这是一个 **GitHub Actions 云编译 OpenWRT 固件** 的自动化 CI 项目，由 VIKINGYFY 维护。

- **自动编译**: 每天凌晨 4:00 自动触发
- **编译时间**: 固件信息显示编译开始时间，便于核对上游源码提交时间
- **发布方式**: GitHub Release

---

## 源码来源

### OpenWRT 固件源码

| 类型 | 仓库地址 | 分支 |
|------|----------|------|
| 官方版 | https://github.com/immortalwrt/immortalwrt.git | - |
| 高通版 | https://github.com/VIKINGYFY/immortalwrt.git | `owrt` / `main` |

### U-Boot 引导程序

| 平台 | 仓库地址 |
|------|----------|
| 高通 (IPQ60XX EMMC) | https://github.com/chenxin527/uboot-ipq60xx-emmc-build |
| 高通 (IPQ60XX NAND) | https://github.com/chenxin527/uboot-ipq60xx-nand-build |
| 高通 (IPQ60XX NOR) | https://github.com/chenxin527/uboot-ipq60xx-nor-build |
| 联发科 | https://drive.wrt.moe/uboot/mediatek |

---

## 支持平台

### 1. MEDIATEK (联发科)

- **架构**: filogic
- **设备数量**: 50+
- **代表设备**:
  - ASUS TUF-AX4200 / AX6000
  - Xiaomi Mi Router AX3000T / Redmi Router AX6000
  - TP-Link TL-XDR4288 / TL-XDR6086 / TL-XDR6088
  - Cudy TR3000
  - NetCore N60 / N60 Pro
  - GL.iNet GL-MT3000 / GL-MT6000

### 2. ROCKCHIP (瑞芯微)

- **架构**: armv8
- **设备数量**: 20+
- **代表设备**:
  - NanoPi R4S / R5S / R6S
  - OrangePi 5 / 5 Plus
  - FriendlyARM NanoPi 系列

### 3. X86_64

- **类型**: 虚拟机 / 物理机
- **特点**: 
  - 全设备支持
  - 集成 GPU 驱动
  - 支持 MT7925 WiFi

### 4. Qualcommax IPQ807X (高通)

- **设备**:
  - Linksys MX4200v1/v2 / MX4300 / MX5300 / MX8500
  - Xiaomi AX3600 / AX9000
  - Redmi AX6
  - QNAP 301W

### 5. Qualcommax IPQ60XX (高通)

- **变体**: WIFI-YES / WIFI-NO
- **用途**: 支持外接 WiFi 或使用内置方案

### 6. Qualcommax IPQ50XX (高通)

- **特点**: 新一代入门级平台

---

## 自定义插件

### 主题 (Themes)

| 插件 | 仓库 | 说明 |
|------|------|------|
| argon | sbwml/luci-theme-argon | 现代渐变主题 |
| aurora | eamonxg/luci-theme-aurora | 菜单式主题 (默认) |
| kucat | sirpdboy/luci-theme-kucat | 猫主题 |

### 代理/科学上网 (Proxy)

| 插件 | 仓库 | 说明 |
|------|------|------|
| homeproxy | VIKINGYFY/homeproxy | Surge 规则代理 (默认) |
| openclash | vernesong/OpenClash | Clash 核心代理 |
| passwall | Openwrt-Passwall/openwrt-passwall | 多种协议支持 |
| passwall2 | Openwrt-Passwall/openwrt-passwall2 | Passwall 经典版 |
| momo | nikkinikki-org/OpenWrt-momo | Momo 代理 |
| nikki | nikkinikki-org/OpenWrt-nikki | Nikki 代理 |

### 网络工具 (Network)

| 插件 | 仓库 | 说明 |
|------|------|------|
| luci-app-tailscale | asvow/luci-app-tailscale | Tailscale 内网穿透 |
| luci-app-easytier | EasyTier/luci-app-easytier | EasyTier VPN |
| luci-app-ddns-go | sirpdboy/luci-app-ddns-go | DDNS 客户端 |
| luci-app-gecoosac | laipeng668/luci-app-gecoosac | 访问控制 |
| luci-app-netspeedtest | sirpdboy/netspeedtest | 网速测试 |

### 下载/存储 (Download/Storage)

| 插件 | 仓库 | 说明 |
|------|------|------|
| luci-app-qbittorrent | sbwml/luci-app-qbittorrent | BT 下载 |
| luci-app-diskman | lisaac/luci-app-diskman | 磁盘管理 |
| luci-app-quickfile | sbwml/luci-app-quickfile | 快速文件分享 |

### 其他插件 (Others)

| 插件 | 仓库 | 说明 |
|------|------|------|
| luci-app-mosdns | sbwml/luci-app-mosdns | DNS 优化 |
| luci-app-openlist2 | sbwml/luci-app-openlist2 | 列表管理 |
| luci-app-partexp | sirpdboy/luci-app-partexp | 分区助手 |
| luci-app-vnt | lmq8267/luci-app-vnt | VNT 穿透 |
| luci-app-fancontrol | rockjake/luci-app-fancontrol | 风扇控制 |
| luci-app-qmodem | FUjr/QModem | QMI 调制解调器 |

### 预置规则

- **HomeProxy**: 预置 Loyalsoldier Surge 规则 (GFWList/ChinaIP)

---

## 核心脚本

### Scripts/Packages.sh

**功能**: 克隆和管理第三方插件

```bash
# 主要操作:
1. 删除可能冲突的旧版本插件
2. 从 GitHub 克隆最新插件
3. 处理特殊插件类型 (pkg/name)
4. 自动检测并更新插件版本 (如 sing-box)
```

### Scripts/Settings.sh

**功能**: 编译前系统定制

```bash
# 主要操作:
1. 移除 luci-app-attendedsysupgrade
2. 修改默认主题
3. 修改默认 IP 地址 (192.168.10.1)
4. 修改默认主机名
5. 修改默认 WIFI 名称/密码
6. 添加编译日期标识
7. 注入配置文件 (luci, theme, packages)
8. 高通平台 NSS 固件版本调整
9. 高通无 WIFI 配置调整 Q6 DSP 大小
```

### Scripts/Handles.sh

**功能**: 编译后插件修复和优化

```bash
# 主要操作:
1. 预置 HomeProxy 规则文件
2. Argon 主题字体和颜色修复
3. Aurora 主题菜单样式修复
4. NSS 驱动启动顺序修复 (qca-nss-drv, qca-nss-pbuf)
5. Tailscale 配置文件冲突修复
6. Rust 编译失败修复
7. DiskMan 编译失败修复
8. NetSpeedTest 相关问题修复
```

---

## 配置说明

### 目录结构

```
OpenWRT-CI/
├── .github/workflows/   # CI 配置文件
│   ├── WRT-CORE.yml     # 编译核心流程
│   ├── OWRT-ALL.yml    # 官方/联发科/瑞芯微/x86 编译
│   ├── QCA-ALL.yml     # 高通平台编译
│   ├── Auto-Clean.yml  # 自动清理缓存
│   ├── Cache-Clean.yml # 手动清理缓存
│   └── WRT-TEST.yml    # 测试编译
├── Scripts/             # 自定义脚本
│   ├── Settings.sh     # 系统定制
│   ├── Packages.sh     # 插件管理
│   └── Handles.sh      # 插件修复
├── Config/              # 平台配置
│   ├── GENERAL.txt     # 通用配置
│   ├── MEDIATEK.txt    # 联发科设备
│   ├── ROCKCHIP.txt    # 瑞芯微设备
│   ├── X86.txt         # x86_64 设备
│   ├── IPQ807X-WIFI-*.txt  # 高通 IPQ807X
│   ├── IPQ60XX-WIFI-*.txt  # 高通 IPQ60XX
│   └── IPQ50XX-WIFI-*.txt  # 高通 IPQ50XX
└── README.md           # 项目说明
```

### GENERAL.txt 通用配置

```bash
# 科学插件
CONFIG_PACKAGE_luci-app-homeproxy=y

# 额外插件
CONFIG_PACKAGE_luci-app-autoreboot=y      # 自动重启
CONFIG_PACKAGE_luci-app-samba4=y          # 文件共享
CONFIG_PACKAGE_luci-app-tailscale=y       # 内网穿透
CONFIG_PACKAGE_luci-app-upnp=y            # UPnP
CONFIG_PACKAGE_luci-app-wolplus=y         # 网络唤醒

# 删除插件
CONFIG_PACKAGE_luci-app-attendedsysupgrade=n
CONFIG_PACKAGE_luci-app-wol=n

# 编译参数
CONFIG_CCACHE=y          # 加速编译
CONFIG_DEVEL=y           # 开发工具
CONFIG_TARGET_MULTI_PROFILE=y

# 内核模块
# USB: usb3, usb-audio, storage, asix, rtl8152, qmi-wwan, etc.
# Network: bonding, dsa, wireguard, mptcp, nft-*
# Filesystem: btrfs, fuse

# 常用工具
curl, htop, iperf3, openssh, coremark, mmc-utils
```

---

## CI/CD 工作流

### 编译流程图

```
┌─────────────────────────────────────────────────────────────┐
│                      Auto-Clean / Manual                    │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      WRT-CORE.yml                           │
├─────────────────────────────────────────────────────────────┤
│  1. 环境初始化                                               │
│     - apt update / full-upgrade                             │
│     - 安装依赖 (dos2unix, python3-netifaces, libfuse-dev)   │
│     - 运行 immortalwrt 构建环境初始化脚本                    │
│                                                             │
│  2. 克隆源码                                                │
│     - git clone --depth=1 --single-branch                   │
│     - 移除国内下载源镜像                                     │
│                                                             │
│  3. 更新 Feeds                                              │
│     - ./scripts/feeds update -a                             │
│     - ./scripts/feeds install -a                            │
│                                                             │
│  4. 安装自定义插件 (Packages.sh)                            │
│     - 克隆 20+ 第三方插件                                   │
│     - 自动更新版本                                           │
│                                                             │
│  5. 插件修复 (Handles.sh)                                   │
│     - 预置规则                                              │
│     - 修复编译问题                                          │
│                                                             │
│  6. 应用配置 (Settings.sh)                                  │
│     - 注入 Config/*.txt                                     │
│     - 修改 IP/主机名/WIFI                                   │
│     - make defconfig + make clean                           │
│                                                             │
│  7. 下载依赖                                                │
│     - make download -j$(nproc)                              │
│                                                             │
│  8. 编译固件                                                │
│     - make -j$(nproc) 或 make -j1 V=s                       │
│                                                             │
│  9. 打包发布                                                │
│     - 生成 GitHub Release                                   │
│     - 上传固件文件                                          │
└─────────────────────────────────────────────────────────────┘
```

### 缓存策略

- **缓存内容**: `.ccache`, `staging_dir/host*`, `staging_dir/tool*`
- **缓存 key**: `{CONFIG}-{INFO}-{HASH}`
- **自动清理**: 检测到缓存未命中时自动清理旧缓存

---

## 固件特性

### 默认配置

| 项目 | 默认值 |
|------|--------|
| 主题 | aurora |
| 语言 | 中文 (zh_Hans) |
| IP 地址 | 192.168.10.1 |
| 主机名 | OWRT |
| WIFI 名称 | OWRT |
| WIFI 密码 | 12345678 |
| 登录密码 | 无 (默认) |

### 编译标记

固件会在 LuCI 版本信息中显示编译日期:

```
LuCI 版本 / 26.03.25-04.00.01
```

### 硬件加速

- **高通平台**: 全系支持开源 NSS 加速
- **联发科平台**: 原生支持
- **瑞芯微平台**: GPU 驱动 (Panfrost, Rockchip DRM)

### 自动任务

固件每天凌晨 4:00 自动编译，编译完成后:
1. 生成 GitHub Release
2. 上传固件文件
3. 记录内核版本和插件列表

---

## 常见问题

### Q: 如何手动触发编译?

A: 在 GitHub 页面进入 Actions → 选择工作流 → 点击 "Run workflow"

### Q: 如何仅测试配置不编译?

A: 手动触发时勾选 "仅输出配置文件"

### Q: 如何添加自定义插件?

A: 手动触发时在 "手动调整插件包" 输入框中添加，格式:
```
CONFIG_PACKAGE_luci-app-xxx=y
```

### Q: 如何清理编译缓存?

A: 运行 Cache-Clean.yml 工作流

---

## 许可证

MIT License - Copyright (C) 2026 VIKINGYFY
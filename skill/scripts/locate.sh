#!/usr/bin/env bash
# =============================================================================
# locate.sh — 定制点快速定位工具(shuhe-ostl-deploy v2)
#
# 用法:
#   locate.sh 网口|eth|hdmi|usb|摄像头|camera|pll4|lvgl|boot|介质
#   或: locate.sh --all
#
# 输出双板型(自定义板 -test / 官方板 dk)的修改点位置。
# 详细说明见 docs/CUSTOM_MAP.md
# =============================================================================
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_CYN=$'\e[36m'; C_OFF=$'\e[0m'

MAP="$SKILL_DIR/docs/CUSTOM_MAP.md"
[ -f "$MAP" ] || { echo "[FAIL] 缺少 docs/CUSTOM_MAP.md" >&2; exit 1; }

KEY="${1:-}"
[ -n "$KEY" ] && [ "$KEY" != "--all" ] || { cat "$MAP"; exit 0; }

case "$KEY" in
    网口|eth|network|net)
        SECTION="## 1. 网口"
        ;;
    hdmi|HDMI|显示|display)
        SECTION="## 2. HDMI"
        ;;
    usb|USB)
        SECTION="## 3. USB"
        ;;
    摄像头|camera|ov5640)
        SECTION="## 4. 摄像头"
        ;;
    pll4|PLL4|时钟|clock)
        SECTION="## 5. PLL4"
        ;;
    模块|module|modules)
        SECTION="## 6. 内核模块装载"
        ;;
    boot|/boot|启动)
        SECTION="## 7. 镜像 /boot"
        ;;
    介质|media|emmc|sdcard)
        SECTION="## 8. 启动介质"
        ;;
    *)
        echo "[FAIL] 未知关键字: $KEY" >&2
        echo "可用: 网口|eth | hdmi | usb | 摄像头|camera | pll4 | 模块 | boot | 介质|media" >&2
        exit 1
        ;;
esac

awk "/^$SECTION/{f=1;next} /^## /{if(f)exit} f" "$MAP"
echo
echo "完整说明: $MAP"
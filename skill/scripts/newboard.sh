#!/usr/bin/env bash
# =============================================================================
# newboard.sh — 新自定义板一键生成器(shuhe-ostl-deploy v2, 步骤 F)
#
# 用法:
#   newboard.sh --name stm32mp13-disco-xxx --dt stm32mp135f-xxx-test \
#               [--media emmc|sdcard] [--image shuhe-xxx-image-core] \
#               [--repo <meta-st-stm32mp 目录>] [--linux <内核 fork 目录>] \
#               [--commit] [--push]
#
# 自动完成(落到本地 git 仓库, --commit/--push 控制提交与推送):
#   1. 渲染机器模板 -> conf/machine/<name>.conf
#   2. 生成镜像 recipe  recipes-st/images/<image>.bb(含 bootfs 修复)
#   3. 生成内核 dts 骨架 arch/arm/boot/dts/st/<dt>.dts + <dt>.dtsi
#      (含外设修改点注释: 网口/HDMI/USB/摄像头)
#   4. 提示下一步: 改外设 -> envsetup 选机器 -> bitbake <image>
#      注: 本工程 dtb 以 make 显式目标编译(KERNEL_DEVICETREE),
#          新 dts 无需注册到内核 Makefile(stm32mp135f-test 即如此)。
# =============================================================================
set -euo pipefail

C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_CYN=$'\e[36m'; C_OFF=$'\e[0m'
info() { echo -e "${C_CYN}[INFO]${C_OFF} $*"; }
ok()   { echo -e "${C_GRN}[ OK ]${C_OFF} $*"; }
die()  { echo -e "${C_RED}[FAIL]${C_OFF} $*" >&2; exit 1; }

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPL=""

NAME=""; DT=""; MEDIA="emmc"; IMAGE=""; REPO=""; LINUX=""; DO_COMMIT=0; DO_PUSH=0

usage() {
    sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --name)  NAME="$2"; shift 2 ;;
        --dt)    DT="$2"; shift 2 ;;
        --media) MEDIA="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        --repo)  REPO="$2"; shift 2 ;;
        --linux) LINUX="$2"; shift 2 ;;
        --commit) DO_COMMIT=1; shift ;;
        --push)   DO_PUSH=1; DO_COMMIT=1; shift ;;
        -h|--help) usage ;;
        *) die "未知参数: $1" ;;
    esac
done

[ -n "$NAME" ] || die "缺少 --name (机器名, 如 stm32mp13-disco-xxx)"
[ -n "$DT" ]   || die "缺少 --dt (设备树名, 如 stm32mp135f-xxx-test)"
case "$NAME" in
    stm32mp13-disco-*) ;;
    *) die "机器名必须以 stm32mp13-disco- 开头" ;;
esac
case "$DT" in
    stm32mp135f-*) ;;
    *) die "设备树名必须以 stm32mp135f- 开头" ;;
esac
case "$MEDIA" in
    emmc|sdcard) ;;
    *) die "未知介质: $MEDIA (可用: emmc|sdcard)" ;;
esac
[ -n "$IMAGE" ] || IMAGE="shuhe-${NAME#stm32mp13-disco-}-image-core"

# ------------------------------------------------------------------ 定位仓库
if [ -z "$REPO" ]; then
    for d in "$PWD" "$PWD/layers/meta-st/meta-st-stm32mp" "$PWD/../meta-st-stm32mp" "$HOME/shuhe/layers/meta-st/meta-st-stm32mp"; do
        [ -d "$d/conf/machine" ] && REPO="$d" && break
    done
fi
[ -n "$REPO" ] && [ -f "$REPO/conf/machine/stm32mp13-disco-test.conf" ] \
    || die "未找到 meta-st-stm32mp 仓库(含 stm32mp13-disco-test.conf), 请用 --repo 指定"
REPO="$(cd "$REPO" && pwd)"

if [ -z "$LINUX" ]; then
    for d in "$PWD/workspace/sources/linux-stm32mp" "$PWD/sources/linux-stm32mp" "$HOME/shuhe/layers/linux-stm32mp"; do
        [ -d "$d/arch/arm/boot/dts/st" ] && LINUX="$d" && break
    done
fi
if [ -n "$LINUX" ] && [ -f "$LINUX/arch/arm/boot/dts/st/stm32mp135f-test.dts" ]; then
    LINUX="$(cd "$LINUX" && pwd)"
else
    warn "未找到内核 fork 目录(含 stm32mp135f-test.dts), 跳过 dts 骨架生成; 请用 --linux 指定"
    LINUX=""
fi

BOOTDEVICE_UPPER=$(echo "$MEDIA" | tr 'a-z' 'A-Z')
if [ "$MEDIA" = "emmc" ]; then
    UBOOT_DEFCONFIG="stm32mp13_test_defconfig"
else
    UBOOT_DEFCONFIG="stm32mp13_defconfig"
fi

# ------------------------------------------------------------------ 1. 机器 conf
info "1/4 生成机器 conf: $REPO/conf/machine/$NAME.conf"
if [ -f "$REPO/conf/machine/$NAME.conf" ]; then
    die "机器 conf 已存在: $NAME.conf"
fi
# 模板位置: meta-st-stm32mp/conf/machine/templates/shuhe-board.conf.tmpl
TMPL="$REPO/conf/machine/templates/shuhe-board.conf.tmpl"
[ -f "$TMPL" ] || die "缺少机器模板: $TMPL (请先 repo sync 到最新 meta-st-stm32mp)"
sed -e "s|__MACHINE_NAME__|$NAME|g" \
    -e "s|__DT_NAME__|$DT|g" \
    -e "s|__BOOTDEVICE__|$MEDIA|g" \
    -e "s|__BOOTDEVICE_UPPER__|$BOOTDEVICE_UPPER|g" \
    -e "s|__UBOOT_DEFCONFIG__|$UBOOT_DEFCONFIG|g" \
    -e "s|__IMAGE_NAME__|$IMAGE|g" \
    "$TMPL" > "$REPO/conf/machine/$NAME.conf"
ok "机器 conf 生成: conf/machine/$NAME.conf"

# ------------------------------------------------------------------ 2. 镜像 recipe
info "2/4 生成镜像 recipe: $REPO/recipes-st/images/$IMAGE.bb"
if [ -f "$REPO/recipes-st/images/$IMAGE.bb" ]; then
    die "镜像 recipe 已存在: $IMAGE.bb"
fi
cat > "$REPO/recipes-st/images/$IMAGE.bb" <<EOF
SUMMARY = "OpenSTLinux core image for $NAME board with $DT devicetree."
LICENSE = "Proprietary"

include recipes-st/images/st-image.inc

inherit core-image

# --- START: 禁用不需要的 IMAGE_FEATURES ---
FEATURE_PACKAGES_weston = ""
FEATURE_PACKAGES_x11 = ""
FEATURE_PACKAGES_x11-base = ""
FEATURE_PACKAGES_x11-sato = ""
FEATURE_PACKAGES_tools-debug = ""
FEATURE_PACKAGES_eclipse-debug = ""
FEATURE_PACKAGES_tools-profile = ""
FEATURE_PACKAGES_tools-testapps = ""
FEATURE_PACKAGES_tools-sdk = ""
FEATURE_PACKAGES_nfs-server = ""
FEATURE_PACKAGES_nfs-client = ""
FEATURE_PACKAGES_hwcodecs = ""

# 使用精简包组作为基础
CORE_IMAGE_BASE_INSTALL = '\\
    packagegroup-shuhe-minimal \\
    '

# 安装机器必备的启动包(内核镜像/设备树/extlinux), 确保 /boot 有内容可启动
IMAGE_INSTALL:append = " \${MACHINE_ESSENTIAL_EXTRA_RDEPENDS} st-initrd"

IMAGE_LINGUAS = "en-us"

MACHINE_EXTRA_RRECOMMENDS:remove = "kernel-modules"

# 禁用 systemd 网络相关服务
SYSTEMD_DISABLED_SERVICES += "systemd-networkd.service systemd-resolved.service systemd-timesyncd.service"
SYSTEMD_DISABLED_SERVICES += "systemd-firstboot.service systemd-coredump.socket systemd-journald-audit.socket serial-getty@ttySTM0.service"
EOF
ok "镜像 recipe 生成: recipes-st/images/$IMAGE.bb"

# ------------------------------------------------------------------ 3. 内核 dts 骨架
if [ -n "$LINUX" ]; then
    info "3/4 生成内核 dts 骨架: $LINUX/arch/arm/boot/dts/st/$DT.dts + $DT.dtsi"
    if [ -f "$LINUX/arch/arm/boot/dts/st/$DT.dts" ] || [ -f "$LINUX/arch/arm/boot/dts/st/$DT.dtsi" ]; then
        die "dts 已存在: $DT.dts / $DT.dtsi"
    fi
    cat > "$LINUX/arch/arm/boot/dts/st/$DT.dts" <<EOF
// SPDX-License-Identifier: (GPL-2.0+ OR BSD-3-Clause)
/*
 * $NAME 自定义板设备树(由 newboard.sh 生成骨架)
 * 修改外设请参考 docs/CUSTOM_MAP.md:
 *   网口   -> 本文件 &ethernet1/&ethernet2 节点(phy-handle/phy-mode)
 *   HDMI   -> sii9022 桥节点 + &ltdc 链路
 *   USB    -> &usbotg_hs / &usbh_ehci 节点
 *   摄像头  -> ov5640 节点(status 改 okay)
 */

/dts-v1/;

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/leds/common.h>
#include <dt-bindings/pwm/pwm.h>
#include <dt-bindings/rtc/rtc-stm32.h>
#include "$DT.dtsi"
#include "stm32mp13xf.dtsi"

/ {
	model = "STMicroelectronics STM32MP135F $NAME Board";
	compatible = "st,$DT", "st,stm32mp135";

	aliases {
		serial0 = &uart4;
	};
};
EOF
    cat > "$LINUX/arch/arm/boot/dts/st/$DT.dtsi" <<EOF
// SPDX-License-Identifier: (GPL-2.0+ OR BSD-3-Clause)
/*
 * $NAME 自定义板 dtsi(由 newboard.sh 生成骨架)
 * 参考: stm32mp135-test.dtsi(内存/保留区/外设使能)
 */

#include "stm32mp135.dtsi"

&etzpc {
	ltdc: display-controller@5a001000 {
		compatible = "st,stm32-ltdc";
		reg = <0x5a001000 0x400>;
		interrupts = <GIC_SPI 88 IRQ_TYPE_LEVEL_HIGH>,
			     <GIC_SPI 89 IRQ_TYPE_LEVEL_HIGH>;
		clocks = <&rcc LTDC_PX>;
		clock-names = "lcd";
		resets = <&scmi_reset RST_SCMI_LTDC>;
		access-controllers = <&etzpc 3>;
		status = "disabled";
	};
};
EOF
    ok "内核 dts 骨架生成(无需改内核 Makefile, dtb 按 KERNEL_DEVICETREE 显式编译)"
else
    info "3/4 跳过 dts 骨架(未提供内核 fork 目录)"
fi

# ------------------------------------------------------------------ 4. 提交/推送
if [ "$DO_COMMIT" = "1" ]; then
    info "4/4 提交..."
    git -C "$REPO" add "conf/machine/$NAME.conf" "recipes-st/images/$IMAGE.bb" || true
    git -C "$REPO" commit -m "add new board $NAME: machine + $IMAGE + $DT skeleton" || true
    if [ -n "$LINUX" ]; then
        git -C "$LINUX" add "arch/arm/boot/dts/st/$DT.dts" "arch/arm/boot/dts/st/$DT.dtsi" || true
        git -C "$LINUX" commit -m "add $DT devicetree skeleton for $NAME board" || true
    fi
    if [ "$DO_PUSH" = "1" ]; then
        BR=$(git -C "$REPO" branch --show-current)
        git -C "$REPO" push origin "$BR" || warn "push meta-st-stm32mp 失败(请手动处理)"
        if [ -n "$LINUX" ]; then
            BR2=$(git -C "$LINUX" branch --show-current)
            git -C "$LINUX" push origin "$BR2" || warn "push linux 失败(请手动处理)"
        fi
    fi
else
    info "4/4 未提交(--commit 提交, --push 推送)"
fi

cat <<EOF

${C_GRN}==============================================================${C_OFF}
${C_GRN}  新板 $NAME 生成完成!${C_OFF}
   机器:  conf/machine/$NAME.conf
   镜像:  recipes-st/images/$IMAGE.bb
   设备树: arch/arm/boot/dts/st/$DT.dts (+ .dtsi)

${C_CYN}下一步:${C_OFF}
 1) 按 docs/CUSTOM_MAP.md 修改外设(网口/HDMI/USB/摄像头)
 2) source layers/meta-st/scripts/envsetup.sh -> 选择 DISTRO + $NAME
 3) bitbake $IMAGE -> 专属构建版本
${C_GRN}==============================================================${C_OFF}
EOF
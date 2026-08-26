#!/usr/bin/env bash
# =============================================================================
# configure.sh — 板型/介质/外设选择并生成 local.conf(shuhe-ostl-deploy v2)
#
# 用法:
#   configure.sh --board dk|test [--media emmc|sdcard|both] [--camera] [--build-dir <dir>]
#   configure.sh --list                 # 列出支持的板型
#   configure.sh(无参数)                # 交互式选择
#
# 作用: 在 build 目录的 conf/local.conf 追加(幂等)对应板型的定制配置,
#       之后执行 bitbake <镜像> 即可。
# =============================================================================
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$SKILL_DIR/templates"

C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_CYN=$'\e[36m'; C_OFF=$'\e[0m'
info() { echo -e "${C_CYN}[INFO]${C_OFF} $*"; }
ok()   { echo -e "${C_GRN}[ OK ]${C_OFF} $*"; }
die()  { echo -e "${C_RED}[FAIL]${C_OFF} $*" >&2; exit 1; }

BOARD=""
MEDIA=""
CAMERA="0"
BUILD_DIR=""

usage() {
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --board)     BOARD="$2"; shift 2 ;;
        --media)     MEDIA="$2"; shift 2 ;;
        --camera)    CAMERA="1"; shift ;;
        --build-dir) BUILD_DIR="$2"; shift 2 ;;
        --list)
            echo "支持的板型:"
            echo "  test  -> stm32mp13-disco-test  / shuhe-test-image-core (256MB, eMMC, -test dts, 默认)"
            echo "  dk    -> stm32mp13-disco-dk     / shuhe-image-core      (512MB, SD卡, 官方 dts)"
            exit 0 ;;
        -h|--help) usage ;;
        *) die "未知参数: $1" ;;
    esac
done

# ------------------------------------------------------------------ 交互选择
if [ -z "$BOARD" ]; then
    echo "请选择板型:"
    echo "  1) 自定义板(stm32mp13-disco-test, 默认)"
    echo "  2) 官方板 (stm32mp13-disco-dk)"
    read -rp "选择 [1/2, 默认 1]: " b
    case "$b" in
        2) BOARD="dk" ;;
        *) BOARD="test" ;;
    esac
fi
case "$BOARD" in
    test|dk) ;;
    *) die "未知板型: $BOARD (可用: test|dk)" ;;
esac

if [ -z "$MEDIA" ]; then
    if [ "$BOARD" = "dk" ]; then
        MEDIA="sdcard"
    else
        echo "请选择启动介质(自定义板):"
        echo "  1) eMMC(默认)"
        echo "  2) SD 卡"
        echo "  3) 双产物(eMMC + SD)"
        read -rp "选择 [1/2/3, 默认 1]: " m
        case "$m" in
            2) MEDIA="sdcard" ;;
            3) MEDIA="both" ;;
            *) MEDIA="emmc" ;;
        esac
    fi
fi
case "$MEDIA" in
    emmc|sdcard|both) ;;
    *) die "未知介质: $MEDIA (可用: emmc|sdcard|both)" ;;
esac

# ------------------------------------------------------------------ 定位 build 目录
if [ -z "$BUILD_DIR" ]; then
    for d in . "$PWD/../.." "$HOME/shuhe-test" "$HOME/shuhe"; do
        if [ -f "$d/conf/local.conf" ] && grep -q 'openstlinux' "$d/conf/local.conf" 2>/dev/null; then
            BUILD_DIR="$d"; break
        fi
    done
fi
[ -n "$BUILD_DIR" ] && [ -f "$BUILD_DIR/conf/local.conf" ] || die "未找到 build 目录(带 conf/local.conf), 请用 --build-dir 指定"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

# ------------------------------------------------------------------ 生成配置片段
gen_conf() {
    local board="$1" media="$2" camera="$3"

    if [ "$board" = "dk" ]; then
        cat <<'EOF'

# =========================================================================
# shuhe-ostl-deploy v2: 官方板配置 (configure.sh --board dk)
# =========================================================================
MACHINE = "stm32mp13-disco-dk"
DISTRO = "openstlinux-weston"
ACCEPT_EULA_stm32mp13-disco-dk = "1"
ERROR_QA:remove = "version-going-backwards"
STM32MP_SOURCE_SELECTION:pn-linux-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-optee-os-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-tf-a-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-u-boot-stm32mp = "github"
IMAGE_INSTALL:append = " dropbear dpkg lrzsz kernel-modules fbset lvgl lvgl-demo-fb edid-decode"
WKS_IMAGE_FSTYPES += "wic"
WKS_FILE = "sdcard-stm32mp135f-dk-optee-example.wks.in"
EOF
    else
        cat <<'EOF'

# =========================================================================
# shuhe-ostl-deploy v2: 自定义板配置 (configure.sh --board test)
# =========================================================================
MACHINE = "stm32mp13-disco-test"
DISTRO = "openstlinux-weston"
ACCEPT_EULA_stm32mp13-disco-test = "1"
ERROR_QA:remove = "version-going-backwards"
STM32MP_SOURCE_SELECTION:pn-linux-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-optee-os-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-tf-a-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-u-boot-stm32mp = "github"
IMAGE_INSTALL:append = " dropbear dpkg lrzsz kernel-modules fbset lvgl lvgl-demo-fb edid-decode"
TF_A_CONFIG[optee-emmc] = "\
    ${STM32MP_DT_FILES_EMMC},\
    ${TF_A_CONFIG_OPTS_optee} ${TF_A_CONFIG_OPTS_EXTDT} ${TF_A_CONFIG_OPTS_features} ${TF_A_CONFIG_OPTS_fwupdate} STM32MP_EMMC=1 STM32MP_EMMC_BOOT=1,\
    ${TF_A_CONFIG_BASENAME_BIN},\
    ${TF_A_CONFIG_MAKE_TARGET},\
    ${TF_A_CONFIG_DEPLOY_FTYPE} ${TF_A_CONFIG_DEPLOY_EXTRA},\
    ${EXTDT_SUFFIX_EMMC}"
EOF
        if [ "$media" = "sdcard" ] || [ "$media" = "both" ]; then
            cat <<'EOF'
# --- SD 卡产物(configure.sh --media sdcard|both) ---
STM32MP_DT_FILES_SDCARD = "stm32mp135f-test"
TF_A_CONFIG[optee-sdcard] = "\
    ${STM32MP_DT_FILES_SDCARD},\
    ${TF_A_CONFIG_OPTS_optee} ${TF_A_CONFIG_OPTS_EXTDT} ${TF_A_CONFIG_OPTS_features} ${TF_A_CONFIG_OPTS_fwupdate} STM32MP_SDMMC=1,\
    ${TF_A_CONFIG_BASENAME_BIN},\
    ${TF_A_CONFIG_MAKE_TARGET},\
    ${TF_A_CONFIG_DEPLOY_FTYPE} ${TF_A_CONFIG_DEPLOY_EXTRA},\
    ${EXTDT_SUFFIX_SDCARD}"
WKS_IMAGE_FSTYPES += "wic"
WKS_FILE = "sdcard-stm32mp135f-test-optee-example.wks.in"
EOF
        fi
    fi

    if [ "$camera" = "1" ]; then
        cat <<'EOF'
# --- 摄像头(configure.sh --camera): ov5640 默认 disabled, 启用需改 dts status + 装 libcamera ---
# IMAGE_INSTALL:append = " camera-tx libcamera libcamera-apps"
EOF
    fi
}

CONF="$BUILD_DIR/conf/local.conf"
if grep -q "shuhe-ostl-deploy v2" "$CONF" 2>/dev/null; then
    info "local.conf 已包含 v2 定制, 如需切换板型请先手动删除旧定制块"
fi

{
    echo ""
    gen_conf "$BOARD" "$MEDIA" "$CAMERA"
} >> "$CONF"

# ------------------------------------------------------------------ 校验
for key in 'ERROR_QA:remove = "version-going-backwards"' 'STM32MP_SOURCE_SELECTION:pn-u-boot-stm32mp = "github"'; do
    grep -qF "$key" "$CONF" || die "local.conf 缺少关键配置: $key"
done

ok "配置已写入 $CONF"
echo
info "下一步: source layers/meta-st/scripts/envsetup.sh 后执行:"
case "$BOARD" in
    dk)  echo "  bitbake shuhe-image-core" ;;
    test) echo "  bitbake shuhe-test-image-core" ;;
esac
echo
info "烧录指引:"
case "$BOARD:$MEDIA" in
    dk:*)  echo "  dd 烧录 SD 卡: sudo dd if=tmp-glibc/deploy/images/stm32mp13-disco-dk/shuhe-image-core-*.rootfs.wic of=/dev/sdX bs=4M conv=fsync" ;;
    test:emmc) echo "  STM32CubeProgrammer + FlashLayout_emmc_stm32mp135f-test-optee.tsv" ;;
    test:sdcard) echo "  dd 烧录 SD 卡: sudo dd if=tmp-glibc/deploy/images/stm32mp13-disco-test/shuhe-test-image-core-*.rootfs.wic of=/dev/sdX bs=4M conv=fsync" ;;
    test:both) echo "  eMMC: STM32CubeProgrammer + FlashLayout tsv; SD: dd rootfs.wic" ;;
esac
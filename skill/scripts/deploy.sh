#!/usr/bin/env bash
# =============================================================================
# shuhe-ostl-deploy.sh — OpenSTLinux shuhe 定制项目一键部署脚本
#
# 用途: 在新电脑上从零部署 STM32MP135F-DK (MACHINE=stm32mp13-disco-test)
#       并构建 shuhe-test-image-core 镜像(含全部 shuhe 定制)。
#
# 用法: bash deploy.sh [--dir <项目目录>] [--dl-dir <下载缓存目录>]
#
# 依赖: Ubuntu 20.04/22.04/24.04, 可访问 github.com, 磁盘 ≥100GB
# =============================================================================
set -euo pipefail

# ------------------------------------------------------------------ 配置
PROJECT_DIR="${1:-$HOME/shuhe-test}"           # 项目根目录(含 .repo 与 layers)
DL_DIR_OPT=""                                   # 可选共享下载缓存
MANIFEST_URL="https://github.com/stm32mp9527/oe-manifest.git"
MANIFEST_BRANCH="shuhe-dev"
DISTRO="openstlinux-weston"
MACHINE="stm32mp13-disco-test"
IMAGE="shuhe-test-image-core"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # skill 根目录
LOCAL_CONF_TEMPLATE="$SKILL_DIR/templates/local.conf.shuhe"
BUILD_DIR="build-openstlinuxweston-$MACHINE"

# ------------------------------------------------------------------ 颜色
C_RED=$'\e[31m'; C_GRN=$'\e[32m'; C_YEL=$'\e[33m'; C_CYN=$'\e[36m'; C_OFF=$'\e[0m'
info()  { echo -e "${C_CYN}[INFO]${C_OFF} $*"; }
ok()    { echo -e "${C_GRN}[ OK ]${C_OFF} $*"; }
warn()  { echo -e "${C_YEL}[WARN]${C_OFF} $*"; }
die()   { echo -e "${C_RED}[FAIL]${C_OFF} $*" >&2; exit 1; }

# 解析参数
while [ $# -gt 0 ]; do
    case "$1" in
        --dir)    PROJECT_DIR="$2"; shift 2 ;;
        --dl-dir) DL_DIR_OPT="$2";   shift 2 ;;
        *) die "未知参数: $1" ;;
    esac
done

# =============================================================================
# 步骤 1: 环境检查
# =========================================================================
check_env() {
    info "=== 1/7 环境检查 ==="
    [ -n "$(uname -m | grep -i x86_64)" ] || warn "非 x86_64 架构, 请确认 host 支持"
    command -v lsb_release >/dev/null 2>&1 && UBUNTU_VER=$(lsb_release -rs) || UBUNTU_VER=$(grep -oP '(?<=VERSION_ID=")[0-9.]+' /etc/os-release)
    echo "  OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    case "$UBUNTU_VER" in
        20.04|22.04|24.04) ok "Ubuntu $UBUNTU_VER 支持" ;;
        *) warn "建议 Ubuntu 20.04/22.04/24.04 (当前 $UBUNTU_VER)" ;;
    esac

    AVAIL_GB=$(df -Pk "$HOME" | awk 'NR==2{printf "%.0f", $4/1024/1024}')
    echo "  ${HOME} 可用磁盘: ${AVAIL_GB} GB"
    [ "$AVAIL_GB" -ge 100 ] || die "磁盘空间不足(需 ≥100GB)"

    echo "  测试 github 连通性..."
    curl -sI --max-time 15 https://github.com >/dev/null 2>&1 \
        || die "无法访问 github.com, 请检查网络/代理"
    ok "github 可达"

    for t in git python3 curl repo; do
        command -v "$t" >/dev/null 2>&1 || MISSING_TOOLS="$MISSING_TOOLS $t"
    done
    if [ -n "${MISSING_TOOLS:-}" ]; then
        warn "缺失工具:${MISSING_TOOLS}"
        info "安装中(sudo apt install ...)"
        sudo apt update
        sudo apt install -y git python3 curl repo || die "工具安装失败, 请手动安装:${MISSING_TOOLS}"
    fi
    ok "基础工具就绪"
}

# =============================================================================
# 步骤 2: 安装 bitbake HOSTTOOLS 依赖
# =========================================================================
install_deps() {
    info "=== 2/7 安装构建依赖 ==="
    sudo apt install -y chrpath diffstat lz4 2>/dev/null \
        || { sudo apt update; sudo apt install -y chrpath diffstat lz4; } \
        || die "构建依赖安装失败"
    ok "chrpath/diffstat/lz4 就绪"

    if ! locale -a 2>/dev/null | grep -qi "en_US.UTF-8"; then
        warn "缺少 en_US.UTF-8 locale, 正在生成"
        sudo locale-gen en_US.UTF-8 || true
    fi
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    ok "环境依赖就绪"
}

# =============================================================================
# 步骤 3: repo 初始化 + 同步(带重试)
# =========================================================================
retry() {  # retry <次数> <命令...>
    local n=${1}; shift
    local i
    for ((i=1; i<=n; i++)); do
        if "$@"; then return 0; fi
        warn "命令失败(第 $i/$n 次): $*"
        [ "$i" -lt "$n" ] && sleep $((i*10))
    done
    return 1
}

repo_init() {
    info "=== 3/7 初始化 repo ==="
    mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"
    if [ -d .repo ]; then
        ok ".repo 已存在, 跳过 repo init"
    else
        retry 5 repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" -m default.xml \
            || die "repo init 失败(网络?请稍后重试)"
        ok "repo init 完成"
    fi
    retry 5 repo sync -j8 || die "repo sync 失败"
    ok "repo sync 完成"
    [ -f layers/meta-st/scripts/envsetup.sh ] || die "layers 不完整, 请重新 repo sync"
}

# =============================================================================
# 步骤 4: envsetup 非交互创建 build 目录
# =========================================================================
setup_build_dir() {
    info "=== 4/7 创建 build 目录 ==="
    cd "$PROJECT_DIR"
    if [ -d "$BUILD_DIR/conf" ]; then
        ok "build 目录已存在: $BUILD_DIR"
        return
    fi
    # envsetup.sh 支持通过环境变量非交互选择 DISTRO/MACHINE
    DISTRO="$DISTRO" MACHINE="$MACHINE" \
        bash -c "source layers/meta-st/scripts/envsetup.sh" \
        || die "envsetup.sh 失败, 请手动执行: DISTRO=$DISTRO MACHINE=$MACHINE source layers/meta-st/scripts/envsetup.sh"
    [ -f "$BUILD_DIR/conf/local.conf" ] || die "未生成 build 目录 $BUILD_DIR"
    ok "build 目录就绪: $BUILD_DIR"
}

# =============================================================================
# 步骤 5: 写入 local.conf 定制(幂等)
# =========================================================================
write_local_conf() {
    info "=== 5/7 写入 local.conf 定制 ==="
    [ -f "$LOCAL_CONF_TEMPLATE" ] || die "缺少模板: $LOCAL_CONF_TEMPLATE"
    local conf="$PROJECT_DIR/$BUILD_DIR/conf/local.conf"
    if grep -q "shuhe-ostl-deploy" "$conf" 2>/dev/null; then
        ok "local.conf 已包含 shuhe 定制, 跳过"
    else
        {
            echo ""
            cat "$LOCAL_CONF_TEMPLATE"
        } >> "$conf"
        [ -n "$DL_DIR_OPT" ] && echo "DL_DIR = \"$DL_DIR_OPT\"" >> "$conf"
        ok "local.conf 定制已写入"
    fi
    # 校验关键配置齐全
    for key in 'ERROR_QA:remove = "version-going-backwards"' \
               'STM32MP_SOURCE_SELECTION:pn-u-boot-stm32mp = "github"' \
               'IMAGE_INSTALL:append' 'TF_A_CONFIG\[optee-emmc\]' ; do
        grep -qE "$key" "$conf" || die "local.conf 缺少关键配置: $key"
    done
    ok "关键配置校验通过"
}

# =============================================================================
# 步骤 6: 构建
# =========================================================================
build() {
    info "=== 6/7 构建 $IMAGE (首次约 1~2 小时, 请耐心) ==="
    cd "$PROJECT_DIR/$BUILD_DIR"
    if ! command -v bitbake >/dev/null 2>&1; then
        # 环境未加载时手动初始化
        source "$PROJECT_DIR/layers/openembedded-core/oe-init-build-env" . >/dev/null 2>&1 \
            || die "bitbake 环境初始化失败"
    fi
    # HOSTTOOLS 检查
    for t in chrpath diffstat lz4c; do
        command -v "$t" >/dev/null 2>&1 || { sudo apt install -y chrpath diffstat lz4 >/dev/null 2>&1 || true; break; }
    done
    bitbake "$IMAGE" || die "bitbake $IMAGE 失败, 请查看日志后重试"
    ok "构建完成"
}

# =============================================================================
# 步骤 7: 产物验证
# =========================================================================
verify() {
    info "=== 7/7 产物验证 ==="
    local IMG="$PROJECT_DIR/$BUILD_DIR/tmp-glibc/deploy/images/$MACHINE"
    [ -d "$IMG" ] || die "产物目录不存在: $IMG"

    local BOOTFS; BOOTFS=$(ls -t "$IMG"/shuhe-test-image-core-*.splitted-bootfs-*.ext4 2>/dev/null | head -1)
    [ -n "$BOOTFS" ] || die "未找到 splitted-bootfs 产物"
    echo "  bootfs: $(basename "$BOOTFS")"
    # bootfs 关键内容检查
    local missing=""
    if command -v debugfs >/dev/null 2>&1; then
        for f in uImage stm32mp135f-test.dtb extlinux st-image-resize-initrd; do
            debugfs -R "ls -p /" "$BOOTFS" 2>/dev/null | grep -q "/$f/" || missing="$missing $f"
        done
    else
        warn "debugfs 未安装(e2fsprogs), 跳过 bootfs 内容校验"
    fi
    [ -z "$missing" ] || die "bootfs 缺少启动文件:$missing(烧录会卡 U-Boot, 请重新构建并检查 shuhe-test-image-core.bb 的 IMAGE_INSTALL:append)"
    ok "bootfs 启动文件齐全(uImage/dtb/extlinux/initrd)"

    local TSRV="$IMG/flashlayout_shuhe-test-image-core/optee/FlashLayout_emmc_stm32mp135f-test-optee.tsv"
    [ -f "$TSRV" ] || die "缺少 flashlayout tsv: $TSRV"
    ok "flashlayout tsv 存在"

    local KVER; KVER=$(ls "$IMG"/kernel/config-* 2>/dev/null | head -1 | xargs basename | sed 's/config-//')
    echo "  内核版本: $KVER"
    ok "产物验证通过"

    cat <<EOF

${C_GRN}==============================================================${C_OFF}
${C_GRN}  部署完成!${C_OFF}
  产物目录: $IMG
  烧录: STM32CubeProgrammer 加载
       $TSRV
  板卡启动后验证: eth0/eth1、HDMI(edid-decode)、USB、lvgl-demo-fb
${C_GRN}==============================================================${C_OFF}
EOF
}

# =============================================================================
main() {
    echo -e "${C_CYN}==============================================${C_OFF}"
    echo -e "${C_CYN}  OpenSTLinux shuhe 一键部署${C_OFF}"
    echo -e "${C_CYN}  MACHINE=$MACHINE  IMAGE=$IMAGE${C_OFF}"
    echo -e "${C_CYN}==============================================${C_OFF}"
    check_env
    install_deps
    repo_init
    setup_build_dir
    write_local_conf
    build
    verify
    ok "全部完成"
}
main
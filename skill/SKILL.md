---
name: shuhe-ostl-deploy
description: |
  一键在新电脑上部署/复刻 OpenSTLinux shuhe 定制项目(STM32MP13-DK)。
  自动完成:系统依赖检查安装、repo 初始化同步、envsetup 非交互配置、
  local.conf 定制写入、bitbake shuhe-test-image-core 构建、产物验证与烧录指引。
  包含 github 源码源、TF_A_CONFIG[optee-emmc]、IMAGE_INSTALL 定制、
  ERROR_QA 跳过版本回退检查等客户环境必需配置。
  用于:"一键部署"、"复刻到新电脑"、"新环境构建 OpenSTLinux"、
  "shuhe 部署"、"客户机器搭建"、"bitbake 全流程"等请求。
  (shuhe)
---

# /shuhe-ostl-deploy — OpenSTLinux shuhe 项目一键部署

在新电脑上从零部署 **OpenSTLinux shuhe 定制项目**(STM32MP135F-DK 测试板,
MACHINE=`stm32mp13-disco-test`,镜像 `shuhe-test-image-core`)。

所有定制(meta-st 两层 fork、内核/固件 fork、manifest)都已推送到
`github.com/stm32mp9527`,部署全程从 GitHub 拉取,无需手工复制任何文件。

## 快速开始(客户无 opencode 时)

```bash
bash ~/.config/opencode/skills/shuhe-ostl-deploy/scripts/deploy.sh
```

## 前置条件(自动检查,不满足会提示)

- 操作系统:Ubuntu 20.04 / 22.04 / 24.04(x86_64)
- 网络:可访问 `github.com`(首次需下载约 13GB 源码)
- 磁盘:建议 ≥100GB 可用空间
- 工具:git、python3、curl、repo(缺失自动安装)
- locale:`en_US.UTF-8`(构建需要)

## 部署流程

### 1. 环境检查

```bash
# 逐项检查:OS 版本 / 磁盘空间 / 网络 / 工具 / locale
# 磁盘不足或工具缺失时先处理,不要跳过
df -h .
lsb_release -a 2>/dev/null || cat /etc/os-release
curl -sI --max-time 10 https://github.com | head -1
locale | grep LANG
```

### 2. 安装系统依赖

```bash
sudo apt update
sudo apt install -y chrpath diffstat lz4 gawk wget git-core diffstat unzip texinfo \
    gcc-multilib build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
    pylint3 xterm python3-subunit mesa-common-dev zstd liblz4-tool file repo
```

> 说明:chrpath/diffstat/lz4 是 bitbake HOSTTOOLS 硬性要求(缺失会直接报错)。

### 3. 初始化 repo 并同步

```bash
mkdir -p ~/shuhe-test && cd ~/shuhe-test
repo init -u https://github.com/stm32mp9527/oe-manifest.git -b shuhe-dev -m default.xml
repo sync -j8
```

> 网络失败时重试(每次间隔递增)。若某仓库持续失败,参考下方"故障排查-网络"。

### 4. 创建 build 目录(非交互)

```bash
cd ~/shuhe-test
DISTRO=openstlinux-weston MACHINE=stm32mp13-disco-test \
    source layers/meta-st/scripts/envsetup.sh
```

生成目录:`build-openstlinuxweston-stm32mp13-disco-test/`

### 5. 写入 local.conf 定制

将 `templates/local.conf.shuhe` 的内容**追加**到
`build-openstlinuxweston-stm32mp13-disco-test/conf/local.conf` 末尾:

```bash
cat ~/.config/opencode/skills/shuhe-ostl-deploy/templates/local.conf.shuhe \
    >> build-openstlinuxweston-stm32mp13-disco-test/conf/local.conf
```

> 模板内容(务必完整,勿删减):MACHINE/DISTRO/EULA、
> `ERROR_QA:remove = "version-going-backwards"`、4 个组件 github 源码源、
> `IMAGE_INSTALL:append`(dropbear/dpkg/lrzsz/kernel-modules/fbset/lvgl/lvgl-demo-fb/edid-decode)、
> `TF_A_CONFIG[optee-emmc]`(eMMC+optee 启动配置)。

### 6. 构建

```bash
cd ~/shuhe-test/build-openstlinuxweston-stm32mp13-disco-test
bitbake shuhe-test-image-core
```

- 首次构建:下载约 13GB + 全量编译,预计 1~2 小时(视机器性能)
- 中断后可重复执行同一命令续构建(增量)
- 再次部署/复用缓存时,可用 `DL_DIR` 指向已有 downloads 目录加速

### 7. 产物验证(防踩空 bootfs 坑)

构建成功后**必须**验证,否则烧录后可能卡 U-Boot:

```bash
IMG=tmp-glibc/deploy/images/stm32mp13-disco-test
ls -la $IMG/shuhe-test-image-core-*.splitted-bootfs-*.ext4
# bootfs 内必须能看到 uImage / stm32mp135f-test.dtb / extlinux / st-image-resize-initrd:
debugfs -R "ls -l /" $IMG/shuhe-test-image-core-*.splitted-bootfs-*.ext4 | tail -8
# flashlayout tsv 存在:
ls $IMG/flashlayout_shuhe-test-image-core/optee/FlashLayout_emmc_stm32mp135f-test-optee.tsv
# 内核版本(应为 6.6.129):
ls $IMG/kernel/config-*
```

### 8. 烧录与启动验证

1. 拷贝 `$IMG/` 到烧录机
2. STM32CubeProgrammer 加载
   `flashlayout_shuhe-test-image-core/optee/FlashLayout_emmc_stm32mp135f-test-optee.tsv`
   烧录 eMMC(板子 USB 连接,需进入 DFU 模式)
3. 启动后验证(用户板卡功能清单):
   ```bash
   # 网口(两路 125MHz PLL4P)
   ip link  # eth0/eth1 UP
   # HDMI(经 SII9022,edid-decode 已内置)
   edid-decode /sys/class/drm/card0-HDMI-A-1/edid
   # USB
   lsusb
   # LVGL 显示 demo
   lvgl-demo-fb
   ```

## 故障排查

| 症状 | 原因 | 处理 |
|------|------|------|
| `repo sync` 某仓库卡住/超时 | github 连接不稳定 | 重试;或手动预下载:`git clone --bare --mirror https://github.com/<org>/<repo>.git downloads/git2/<host>.<path>` 后重跑 |
| 构建报 `TMPDIR has changed location` | build 目录被复制/移动过 | `echo "$PWD/tmp-glibc" > tmp-glibc/saved_tmpdir` |
| 烧录后卡 U-Boot、`Cannot load any image` | bootfs 空 | 重新构建并执行"步骤 7 产物验证";确认 meta-st fork 是 shuhe-dev 最新(shuhe-test-image-core.bb 含 `IMAGE_INSTALL:append = " \${MACHINE_ESSENTIAL_EXTRA_RDEPENDS} st-initrd"`) |
| pseudo 编译失败 | 主机 glibc 过新 | ST 官方 r3.1 已修复(SRCREV 43cbd8fb);仍失败时检查 openembedded-core 的 pseudo_git.bb 是否有本地改动 |
| 磁盘空间不足 | 首次构建需 ≥100GB | 清理 sstate-cache/tmp-glibc 历史产物 |
| `version-going-backwards` 报错 | 版本回退检查 | 确认 local.conf 已含 `ERROR_QA:remove = "version-going-backwards"` |
| locale 报错 | 非 en_US.UTF-8 | `sudo locale-gen en_US.UTF-8` 后重新登录 |
| bitbake: 未找到命令 | 未 source 环境 | 在 build 目录执行 `source <oe-root>/layers/openembedded-core/oe-init-build-env .` |

## 常用命令(客户/开发参考)

```bash
bitbake -s                                  # 列出所有可编译目标
bitbake linux-stm32mp                       # 只编译内核
bitbake -c cleanall linux-stm32mp           # 清理内核后重新 fetch
bitbake -e linux-stm32mp | grep ^SRCREV     # 查看实际使用的 SRCREV
bitbake -c cleansstate shuhe-test-image-core # 强制重建镜像
```

## 定制来源说明(客户透明)

- manifest:github.com/stm32mp9527/oe-manifest(branch `shuhe-dev`)
- meta-st-stm32mp / meta-st-openstlinux:基于 ST v26.06.10 + shuhe 定制
  (stm32mp13-disco-test machine、-test 设备树、shuhe-test-image-core 等)
- linux / tf-a / optee / u-boot:ST r3.1 + 板卡定制(HDMI/eth/USB/PLL4 等)
- ST 上游版本:openstlinux-6.6-yocto-scarthgap-mpu-v26.06.10(2026-06-10)
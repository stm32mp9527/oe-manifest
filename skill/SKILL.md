---
name: shuhe-ostl-deploy
description: |
  一键在新电脑上部署/复刻 OpenSTLinux shuhe 定制项目(STM32MP13-DK 双板型)。
  支持对话式选择板型(自定义板 stm32mp13-disco-test / 官方板 stm32mp13-disco-dk)、
  启动介质(eMMC/SD 卡)、附加组件,自动完成:系统依赖检查安装、repo 初始化同步、
  envsetup 非交互配置、local.conf 定制写入、bitbake 构建、产物验证与烧录指引。
  附带定制点快速定位(locate.sh)、命令行配置(configure.sh)、新板生成器(newboard.sh)。
  包含 github 源码源、TF_A_CONFIG 覆盖、IMAGE_INSTALL 定制、
  ERROR_QA 跳过版本回退检查等客户环境必需配置。
  用于:"一键部署"、"复刻到新电脑"、"新环境构建 OpenSTLinux"、
  "出个官方板版本"、"shuhe 部署"、"客户机器搭建"、"bitbake 全流程"等请求。
  (shuhe)
---

# /shuhe-ostl-deploy — OpenSTLinux shuhe 项目一键部署(v2 双板型)

在新电脑上从零部署 **OpenSTLinux shuhe 定制项目**(STM32MP135F),双板型:

| 板型 | 机器 | 镜像 | 内存 | 介质 | 设备树 |
|------|------|------|------|------|--------|
| 自定义板 | `stm32mp13-disco-test` | `shuhe-test-image-core` | 256MB | eMMC(可 SD) | `-test` 体系 |
| 官方板 | `stm32mp13-disco-dk` | `shuhe-image-core` | 512MB | SD 卡 | 官方 `stm32mp135f-dk` |

所有定制(meta-st 两层 fork、内核/固件 fork、manifest)都已推送到
`github.com/stm32mp9527`,部署全程从 GitHub 拉取,无需手工复制任何文件。

## 对话式选择(opencode 场景)

用户提出构建需求时,先用 AskUserQuestion 依次确认:

- **Q1 板型**:
  1. 自定义板(`stm32mp13-disco-test` / `shuhe-test-image-core`,默认)
  2. 官方板(`stm32mp13-disco-dk` / `shuhe-image-core`,SD 卡 wic 烧录)
- **Q2 介质**(仅自定义板时询问):① eMMC(默认,FlashLayout tsv 烧录)
  ② SD 卡 ③ 双产物
- **Q3 附加**:摄像头(libcamera,默认不开)/ LVGL demo / 调试工具(默认全开)

确认后自动:写入 local.conf(configure.sh 逻辑)→ 构建 → 输出对应烧录指引。

## 快速开始(客户无 opencode 时)

```bash
# 命令行交互/参数式配置 local.conf(板型/介质)
bash ~/.config/opencode/skills/shuhe-ostl-deploy/scripts/configure.sh \
    --board dk | test [--media emmc|sdcard|both] [--camera]

# 定位外设修改点(双板型对照)
bash ~/.config/opencode/skills/shuhe-ostl-deploy/scripts/locate.sh 网口

# 全流程一键部署(默认: 自定义板 eMMC)
bash ~/.config/opencode/skills/shuhe-ostl-deploy/scripts/deploy.sh

# 新自定义板一键生成(机器+镜像+dts 骨架)
bash ~/.config/opencode/skills/shuhe-ostl-deploy/scripts/newboard.sh \
    --name stm32mp13-disco-xxx --dt stm32mp135f-xxx-test --media emmc
```

## 前置条件(自动检查,不满足会提示)

- 操作系统:Ubuntu 20.04 / 22.04 / 24.04(x86_64)
- 网络:可访问 `github.com`(首次需下载约 13GB 源码)
- 磁盘:建议 ≥100GB 可用空间
- 工具:git、python3、curl、repo(缺失自动安装)
- locale:`en_US.UTF-8`(构建需要)

## 部署流程(自定义板 eMMC 默认路径)

### 1. 环境检查

```bash
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

自定义板:
```bash
cd ~/shuhe-test
DISTRO=openstlinux-weston MACHINE=stm32mp13-disco-test \
    source layers/meta-st/scripts/envsetup.sh
```

官方板(生成目录 `build-openstlinuxweston-stm32mp13-disco-dk/`):
```bash
cd ~/shuhe-test
DISTRO=openstlinux-weston MACHINE=stm32mp13-disco-dk \
    source layers/meta-st/scripts/envsetup.sh
```

### 5. 写入 local.conf 定制

自定义板:
```bash
cat ~/.config/opencode/skills/shuhe-ostl-deploy/templates/local.conf.shuhe \
    >> build-openstlinuxweston-stm32mp13-disco-test/conf/local.conf
```

官方板(含 wic SD 卡镜像):
```bash
cat ~/.config/opencode/skills/shuhe-ostl-deploy/templates/local.conf.dk \
    >> build-openstlinuxweston-stm32mp13-disco-dk/conf/local.conf
```

或用 `configure.sh` 交互式/参数式生成(推荐)。

> 模板内容(务必完整,勿删减):MACHINE/DISTRO/EULA、
> `ERROR_QA:remove = "version-going-backwards"`、4 个组件 github 源码源、
> `IMAGE_INSTALL:append`(dropbear/dpkg/lrzsz/kernel-modules/fbset/lvgl/lvgl-demo-fb/edid-decode)、
> TF-A 覆盖(自定义板 `optee-emmc`;官方板自动派生 `optee-sdcard`)、wic 配置(官方板)。

### 6. 构建

```bash
cd ~/shuhe-test/build-openstlinuxweston-stm32mp13-disco-test
bitbake shuhe-test-image-core     # 自定义板
# 官方板: cd ../build-openstlinuxweston-stm32mp13-disco-dk && bitbake shuhe-image-core
```

- 首次构建:下载约 13GB + 全量编译,预计 1~2 小时(视机器性能)
- 中断后可重复执行同一命令续构建(增量)
- 再次部署/复用缓存时,可用 `DL_DIR` 指向已有 downloads 目录加速

### 7. 产物验证(防踩空 bootfs 坑)

自定义板:
```bash
IMG=tmp-glibc/deploy/images/stm32mp13-disco-test
ls -la $IMG/shuhe-test-image-core-*.splitted-bootfs-*.ext4
debugfs -R "ls -l /" $IMG/shuhe-test-image-core-*.splitted-bootfs-*.ext4 | tail -8
ls $IMG/flashlayout_shuhe-test-image-core/optee/FlashLayout_emmc_stm32mp135f-test-optee.tsv
ls $IMG/kernel/config-*
```

官方板(wic SD 卡镜像):
```bash
IMG=tmp-glibc/deploy/images/stm32mp13-disco-dk
ls -la $IMG/shuhe-image-core-*.rootfs.wic*        # 必须存在 wic 产物
ls $IMG/arm-trusted-firmware/tf-a-stm32mp135f-dk-optee-sdcard.stm32
ls $IMG/fip/fip-stm32mp135f-dk-optee-sdcard.bin
# bootfs 分区内容检查(解包 wic):
wic ls $IMG/shuhe-image-core-*.rootfs.wic | grep -i boot
```

### 8. 烧录与启动验证

自定义板(eMMC):
1. 拷贝 `$IMG/` 到烧录机
2. STM32CubeProgrammer 加载
   `flashlayout_shuhe-test-image-core/optee/FlashLayout_emmc_stm32mp135f-test-optee.tsv`
   烧录 eMMC(板子 USB 连接,需进入 DFU 模式)
3. 启动后验证(用户板卡功能清单):
   ```bash
   ip link  # eth0/eth1 UP
   edid-decode /sys/class/drm/card0-HDMI-A-1/edid
   lsusb
   lvgl-demo-fb
   ```

官方板(SD 卡):
```bash
# Linux 主机 dd 烧录(先确认 SD 卡设备名, 如 /dev/sdb)
sudo dd if=shuhe-image-core-*.rootfs.wic of=/dev/sdX bs=4M conv=fsync
# 或 xz 版: xz -dk shuhe-image-core-*.rootfs.wic.xz 后 dd
```
启动后验证:`cat /proc/meminfo | grep MemTotal`(≈512MB)、`ip link`、`lsusb`、
`edid-decode`(如有 DSI→HDMI 适配)。

## 定制点快速定位(外设修改)

```bash
locate.sh 网口 | eth      # 网口 dts/pinctrl/驱动配置位置(双板对照)
locate.sh hdmi | usb | 摄像头 | pll4 | 模块 | boot | 介质
locate.sh --all           # 输出完整地图 docs/CUSTOM_MAP.md
```

示例(网口):
```bash
$ locate.sh 网口
## 1. 网口(eth1/eth2)
| 项目 | 自定义板(-test) | 官方板(官方 dk) |
| 设备树 | stm32mp135f-test.dts:265-307(rgmii-id + dwmac-mdio + PHY) | stm32mp135f-dk.dts:252/279(phy-handle) |
...
```

## 新自定义板(一条命令生成)

```bash
newboard.sh --name stm32mp13-disco-xxx --dt stm32mp135f-xxx-test \
            --media emmc [--image shuhe-xxx-image-core] [--commit] [--push]
```

自动生成:机器 conf + 镜像 recipe(含 bootfs 修复)+ 内核 dts 骨架(含外设注释引导)。
之后:按 CUSTOM_MAP 改外设 → envsetup 选新机器 → `bitbake shuhe-xxx-image-core`。

## 故障排查

| 症状 | 原因 | 处理 |
|------|------|------|
| `repo sync` 某仓库卡住/超时 | github 连接不稳定 | 重试;或手动预下载:`git clone --bare --mirror https://github.com/<org>/<repo>.git downloads/git2/<host>.<path>` 后重跑 |
| 构建报 `TMPDIR has changed location` | build 目录被复制/移动过 | `echo "$PWD/tmp-glibc" > tmp-glibc/saved_tmpdir` |
| 烧录后卡 U-Boot、`Cannot load any image` | bootfs 空 | 重新构建并执行"步骤 7 产物验证";确认 meta-st fork 是 shuhe-dev 最新(shuhe-*.bb 含 `IMAGE_INSTALL:append = " \${MACHINE_ESSENTIAL_EXTRA_RDEPENDS} st-initrd"`) |
| 官方板 SD 卡启动失败 | wic 分区/bootfs 问题 | 验证 `tf-a-*-dk-optee-sdcard.stm32`/`fip-*-dk-optee-sdcard.bin` 存在(机器 conf 自动派生);`wic ls` 检查 bootfs 分区 |
| pseudo 编译失败 | 主机 glibc 过新 | ST 官方 r3.1 已修复(SRCREV 43cbd8fb);仍失败时检查 openembedded-core 的 pseudo_git.bb 是否有本地改动 |
| 磁盘空间不足 | 首次构建需 ≥100GB | 清理 sstate-cache/tmp-glibc 历史产物 |
| `version-going-backwards` 报错 | 版本回退检查 | 确认 local.conf 已含 `ERROR_QA:remove = "version-going-backwards"` |
| locale 报错 | 非 en_US.UTF-8 | `sudo locale-gen en_US.UTF-8` 后重新登录 |
| bitbake: 未找到命令 | 未 source 环境 | 在 build 目录执行 `source <oe-root>/layers/openembedded-core/oe-init-build-env .` |
| envsetup 列表看不到新机器 | 机器 conf 未同步 | `repo sync` 后确认 `conf/machine/<name>.conf` 存在且无语法错误 |

## 常用命令(客户/开发参考)

```bash
bitbake -s                                  # 列出所有可编译目标
bitbake linux-stm32mp                       # 只编译内核
bitbake -c cleanall linux-stm32mp           # 清理内核后重新 fetch
bitbake -e linux-stm32mp | grep ^SRCREV     # 查看实际使用的 SRCREV
bitbake -c cleansstate shuhe-image-core     # 强制重建镜像
```

## 定制来源说明(客户透明)

- manifest:github.com/stm32mp9527/oe-manifest(branch `shuhe-dev`)
- meta-st-stm32mp / meta-st-openstlinux:基于 ST v26.06.10 + shuhe 定制
  (`stm32mp13-disco-test` / `stm32mp13-disco-dk` 机器、-test/官方设备树、
  shuhe-*-image-core 等)
- linux / tf-a / optee / u-boot:ST r3.1 + 板卡定制(HDMI/eth/USB/PLL4 等);
  `stm32mp135f-dk.dts` 已还原官方版(512MB),供官方板使用
- ST 上游版本:openstlinux-6.6-yocto-scarthgap-mpu-v26.06.10(2026-06-10)

# 初始化 repo

```bash  创建一个存放项目的目录，并进入目录
mkdir -p ~/shuhe-test  && cd shuhe-test

repo init -u https://github.com/stm32mp9527/oe-manifest.git \
          -b shuhe-dev \
          -m default.xml

repo sync -j8
```

# 创建 build 目录

```bash
cd /develop/lwg/shuhe-test
source layers/meta-st/scripts/envsetup.sh
```

交互选择：
- DISTRO → openstlinux-weston
- MACHINE → stm32mp13-disco-test



# 配置 local.conf

```bash
vi build-openstlinuxweston-stm32mp13-disco-test/conf/local.conf
```

在文件末尾添加：

```bitbake
# =========================================================================
# MACHINE / DISTRO
# =========================================================================
MACHINE = "stm32mp13-disco-test"
DISTRO = "openstlinux-weston"

# =========================================================================
# 接受 ST EULA
# =========================================================================
ACCEPT_EULA_stm32mp13-disco-test = "1"

# =========================================================================
# 下载缓存目录 通过配置指定下载缓存目录
# =========================================================================
DL_DIR = "/home/lwg/work/shuhe-package/distribution/downloads"


# =========================================================================
# 跳过版本回退检查
# =========================================================================
ERROR_QA:remove = "version-going-backwards"

# =========================================================================
# 从 GitHub 拉取 BSP 源码
# =========================================================================
STM32MP_SOURCE_SELECTION:pn-linux-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-optee-os-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-tf-a-stm32mp = "github"
STM32MP_SOURCE_SELECTION:pn-u-boot-stm32mp = "github"

IMAGE_INSTALL:append = " dropbear dpkg lrzsz kernel-modules fbset"

TF_A_CONFIG[optee-emmc] = "\
    ${STM32MP_DT_FILES_EMMC},\
    ${TF_A_CONFIG_OPTS_optee} ${TF_A_CONFIG_OPTS_EXTDT} ${TF_A_CONFIG_OPTS_features} ${TF_A_CONFIG_OPTS_fwupdate} STM32MP_EMMC=1 STM32MP_EMMC_BOOT=1,\
    ${TF_A_CONFIG_BASENAME_BIN},\
    ${TF_A_CONFIG_MAKE_TARGET},\
    ${TF_A_CONFIG_DEPLOY_FTYPE} ${TF_A_CONFIG_DEPLOY_EXTRA},\
    ${EXTDT_SUFFIX_EMMC}"





```

# 编译

```bash
cd /develop/lwg/shuhe-test/build-openstlinuxweston-stm32mp13-disco-test
bitbake shuhe-test-image-core
```

产物位置：

```
build-openstlinuxweston-stm32mp13-disco-test/tmp-glibc/deploy/images/stm32mp13-disco-test/
```

# 常用命令

```bash
bitbake -s                                  # 列出所有可编译目标
bitbake linux-stm32mp                       # 只编译内核
bitbake -c cleanall linux-stm32mp           # 清理内核后重新 fetch
bitbake -e linux-stm32mp | grep ^SRCREV     # 查看实际使用的 SRCREV
```

# 复刻到新环境

在新机器上，只需：

```bash
mkdir project && cd project
repo init -u https://github.com/stm32mp9527/oe-manifest.git -b shuhe-dev
repo sync
source layers/meta-st/scripts/envsetup.sh   # 选 DISTRO + MACHINE
# 按上方说明修正 bblayers.conf 和 local.conf
bitbake shuhe-test-image-core
```

所有定制文件已推送至 GitHub，无需任何手工复制。



# 一键部署 skill(推荐)

面向客户的零门槛部署方式,已随本仓库分发(`skill/` 目录):

## 方式一:独立脚本(无需 opencode)

```bash
bash skill/shuhe-ostl-deploy/scripts/deploy.sh
```

自动完成:环境检查 → 安装依赖 → repo sync → 生成 build 目录 →
写入 local.conf 定制 → bitbake shuhe-test-image-core → 产物验证。

## 方式二:opencode skill(语音/文字触发)

```bash
# 1. 安装 opencode 后, 把 skill 链接到用户目录:
ln -sf ~/shuhe-test/skill/shuhe-ostl-deploy ~/.config/opencode/skills/
# 2. 对 opencode 说: "一键部署 shuhe 项目" 即可全流程执行
```

两者等效;首次构建均需下载约 13GB 源码,耗时 1~2 小时。

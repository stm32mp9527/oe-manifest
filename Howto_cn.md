
# 初始化 repo

```bash  创建一个存放项目的目录，并进入目录
mkdir -p ~/shuhe-test  && cd shuhe-test

repo init -u https://github.com/stm32mp9527/oe-manifest.git \
          -b shuhe-dev \
          -m default.xml

repo sync
```

# 创建 build 目录

```bash
cd /develop/lwg/shuhe-test
source layers/meta-st/scripts/envsetup.sh
```

交互选择：
- DISTRO → openstlinux-weston
- MACHINE → stm32mp13-disco-test

# 修正 bblayers.conf

```bash
vi build-openstlinuxweston-stm32mp13-disco-test/conf/bblayers.conf
```

将底部硬编码路径改为：

```bitbake
BBLAYERS =+ "${OEROOT}/layers/meta-openembedded/meta-oe"
BBLAYERS =+ "${OEROOT}/layers/meta-openembedded/meta-python"
```

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
# 启用分区包构建
# =========================================================================
ST_BOOTFS = "1"
ST_VENDORFS = "1"
ST_USERFS = "1"

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



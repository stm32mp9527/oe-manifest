---
name: shuhe-ostl-mp2
description: |
  STM32MP257F-DK OpenSTLinux（MACHINE=stm32mp2-m33td，st-image-weston）部署/构建/烧录/
  设备树/外设/自定义板手册入口。触发词：STM32MP257、257F-DK、MP2、一键部署、
  构建镜像、烧录 eMMC、烧录 SD、改设备树、改引脚、pinctrl、新增 UART/I2C/SPI/GPIO、
  新外设、自定义板、M33、TF-M、改主机名、改网络、加软件包、改分区、开机 logo、排错。
---

# shuhe-ostl-mp2 — 入口 stub（完整手册随 repo sync 分发）

**本文件只是入口，不含完整正文。** 完整手册位置：

```text
<ROOT>/layers/meta-st/meta-st-stm32mp/docs/shuhe-skill-mp2/SKILL.md
```

同目录还有：

- `HARDWARE_MAP.md` —— 257F-DK 板级参数、boot switch、DTS 节点映射
- `CUSTOM_MAP.md` —— 常用本地修改/外设启用/自定义板导航
- `README.md` / `ROLLBACK.md`

## 新电脑还没 sync（找不到完整手册）时

先向用户确认仓库地址；如果是 `stm32mp9527/oe-manifest`：

```bash
mkdir -p <ROOT> && cd <ROOT>
repo init -u https://github.com/stm32mp9527/oe-manifest.git -b shuhe-dev -m default.xml
repo sync -j8
```

sync 完成后读上面的完整手册路径。

## 铁律（先记住）

1. 先找 `<ROOT>`/`<BUILD>`/`<DEPLOY>`，不硬编码路径。
2. 官方 257F-DK 用内置硬件映射；自定义板必须要有原理图/引脚表，禁止猜引脚。
3. 永久修改落到 layer/bbappend/patch/devtool，不要只改 `tmp-glibc/work`。
4. 改前记录原值，改后构建 + 板上验证。
5. 烧录/擦除/改 boot switch 前先确认。
6. 不要把 MP1（STM32MP135F）的引脚/节点套到 257F-DK。

## 安装/更新

见同目录 `README.md`。

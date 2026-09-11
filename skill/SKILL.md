---
name: shuhe-ostl-deploy
description: |
  shuhe OpenSTLinux(STM32MP135F 双板型)部署/构建/板卡适配手册入口(完整版随
  构建树分发)。触发词:一键部署、shuhe 部署、复刻到新电脑、出个镜像、
  新板子适配、改外设、新增外设、本地改 dts。
---

# shuhe-ostl-deploy — 入口 stub(完整手册随 repo sync 分发)

**本文件只是入口,不含手册正文(省 token)。** 完整手册位置:

- 已 repo sync:`~/shuhe/layers/meta-st/meta-st-stm32mp/docs/shuhe-skill/SKILL.md`
  (同目录含 CUSTOM_MAP.md / HARDWARE_MAP.md / ROLLBACK.md / templates/)
- **部署、适配、改 dts 前,必须先读完整手册,并遵守其第 0 节铁律**

**新电脑还没 sync(找不到完整手册)时,先执行:**

```bash
mkdir -p ~/shuhe && cd ~/shuhe
repo init -u https://github.com/stm32mp9527/oe-manifest.git -b shuhe-dev -m default.xml
repo sync -j8
```

sync 完成后读上面的完整手册路径,再开始部署。

- 本 stub 的安装/更新方法见同目录 `README.md`
- 手册主体改动请改 meta-st-stm32mp 层内文件(本仓库只留 stub,唯一真相源在层里)

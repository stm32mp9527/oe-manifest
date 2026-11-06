# shuhe-ostl-mp2 — 入口 stub（自举用）

本目录是 opencode / OpenClaw / 其他 agent 的注册入口（纯 markdown），**不含完整手册**。
完整手册随 `meta-st-stm32mp` 层分发，`repo sync` 后位于：

```text
<ROOT>/layers/meta-st/meta-st-stm32mp/docs/shuhe-skill-mp2/SKILL.md
```

## 安装

```bash
git clone -b shuhe-dev --depth 1 https://github.com/stm32mp9527/oe-manifest.git /tmp/om
mkdir -p ~/.config/opencode/skills
cp -r /tmp/om/skill-mp2 ~/.config/opencode/skills/shuhe-ostl-mp2

# OpenClaw:
# mkdir -p ~/.openclaw/skills
# cp -r /tmp/om/skill-mp2 ~/.openclaw/skills/shuhe-ostl-mp2
```

| agent | 安装目标目录 | 触发方式 |
|-------|-------------|----------|
| opencode | `~/.config/opencode/skills/shuhe-ostl-mp2/` | 触发词自动加载 |
| OpenClaw（龙虾） | `~/.openclaw/skills/shuhe-ostl-mp2/` 或工作区 `skills/` | 触发词自动注入 |
| 其他 agent | 工作区任意位置 | 开局让它读本目录 `SKILL.md` |

## 触发词

STM32MP257 / 257F-DK / MP2 / 一键部署 / 构建镜像 / 烧录 eMMC / 烧录 SD /
改设备树 / 改引脚 / pinctrl / 新增 UART / I2C / SPI / GPIO / 新外设 / 自定义板 /
M33 / TF-M / 改主机名 / 改网络 / 加软件包 / 改分区 / 开机 logo / 排错

## 完整手册在哪

- 已 repo sync：`<ROOT>/layers/meta-st/meta-st-stm32mp/docs/shuhe-skill-mp2/SKILL.md`
- 同目录：`HARDWARE_MAP.md`、`CUSTOM_MAP.md`、`ROLLBACK.md`
- MP1 项目请用 `shuhe-ostl-deploy`（`docs/shuhe-skill/SKILL.md`），不要混用。

## 维护纪律

- 正文改动去 `meta-st-stm32mp` 层的 `docs/shuhe-skill-mp2/`；本目录只维护入口。
- 触发词/安装路径变更时同步更新本 README 和项目内 `README.md`。

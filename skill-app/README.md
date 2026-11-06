# shuhe-ostl-app — 入口 stub（自举用）

本目录是 opencode / OpenClaw / 其他 agent 的注册入口（纯 markdown），
**不含完整手册**。完整手册随 `meta-st-openstlinux` 层分发，`repo sync` 后位于：

```text
<ROOT>/layers/meta-st/meta-st-openstlinux/docs/shuhe-skill-app/SKILL.md
```

## 安装

```bash
git clone -b shuhe-dev --depth 1 https://github.com/stm32mp9527/oe-manifest.git /tmp/om
mkdir -p ~/.config/opencode/skills
cp -r /tmp/om/skill-app ~/.config/opencode/skills/shuhe-ostl-app

# OpenClaw:
# mkdir -p ~/.openclaw/skills
# cp -r /tmp/om/skill-app ~/.openclaw/skills/shuhe-ostl-app
```

| agent | 安装目标目录 | 触发方式 |
|-------|-------------|----------|
| opencode | `~/.config/opencode/skills/shuhe-ostl-app/` | 触发词自动加载 |
| OpenClaw（龙虾） | `~/.openclaw/skills/shuhe-ostl-app/` 或工作区 `skills/` | 触发词自动注入 |
| 其他 agent | 工作区任意位置 | 开局让它读本目录 `SKILL.md` |

## 触发词

开发 app / 上层应用 / 网络通讯程序 / TCP / UDP / HTTP / MQTT /
HDMI / LCD 显示 / 图像程序 / 开机自启动 / 第三方开发 / 不碰底层 /
app recipe / bitbake app

## 完整手册在哪

- 已 repo sync：`<ROOT>/layers/meta-st/meta-st-openstlinux/docs/shuhe-skill-app/SKILL.md`
- 同目录：`APP_MAP.md`、`README.md`、`DOCKER_VM.md`、`templates/`
- 底层 BSP/部署：`shuhe-ostl-deploy`（`docs/shuhe-skill/SKILL.md`）
- MP2/257F-DK：`shuhe-ostl-mp2`（`docs/shuhe-skill-mp2/SKILL.md`）

## 维护纪律

- 正文改动去 `meta-st-openstlinux` 层的 `docs/shuhe-skill-app/`；本目录只维护入口。
- 触发词/安装路径变更时同步更新本 README。
- 模板改动必须在 Yocto 环境实际 build 过。

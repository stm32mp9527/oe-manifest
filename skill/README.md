# shuhe-ostl-deploy — 入口 stub(自举用)

本目录是 opencode / OpenClaw 的注册入口(纯 markdown),**不含手册正文**——
正文已迁往 meta-st-stm32mp 层,`repo sync` 后随构建树分发(为省 token 不在此复制)。

## 安装(新电脑,AI 代劳或照抄;https 失败换 ssh 协议)

```bash
git clone -b shuhe-dev --depth 1 https://github.com/stm32mp9527/oe-manifest.git /tmp/om
mkdir -p ~/.config/opencode/skills && cp -r /tmp/om/skill ~/.config/opencode/skills/shuhe-ostl-deploy
# OpenClaw:把 mkdir/cp 的目标换成 ~/.openclaw/skills/shuhe-ostl-deploy
```

| agent | 安装目标目录 | 触发方式 |
|-------|-------------|---------|
| opencode | `~/.config/opencode/skills/shuhe-ostl-deploy/` | 触发词自动加载 |
| OpenClaw(龙虾) | `~/.openclaw/skills/shuhe-ostl-deploy/`(全机共享)或 `~/.openclaw/workspace/skills/`(单 agent,优先级更高) | 触发词自动注入 |
| 其他 agent(Crush/Claude Code 等) | 工作区任意位置 | 开局让 agent 读本目录 `SKILL.md` |

## 完整手册在哪

- 已 repo sync:`~/shuhe/layers/meta-st/meta-st-stm32mp/docs/shuhe-skill/SKILL.md`
- 另一层指针:`layers/meta-st/meta-st-openstlinux/docs/shuhe-skill/README.md`
- 新电脑还没 sync:先 `repo init -u https://github.com/stm32mp9527/oe-manifest.git -b shuhe-dev -m default.xml` 再 `repo sync -j8`,然后读上面的手册路径

## 维护纪律

- 手册正文改动一律去 **meta-st-stm32mp 层**对应目录改;本 stub 只维护入口信息
- 触发词:一键部署 / shuhe 部署 / 复刻到新电脑 / 出个镜像 / 新板子适配 / 改外设 / 新增外设 / 本地改 dts
- 分发模式变更记录见层内 `ROLLBACK.md`

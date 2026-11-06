---
name: shuhe-ostl-app
description: |
  STM32MP1 OpenSTLinux 上层应用开发入口（type 2 客户：不改 kernel/uboot/dts，
  只开发 app）。是 shuhe-ostl-deploy 的 companion。
  触发词：开发 app、上层应用、网络通讯程序、TCP/UDP/HTTP/MQTT、HDMI/LCD 显示、
  图像程序、开机自启动、第三方开发、不碰底层、app recipe、bitbake app。
---

# shuhe-ostl-app — 入口 stub（完整手册随 repo sync 分发）

**本文件只是入口，不含完整正文。** 完整手册位置：

```text
<ROOT>/layers/meta-st/meta-st-openstlinux/docs/shuhe-skill-app/SKILL.md
```

同目录还有：

- `APP_MAP.md` —— app 类型/镜像能力/依赖/验证矩阵
- `README.md` / `DOCKER_VM.md`
- `templates/network-app/`、`templates/display-app/`

## 新电脑还没 sync（找不到完整手册）时

先向用户确认仓库地址；如果是 `stm32mp9527/oe-manifest`：

```bash
mkdir -p <ROOT> && cd <ROOT>
repo init -u https://github.com/stm32mp9527/oe-manifest.git -b shuhe-dev -m default.xml
repo sync -j8
```

sync 完成后读上面的完整手册路径。

## 铁律（先记住）

1. 只做 app：不改 kernel/u-boot/TF-A/OP-TEE/DTS/pinctrl/分区。
2. 客户不需要懂交叉编译器；AI 负责 recipe/bitbake/部署/自启动。
3. 先找 `<ROOT>`/`<BUILD>`/`<DEPLOY>`，不硬编码路径。
4. app 放 `meta-customer-app`，不改官方 meta-st 层。
5. 先问清网络协议/显示内容/自启/板子 IP，再写代码。
6. 必须 build + 上板/实际网络/实际屏幕验证。
7. 底层/驱动/分辨率/网口 PHY/分区问题 → 转 `shuhe-ostl-deploy`。

## 安装/更新

见同目录 `README.md`。

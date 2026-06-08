# hasee-Z8-CA5NB-fan-control-linux

神舟 Z8-CA5NB Linux 风扇控制（静音工具）

专为神舟 Z8-CA5NB（Clevo NH5x 模具）设计的 Linux 风扇控制脚本。一键开启静音模式，解决 Linux 下风扇噪音过大的问题。

## 基本信息

- **适用机型**：神舟 Z8-CA5NB（同模具请谨慎尝试，需自行验证）
- **操作系统**：Ubuntu 26.04（其他 Linux 发行版需内核支持 ec_sys 和 acpi_call）
- **核心功能**：静音模式、性能模式、EC 自动模式
- **开发辅助**：DeepSeek · ChatGPT · GLM · workbuddy
- **开源协议**：The Unlicense（公共领域）

## 工程简介

Windows 下神舟笔记本可通过控制中心开启静音模式，但 Linux 下 lm-sensors、fancontrol 等工具无法识别该机型的 EC 寄存器。本项目通过逆向 Windows 驱动 + ACPI/WMI 调用，直接向 EC 发送命令，实现了静音、性能、自动三种风扇模式。

## 开发原理

- 反编译 Windows 程序发现 WMI 命令 `0x79` 用于模式切换（0=自动，1=最大性能，3=静音）。
- Linux 下使用 `acpi_call` 模块向 `\_SB.WMI.WMBB` 发送相同命令。
- 通过 `ec_sys` 读取 EC 寄存器（`/sys/kernel/debug/ec/ec0/io`）获取温度、占空比和转速。
- RPM 计算公式：`2156220 / raw`（raw 为两字节计数值）。

## 使用方法

### 1. 解压与安装

解压后进入目录，给脚本添加执行权限：

```bash
unzip hasee-Z8-CA5NB-fan-control-linux.zip
cd hasee-Z8-CA5NB-fan-control-linux
chmod +x fanctl.sh
```

### 2. 安装依赖

Ubuntu/Debian 执行：

```bash
sudo apt install acpi-call-dkms
```

脚本会自动加载 `ec_sys write_support=1` 和 `acpi_call`，无需手动 modprobe。

### 3. 运行并开启静音模式

使用 root 权限运行：

```bash
sudo ./fanctl.sh
```

进入菜单后，输入 `2` 回车即可切换到静音模式，输入 `q` 回车退出。

每次开机执行一次即可，效果保持到下次切换或重启。


## 验证结果（实机测试）

| 模式 | 占空比 | 噪音感受 | 适用场景 |
|------|--------|----------|----------|
| 静音模式 | 约 35% | 几乎无声（<2000 RPM） | 办公、上网、视频 |
| 性能模式 | 100% | 明显风声 | 游戏、编译、渲染 |
| EC 自动 | 动态调节 | 中等 | 默认平衡 |

室温 25°C 下，静音模式 CPU 温度 55–60°C，噪音降低约 80%。

## 常见问题

**Q: modprobe: FATAL: Module acpi_call not found**  
A: 安装 `acpi-call-dkms` 并重启。

**Q: /sys/kernel/debug/ec/ec0/io 不存在**  
A: 执行 `sudo mount -t debugfs none /sys/kernel/debug`。

**Q: 切换静音模式后风扇仍吵**  
A: 等待 3–5 秒，或再次输入 `2`。

**Q: 如何恢复默认？**  
A: 运行脚本输入 `1` 或重启电脑。

**Q: 其他 Linux 发行版能用吗？**  
A: 需要内核支持 ec_sys 和 acpi_call，理论上可尝试，但未测试。

## 开源协议

The Unlicense – 公共领域贡献。可自由使用、修改、复制、分发、商用，无需署名，无担保。

## 致谢

- DeepSeek、ChatGPT、GLM、workbuddy —— AI 辅助开发
- tuxedo-control-center —— WMI 接口参考
- 神舟 Z8-CA5NB 实机验证者（本人）

---

**最后提醒**：静音模式会限制风扇转速，长时间高负载可能导致温度升高，请根据实际情况切换。本工具按“现状”提供，作者不对任何硬件故障负责。

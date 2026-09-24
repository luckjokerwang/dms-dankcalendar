# 📅 Dank Calendar Plus

<div align="center">

[![DMS Plugin](https://img.shields.io/badge/DMS-Plugin-blue.svg)](https://github.com/AvengeMedia/DankMaterialShell)
[![Version](https://img.shields.io/badge/Version-v3.4.0-brightgreen.svg)](https://github.com/luckjokerwang/dms-dankcalendar)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-orange.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Wayland-purple.svg)](https://github.com/luckjokerwang/dms-dankcalendar)

**专为 [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) & [dcal](https://github.com/AvengeMedia/dcal) 打造的下一代全功能智能化日程与待办生产力工作台**

*Next-generation, AI-powered Agenda & Tasks management platform for DankMaterialShell: Dynamic Bar Pill, Immersive Popout View, One-click Meeting Join, 0ms Optimistic Tasks, and Multimodal AI Assistant.*

</div>

---

## 📸 界面预览 (Screenshots)

<div align="center">
  <p><b>🤖 智能 AI 排程助理 (AI Scheduling Assistant)</b></p>
  <img src="assets/screenshot-ai.png" alt="AI Scheduling Assistant" width="520" />
</div>

<br />

<div align="center">
  <p><b>📅 统一沉浸式日程与待办弹窗 (Agenda & Tasks Popout View)</b></p>
  <img src="assets/screenshot.png" alt="Calendar Popout" width="520" />
</div>

---

## 🌟 核心特性 (Key Features)

### 🤖 1. 多模态 AI 智能排程助理 (AI Scheduling Assistant)
- **主流大模型生态全兼容**：原生适配 **OpenAI、DeepSeek（V3 / R1）、Claude、Google Gemini、Ollama** 及任意标准 OpenAI 协议端点；支持自定义 Base URL、API Key 与可用模型自由多选。
- **大模型即时并发测速**：在设置面板中一键并发测试所有配置模型的网络连通性与首字延迟 (Latency)，响应速度一目了然。
- **截图 OCR 视觉排程**：按下 `Ctrl+V` 或点击附件按钮一键提取剪贴板截图，AI 自动解析海报、课表、会议截图中的事件与待办，并结构化输出排程建议。
- **交互式排程建议卡片**：支持逐项勾选/反选建议日程与待办，一键批量落盘写入，**自动触发后端全量同步与两段式防漏刷新**。
- **弹性自适应多行输入框**：支持单行紧凑起步（38px），随输入内容或 `Shift+Enter` 弹性撑高（最高 130px 约 5~6 行），超出自动启用平滑纵向滚动，`Enter` 一键发送并平滑复位收缩为单行；深度适配 DMS 原生主题光标（`DankTextCursor`）。
- **ChatGPT 级历史提问回溯**：支持在输入框内使用 **`↑ / ↓` 方向键** 快速向上/向下滚动回溯历史 Prompt。
- **双轨桌面悬浮通知**：排程就绪或生成出错时，通过最高优先级 `ToastService` 在屏幕前台滑出高亮悬浮胶囊，并沉淀至系统通知中心。

---

### 📅 2. 沉浸式日程看板与会议助手 (Agenda Management)
- **顶栏恒宽空间预算算法 (Dynamic Budget Allocation)**：
  - 将设置中的胶囊宽度定义为全局像素预算，标题区域自适应扣除右侧动态倒计时（如 `1h`, `14h15m`）的宽度；
  - **彻底消除尺寸抖动**：无论倒计时字符长短、无论切换日程还是待办模式，顶栏胶囊在屏幕上的**总像素宽度 100% 绝对恒定**！
- **12 / 24 小时制自适应**：深度接入 DMS 系统时钟偏好设置（`SettingsData.use24HourClock` 与 `SettingsData.padHours12Hour`），自动根据系统偏好无缝切换 `14:30` 或 `02:30 PM` 显示格式。
- **在线会议智能嗅探与一键「加入」**：
  - 自动智能识别日程中的 **Zoom、Google Meet、Microsoft Teams、腾讯会议 (VooV Meeting)、飞书 (Feishu/Lark)** 等主流在线会议链接；
  - 在日程卡片右侧常驻渲染精致的高亮「加入」芯片按钮，键盘流亦可直接按 **`m` 键一秒直达视频会议**。
- **精准本地与 UTC 时区换算**：深度解决跨天与凌晨（00:00~08:00）日程的时区偏移 Bug，早间日程 0 漏查。
- **跨屏多显示器实时同步**：基于 `PluginGlobalVar`，主副屏之间实时无缝同步展开、收起、Tab 切换与刷新状态。
- **平滑跑马灯 (Marquee)**：超长事件标题在受限视口中自动无缝往复平滑滚动。

---

### ⚡ 3. 0ms 乐观并发待办清单 (Tasks Management)
- **0ms 极速乐观 UI (Optimistic Updates)**：勾选打勾、取消、删除、快速添加即时呈现，内置 FIFO 串行队列守护 SQLite 并发安全与数据一致性。
- **上下文智能标签继承 (Contextual Tag Inheritance)**：在特定分类标签视图下新建待办无需手动输入 `#标签`，系统自动继承当前选中分类并即刻呈现在列表中；智能排除虚拟「到期」聚合标签。
- **AI 智能整理分类与生命周期反馈**：一键调用大模型对未分类待办进行标签推理并批量回写，具备 GPU 加速平滑旋转动效与全局 Toast 状态通知。
- **RFC 5545 优先级系统**：支持 🔴 高优、🟡 中优、🔵 低优 状态标签，快速输入 `!1` / `!h`、`!2` / `!m`、`!3` / `!l` 即可快速标记优先级。
- **临期待办置顶与「到期」聚合筛选**：根据 Deadline 截止时间智能多级排序，即将到期的任务自动置顶呈现。
- **顶栏纯数字极简模式**：顶栏待办状态精简显示为 `[ ✓  7 • 任务标题... ]`，最大化释放空间展示具体任务文本。

---

### 🔔 4. 系统级原生通知体系与偏好管理 (System Notifications)
- **全面接入 Linux 桌面通知 (Freedesktop Notifications)**：通过 `dms notify` 与 `notify-send` 深度集成 Linux 原生通知守护进程，所有提醒与状态自动沉淀至 DMS 侧边通知中心（Notification Center），历史永久留存防遗漏。
- **4 种通知模式偏好自由切换**：
  - **双轨通知（默认推荐）**：兼顾屏幕前台 DMS Toast 悬浮胶囊即时滑出与原生通知中心历史留存；
  - **仅系统原生桌面通知**：无悬浮打扰，直接静默写入通知中心；
  - **仅 DMS Toast 悬浮胶囊**：前台轻量即时提示，不占用系统通知列表；
  - **完全关闭通知**：适合免打扰或游戏场景。
- **日程临期预警通知**：支持自定义提前预警时间（1~30 分钟），在日程即将开始前自动弹出桌面通知，标明倒计时、具体时间与会议地点，并提供智能去重机制。
- **待办到期自动通知**：待办到达截止时间自动汇总提醒，避免遗忘重要 Deadline。
- **一键测试连通性**：在设置页面内嵌“发送测试通知”卡片，并开放 IPC 接口支持随时检验系统通知链路。

---

### ⚙️ 5. 个性化设置与快捷键速查仪表盘 (Customization & Dashboard)
- **丰富的外观与行为调节**：支持自由调节胶囊最大宽度（40px ~ 400px）、切换显示模式（完整/仅倒计时/仅标题）、开启日程与待办定时轮播、自定义历史回溯天数与未来预览跨度。
- **全功能快捷键速查仪表盘 (Cheat Sheet Dashboard)**：设置页面内嵌卡片化操作速查指南，支持一键折叠展开，支持一键复制适用于 Niri / Hyprland 窗口管理器的全局快捷键唤起配置。

---

## 🕹️ 全键盘流与快捷操作指引 (Keyboard Shortcuts & Actions)

| 操作 (Action) | 快捷键 / 触发方式 | 效果说明 (Result) |
|---|---|---|
| **模式切换** | **左键点击顶栏胶囊图标** | 在 **日程模式** 与 **待办模式** 之间循环切换（所有监视器跨屏同步） |
| **打开 / 收起** | **左键点击顶栏胶囊主体** | 打开 / 收起 沉浸式浮动弹窗 (Popout) |
| **外部应用** | **中键点击顶栏胶囊** | 快速调出 DankCalendar 主应用程序窗口 |
| **底层全量同步**| **右键点击胶囊 / 点击 ↻** | 触发底层账户全量同步（`dcal ipc accounts.refresh`），带 360° GPU 旋转动效 |
| **快速新建事件**| **弹窗顶部 `+` 按钮** | 在 DankCalendar 中直接打开新建事件界面 |
| **Tab 快速直达** | **`1` / `2` / `3`** 或 `Ctrl+1 / 2 / 3` | 瞬时切换【日程】/【待办】/【助理】主页面 |
| **Tab 循环切换** | **`Ctrl + Tab` / `Ctrl + Shift + Tab`** | 顺时针 / 逆时针循环轮转切换各功能 Tab |
| **打开插件设置**| **弹窗 ⚙️ 按钮** | 打开插件设置并直达快捷键速查仪表盘 |
| **快速创建待办**| **待办输入框回车** | 快速创建待办（支持输入 `!1` 设为高优，当前分类标签下自动继承） |
| **聚焦新建待办**| **弹窗内 `Ctrl + N`** | 立即聚焦新建待办输入框 |
| **列表漫游** | **`j / k` 或 `↑ / ↓`** | 纯键盘上下浏览日程/待办（视口平滑跟随，待办支持 `Space` 打勾、`c` 复制、`d` 删除、`i / a / Enter` 回顶打字） |
| **秒进视频会议**| **按 `m` 键 / 点击「加入」** | 一键快速打开并加入当前选中日程关联的在线视频会议链接 |
| **回到今天** | **日程内 `t` 或 `Home`** | 视口平滑定位并选中【今天】即将发生的日程 |
| **即时刷新** | **弹窗内 `Ctrl + R`** | 即刻同步刷新日历与待办数据 |
| **关闭弹窗** | **`Esc`** | 快速收起关闭主弹窗 |
| **截图识图排程**| **AI 助理页面 `Ctrl + V`** | 自动提取并上传剪贴板图片/截图进行 AI 识图排程 |
| **AI 多行换行** | **AI 输入框 `Shift + Enter`** | 插入换行符并自适应撑高展开输入框 |
| **AI 发送 / 中断**| **AI 输入框 `Enter`** | 发送当前 Prompt（若正在生成中则直接中断请求）并平滑复位收缩为单行 |
| **AI 提问回溯** | **AI 输入框 `↑ / ↓`** | 快速向上/向下切换回溯历史输入的 Prompt 提示词 |

---

## 📡 外部控制与 IPC 接口 (IPC Integration)

本项目完整开放基于 `dms ipc` 的外部控制接口，可轻松绑定至任何 Wayland 合成器（如 Niri、Hyprland、Sway 等）：

```bash
# 打开插件设置页并查看快捷键仪表盘
dms ipc call dankCalendarPlus openSettings

# 发送一条当前通知模式的测试通知（用于验证通知链路）
dms ipc call dankCalendarPlus testNotification

# 强制触发日历与待办全量同步刷新
dms ipc call dankCalendarPlus refreshAll
```

### 🪟 Niri 快捷键配置示例 (`config.kdl`)
```kdl
binds {
    Mod+Alt+C { spawn "dms" "ipc" "call" "dankCalendarPlus" "openSettings"; }
}
```

### 🪟 Hyprland 快捷键配置示例 (`hyprland.conf`)
```conf
bind = $mainMod ALT, C, exec, dms ipc call dankCalendarPlus openSettings
```

---

## 📦 依赖与运行环境 (Requirements)

- **Linux / Wayland** (DankMaterialShell >= 1.6.0)
- **[dcal](https://github.com/AvengeMedia/dcal)** (DankCalendar 守护进程与 IPC 接口)
- **Python 3** (>= 3.9)
- **jq** (命令行 JSON 处理工具)
- **wl-clipboard** 或 **xclip** (用于剪贴板识图与一键复制功能)

---

## 📥 安装指南 (Installation)

### 方式一：DMS 插件管理器一键安装
在 DMS 设置 -> **插件管理 (Plugins)** 中搜索 `Dank Calendar Plus` 并点击安装。

### 方式二：Git 本地克隆安装
```bash
cd ~/.config/DankMaterialShell/plugins/
git clone https://github.com/luckjokerwang/dms-dankcalendar.git dankCalendarAgendaLocal

# 清除缓存并重启 DMS
rm -rf ~/.cache/DankMaterialShell ~/.cache/quickshell
dms restart
```

---

## 📄 开源许可 (License)

本项目采用 **GPL-3.0-or-later** 许可证发布。详见 [LICENSE](LICENSE) 文件。  
早期 Upstream 基础代码采用 MIT 许可证 © [Leonardo Amaro](https://github.com/leoamaro01) (详见 `LICENSE.upstream`)。

---

## 💖 项目渊源与致谢 (Credits & Acknowledgments)

- **本项目架构设计、全功能演进与维护**：[@luckjokerwang](https://github.com/luckjokerwang)
- **项目渊源与致谢**：本项目基于开源社区先驱项目 `dms-dankcalendar`（原作者 [Leonardo Amaro](https://github.com/leoamaro01) 与早期维护者 [arqueon](https://github.com/arqueon)）的基础代码架构深度重构演进而来，现已全面独立维护并发展为全功能多模态生产力工作台。
- **底层桌面环境支持**：感谢 [AvengeMedia / DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) 团队打造的优秀 Wayland 桌面框架与丰富生态！

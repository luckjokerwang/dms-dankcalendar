# Spec: Dank Calendar Plus AI 排程智能体 (AI Scheduling Agent)

## 1. 目标与范围 (Objective & Scope)
为 Linux 桌面环境（DankMaterialShell / Quickshell）打造一套高度原生、无缝集成的 AI 智能日历与待办助理插件。
核心解决用户从杂乱文本、截图或日常对话中，自动提取结构化排程，并以 **Human-in-the-Loop（交互式确认卡片）** 的机制安全、可靠地写入底层系统服务 `dcal`。

### 1.1 用户故事 (User Stories)
- **自然语言与多模态排程**：用户发送一句话（如“明天下午2点午休半小时”）或一张包含日程的截图，AI 自动完成时间解析、分类拆解（Event vs Task），并给出精美确认卡片。
- **原子化批量写入**：用户核对或微调后，点击“一键确认添加”，系统在 20ms 内通过 IPC 将事件与任务安全落盘至 Google Calendar / 本地日历。
- **纯键盘高效操作**：输入 `/` 触发快捷指令菜单，支持 `↑`/`↓` 选择、`Enter`/`Tab` 执行；支持 `Ctrl+N` 新建会话、`Ctrl+H` 查看历史、`Ctrl+V` 粘贴截图。
- **多模型配置与安全隔离**：支持 Agnes AI、DeepSeek、OpenAI、Gemini、Ollama 等主流厂商，支持一键测通并拉取模型列表；API Key 严格保存在本地，绝不上云或进入 Git。

---

## 2. 技术栈与依赖 (Tech Stack & Dependencies)

| 组件类别 | 技术选型 | 版本/规范 | 用途 |
|---|---|---|---|
| 前端框架 | Qt 6 / Quickshell (QML) | Qt 6.8+ / DMS v2 | 顶栏挂件、弹窗面板、交互卡片、快捷键监听 |
| 设计语言 | Material Design 3 (DMS Theme) | DMS 原生 Tokens | 颜色、圆角（`cornerRadius`）、间距、字体规范 |
| 后端客户端 | Python 3 + `urllib.request` + `ssl` | Python 3.10+ | OpenAI 兼容 SSE 流式客户端、多模态 Base64 编码、Token 剪裁 |
| 日历底层 | `dcal` IPC CLI | dcal v0.1+ | 桌面日历与待办底层守护进程与数据同步引擎 |
| 跨平台工具 | `wl-clipboard` (`wl-paste`), `zenity` | Linux Wayland 标准 | 剪贴板图片获取、原生文件选择对话框 |

---

## 3. 可执行命令与接口契约 (Commands & Data Contracts)

### 3.1 项目执行与验证命令
```bash
# 1. 语法与类型静态检查
qmllint DankCalendarWidget.qml DankCalendarSettings.qml components/TasksView.qml components/ai/*.qml

# 2. DMS 守护进程重启与日志追踪
dms restart && qs -p /usr/share/quickshell/dms log | grep -E "dankCalendarPlus|error"

# 3. 后端服务单点测试
./ai-client test "https://apihub.agnes-ai.com/v1" "sk-YOUR_KEY"
./batch-create-items '{"events":[{"title":"测试会议","start":"2026-08-26T10:00:00+08:00","end":"2026-08-26T11:00:00+08:00"}],"tasks":[{"summary":"准备材料","due":"2026-08-26"}]}'
./session-manager list

# 4. 全局 IPC 唤醒测试
qs -p /usr/share/quickshell/dms ipc call dankCalendarPlus toggleAI
```

### 3.2 AI 输出与提案卡片契约 (Proposal JSON Schema)
AI 回复中必须包含以下格式的代码块：
```json:schedule
{
  "explanation": "排程简要说明",
  "events": [
    {
      "title": "会议/日程标题",
      "start": "YYYY-MM-DDTHH:MM:SS",
      "end": "YYYY-MM-DDTHH:MM:SS",
      "calendarName": "可选日历名称",
      "allDay": false
    }
  ],
  "tasks": [
    {
      "summary": "任务标题",
      "due": "YYYY-MM-DD",
      "priority": 1,
      "calendarName": "可选待办清单名称"
    }
  ]
}
```

### 3.3 `batch-create-items` 写入契约与时区强约束
- **时区要求**：必须保证 `start` 和 `end` 满足带时区偏移的 RFC3339 格式（如 `+08:00`）。若缺少时区，脚本自动探测系统本地时区并补齐；
- **参数映射**：
  - Event: `dcal ipc events.create calendarId=<id> summary=<title> start=<RFC3339> end=<RFC3339>`
  - Task: `dcal ipc tasks.create calendarId=<id> summary=<summary> due=<RFC3339> priority=<0-9>`
- **日期强对齐**：Task 的 `due` 截止日期必须严格与 Event 发生日期一致，禁止将明天的任务 Due 写成今天。

---

## 4. UI 架构与设计规范 (UI Architecture & Design System)

### 4.1 圆角与尺寸规范 (Corner Radii & Sizing)
全面对齐 DMS Material 3 统一规范，坚决杜绝生硬矩形与过大药丸：
- **卡片与容器**：`radius: Theme.cornerRadius` (12px)
- **列表项与输入框**：`radius: Theme.cornerRadiusSmall` (8px)
- **操作按钮与标签**：`radius: Theme.cornerRadiusSmall` (8px)
- **复选框 (Checkbox)**：`radius: 4` (平滑微圆角方形)

### 4.2 布局层级规范
- **PopoutContent 顶部**：日期 Header (48px)
- **Tab 切换栏**：`[ 📅 日程 ] [ ✓ 待办 ] [ 🤖 助理 ]` (34px，与下方内容保持 `Theme.spacingS` 间距，严禁重叠)
- **ChatView 主体**：
  - 会话 Sub-Header (34px，展示历史入口、当前会话名、模型 Badge、新建按钮)
  - 消息流式列表 (自适应高度，带自动滚动)
  - 输入控制区 (附件胶囊 + 📎 按钮 + 输入框 + 发送/终止按钮)
  - 斜杠指令浮窗 (位于输入框正上方，带 1px outlineVariant 边框)

### 4.3 键盘交互状态机
| 按键 | 场景 | 行为 |
|---|---|---|
| `↑` / `↓` | `/` 指令弹窗显示时 | 切换选中的指令索引 `selectedSlashIndex` |
| `Enter` / `Tab` | `/` 指令弹窗显示时 | 执行/补全当前选中的指令，清空输入框 |
| `Enter` | 正常输入时 | 发送当前消息（若生成中则触发中止） |
| `Shift + Enter` | 正常输入时 | 换行输入 |
| `Ctrl + N` | 任何时候 | 初始化全新会话 |
| `Ctrl + H` | 任何时候 | 打开/折叠历史会话抽屉 |
| `Ctrl + V` | 输入框中 | 智能粘贴：若剪贴板为图片或文件则生成附件胶囊，若为纯文本则正常粘贴文字 |
| `Esc` | 指令弹窗/抽屉/生成中 | 关闭弹窗 / 收起抽屉 / 中止生成 |

---

## 5. 三层工程边界 (Boundaries)

- **Always (必须做到)**:
  - 每次代码变更必须通过 `qmllint` 检查（0 Errors）；
  - 保持所有密钥配置保存在本地未跟踪文件，Git 提交默认值为空；
  - 每一个 Bug 修复必须单点验证并保留测试证据；
  - 遵循用户全局 Git 规则（中文 Commit、先拉取后提交、在 `dev` 分支开发）。
- **Ask First (需先询问确认)**:
  - 更改底层日历或待办数据存储结构；
  - 引入需要 `cargo` 或系统级原生编译的大型外部二进制依赖。
- **Never (绝对禁止)**:
  - 禁止跳过切片测试直接一次性大批量修改多个文件；
  - 禁止在 Git 追踪的文件中硬编码任何真实 API 密钥；
  - 禁止静默吞掉报错或不做边界判断导致 QML 加载崩溃。

---

## 6. 验收标准 (Definition of Done)
1. [x] **底层落盘**：`batch-create-items` 能够在 20ms 内成功创建事件与任务，无 RFC3339 或参数名报错；
2. [x] **设置中心**：DMS Settings 中点击 Dank Calendar Plus 能平滑展开与折叠，支持一键测试拉取模型；
3. [x] **历史记录**：展开抽屉能秒级展示历史会话列表，点击可切换，支持清空；
4. [x] **键盘流操作**：输入 `/` 支持 `↑`/`↓`/`Enter`/`Tab` 全键盘无割裂操作；
5. [x] **UI 一致性**：移除突兀大胶囊，全界面统一为 DMS 标准 `Theme.cornerRadiusSmall`，无任何层叠穿透。

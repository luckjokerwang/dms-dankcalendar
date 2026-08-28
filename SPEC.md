# Spec: Dank Calendar Plus (v3.0) 架构重构与模块化升级规范

## 1. 目标与愿景 (Objective)

### 1.1 背景与痛点
Dank Calendar Plus 目前集成了日历日程（Agenda）、任务待办（Tasks）以及基于 LLM 的智能排程助手（AI Agent）。随着功能的快速迭代，项目累积了以下严重的架构债务：
1. **上帝组件（God Objects）**：`DankCalendarWidget.qml`（1700+ 行）和 `ChatView.qml`（1600+ 行）承载了过多视图、动画、状态机与底层进程调用。
2. **状态碎片化与双向强耦合**：子组件直接穿透读写父组件私有变量，导致修改任一模块极易引发意外回归。
3. **后端碎片化**：存在 8 个分散的独立脚本，缺少统一的数据输出契约（Schema）与静态类型校验。
4. **大量重复代码**：聊天视图与设置视图各自维护了近 200 行高度相似的服务商配置与连通性测试逻辑。

### 1.2 重构目标
- **视图层 (QML)**：采用标准的 **MVVM (Model-View-ViewModel / Store) 架构**。将数据拉取、缓存、乐观更新队列抽离到独立的 `store/`，视图组件仅负责纯 UI 渲染与用户交互，单文件代码量控制在 150~300 行以内。
- **核心层 (Backend)**：整合为**单一入口的 Python 3 核心引擎 (`dms-calendar-core`)**，采用严格的 Python `typing` 类型注解与统一的 JSON 通信协议，消除冷启动冗余与进程管理混乱。
- **组件复用**：抽象通用的模态弹窗（如 `ProviderConfigModal.qml`）、通用输入框、消息列表等，彻底消除重复逻辑。
- **杜绝硬编码**：集中管理常量枚举（优先级、状态码、模块枚举、默认尺寸与配置）。

---

## 2. 技术栈与环境依赖 (Tech Stack)

| 层级 | 选型 | 版本/规范 | 作用与约束 |
| :--- | :--- | :--- | :--- |
| **前端视图层** | QML (QtQuick 6 / Quickshell) | Qt 6.x | 纯声明式 UI，遵从 MVVM 单向数据流 |
| **前端通信** | Quickshell `Process` + `SplitParser` | Quickshell v0.0.x | 异步子进程拉取与 SSE 字符流解析 |
| **后端核心层** | Python 3 + `typing` + `argparse` | Python >= 3.8 | 统一 CLI 单入口，标准库实现（零外部 pip 依赖） |
| **底层服务** | `dcal` (CLI / IPC) | dcal >= 0.2.2 | 本地日历与待办存储引擎 |
| **静态分析** | `mypy` / `pyflakes` / `qmlformat` | 最新标准 | 后端强类型检查与代码风格统一 |

---

## 3. 标准命令集 (Commands)

```bash
# 1. 运行后端全量类型检查 (Type Check)
mypy --strict core/

# 2. 运行自动化集成测试套件 (Unit & Integration Tests)
bash tests/test-backend-services.sh

# 3. 清理 QML 缓存并平滑重启 DMS 桌面环境 (Reload)
rm -rf ~/.cache/DankMaterialShell ~/.cache/quickshell && dms restart

# 4. 单独调试核心后端 CLI 子命令 (CLI Verification)
./core/dms-calendar-core agenda get --past 7 --future 30
./core/dms-calendar-core tasks list
./core/dms-calendar-core provider list
```

---

## 4. 重构后项目文件目录规范 (Project Structure)

```
dankCalendarAgendaLocal/
├── plugin.json                       # 插件元信息与权限声明
├── CLAUDE.md                         # 开发指令与快速参考
├── SPEC.md                           # 本架构规范文件 (Living Document)
├── DankCalendarWidget.qml            # 精简后的顶层入口 (仅保留外壳容器与胶囊栏装配，~250行)
├── DankCalendarSettings.qml          # 精简后的设置页 (~300行)
│
├── core/                             # 【后端统一核心库 (Python 3 强类型)】
│   ├── dms-calendar-core             # 统一单入口可执行 CLI (提供 agenda/tasks/ai/provider/session/paste)
│   └── lib/
│       ├── __init__.py
│       ├── types.py                  # 强类型定义 (TypedDict, Dataclasses, Enums)
│       ├── dcal_client.py            # dcal IPC 统一封装与错误熔断
│       ├── agenda_service.py         # 日程聚合、本地/UTC日期对齐算法
│       ├── task_service.py           # 任务过滤、优先级权重排序、批量操作
│       ├── ai_service.py             # OpenAI 兼容 SSE 流式客户端与排程提示词
│       ├── provider_service.py       # 多服务商配置管理、动态拉取 /v1/models、延迟测速
│       └── session_service.py        # 会话落盘持久化、智能标题提炼
│
├── store/                            # 【QML 状态管理中心 (Store / ViewModels)】
│   ├── DankCalendarConstants.qml     # 全局常量、枚举、尺寸规范定义
│   ├── CalendarStore.qml             # 日程数据源、倒计时与自动刷新定时器
│   ├── TaskStore.qml                 # 待办数据源、乐观更新管理与回滚队列
│   ├── AiStore.qml                   # AI 对话状态、SSE 流式接收器与提案解析
│   └── ProviderStore.qml             # 统一服务商模型状态、测速状态与配置读写
│
├── components/                       # 【UI 表现层组件 (单一职责，小颗粒度)】
│   ├── pills/                        # 顶栏胶囊栏模块
│   │   ├── HorizontalBarPill.qml     # 水平顶栏胶囊
│   │   └── VerticalBarPill.qml       # 垂直顶栏胶囊
│   ├── common/                       # 通用复用组件
│   │   ├── ProviderConfigModal.qml   # 共享服务商添加/编辑/测速弹窗 (设置页与聊天页共用)
│   │   ├── ModelPickerMenu.qml       # 模型下拉切换菜单
│   │   ├── DankPriorityTag.qml       # 优先级小圆点/徽章
│   │   └── DankActionIconButton.qml  # 统一风格的图标按钮
│   ├── popout/                       # 弹窗公共框架
│   │   ├── PopoutHeader.qml          # 顶部标题栏与动态副标题
│   │   └── PopoutTabBar.qml          # 日程 / 待办 / 助理 三段式 Tab 切换栏
│   ├── agenda/                       # 日程视图模块
│   │   ├── AgendaView.qml            # 日程主容器
│   │   └── AgendaRowDelegate.qml     # 单个日程/日期组渲染项
│   ├── tasks/                        # 待办视图模块
│   │   ├── TasksView.qml             # 待办主容器
│   │   ├── TaskQuickAddInput.qml     # 快速输入栏 (含优先级 !1 智能解析)
│   │   └── TaskRowDelegate.qml       # 待办列表项 (含完成动画与删除)
│   └── ai/                           # AI 对话视图模块
│       ├── ChatView.qml              # AI 主容器 (仅保留视口布局，~200行)
│       ├── MessageListView.qml       # 消息滚动列表与打字机气泡
│       ├── ChatInputBar.qml          # 仿 ChatGPT 多行输入框、截图粘贴与附件栏
│       ├── CommandPalette.qml        # 快捷斜杠指令 (/today, /plan 等)
│       ├── ScheduleProposalCard.qml  # 智能排程提案卡片与批量确认
│       └── SessionDrawer.qml         # 会话历史侧边栏抽屉
│
└── tests/                            # 【自动化测试套件】
    ├── test-backend-services.sh      # 后端核心业务集成回归测试
    └── test-type-checks.sh           # 后端接口契约与静态类型校验
```

---

## 5. 统一数据契约与接口规范 (Unified Data Contracts)

### 5.1 后端统一响应封包 (Standard JSON Envelope)
所有 `dms-calendar-core <subcommand>` 的输出均严格遵循统一 JSON 结构，杜绝字段缺失导致的运行时异常：

```json
{
  "status": "ok",           // "ok" | "error"
  "code": 200,              // 标准业务状态码
  "data": { ... },          // 实际业务负载 payload
  "error": {                // 当 status 为 "error" 时提供
    "code": "CALENDAR_SYNC_FAILED",
    "message": "无法连接到 dcal 服务，请检查后台守护进程",
    "details": "Connection refused on socket"
  },
  "timestamp": 1787843622
}
```

### 5.2 核心强类型定义 (Python `core/lib/types.py`)

```python
from typing import TypedDict, List, Optional, Literal, Dict, Any

class TaskItem(TypedDict):
    id: str
    summary: str
    calendarId: str
    calendarName: str
    status: Literal["needs_action", "completed"]
    percentComplete: int
    priority: int  # 0: 无, 1: 高 (!1), 5: 中 (!2), 9: 低 (!3)
    due: Optional[str]

class EventItem(TypedDict):
    id: str
    summary: str
    start: str
    end: str
    allDay: bool
    location: str
    description: str
    meetingUrl: str
    url: str
    recurringId: Optional[str]

class ScheduleProposal(TypedDict):
    title: str
    explanation: str
    events: List[Dict[str, Any]]
    tasks: List[Dict[str, Any]]
    confirmed: bool

class ProviderConfig(TypedDict):
    id: str
    name: str
    baseUrl: str
    apiKey: str
    enabled: bool
    icon: str
    color: str
    models: List[Dict[str, str]]
```

---

## 6. 前端 MVVM 单向数据流架构规范

```
 用户交互 (点击/输入)
       │
       ▼
 ┌──────────────┐          调用 Actions          ┌───────────────────┐
 │ UI View 组件  │ ────────────────────────────> │  Store / ViewModel│
 │ (AgendaView) │                                │  (CalendarStore)  │
 └──────────────┘                                └─────────┬─────────┘
       ▲                                                   │ 驱动子进程
       │               状态变更通知 (Signals/Bindings)      ▼
       └───────────────────────────────────────── ┌───────────────────┐
                                                  │ dms-calendar-core │
                                                  │ (Python Backend)  │
                                                  └───────────────────┘
```

### 6.1 各 Store 职责划分
1. **`CalendarStore.qml`**：
   - 管理 `agendaEvents`、`agendaModel`、`nextEvent`、`isLoading`。
   - 提供 `refreshAgenda()`、`deleteEvent(id)`。
   - 维护倒计时时钟与每分钟 tick 更新。
2. **`TaskStore.qml`**：
   - 管理 `pendingTasks`、`completedTasks`、`taskCalendars`、`optimisticActionQueue`。
   - 提供 `createTask(summary, calId)`、`completeTask(id, done)`、`deleteTask(id)`。
   - 内置**乐观更新回滚策略**：在任务执行失败时自动拉取最新真实数据重置 UI。
3. **`AiStore.qml`**：
   - 管理 `messages`、`currentSessionId`、`isGenerating`、`streamingText`、`activeProposal`。
   - 提供 `sendMessage(prompt, imagePath)`、`stopGeneration()`、`confirmProposal(prop)`。
4. **`ProviderStore.qml`**：
   - 统一从 `~/.config/dms-ai/providers.json` 加载配置。
   - 提供 `saveProvider(prov)`、`testProvider(prov)`、`fetchModels(provId)`。
   - `DankCalendarSettings.qml` 与 `ChatView.qml` 共用此 Store，消灭双重状态维护。

---

## 7. 编码规范与边界准则 (Boundaries & Code Style)

### 7.1 必须遵循 (Always Do)
- **Props Down, Events Up**：子组件只通过属性接收数据，通过 `signal` 向上层通知事件，严禁子组件反向读取 `parent.parent.rootWidget`。
- **文件体积控制**：单个 QML 文件行数严格控制在 300 行以内，超过 300 行必须寻找子职责进行组件提取。
- **类型显式声明**：QML 属性避免使用宽泛的 `property var`，明确使用 `property string`、`property int`、`property bool` 或强结构。
- **统一常量字典**：所有魔数（如超时时间 3000ms、默认弹窗尺寸 440x560、优先级常量 1/5/9）必须引用 `DankCalendarConstants`。

### 7.2 严格禁止 (Never Do)
- **严禁直接在 UI 组件内拼接命令行**：所有命令必须经过 Store 与参数化数组传递，防止参数解析错误与注入风险。
- **严禁复制粘贴模态框/服务商测试逻辑**：弹窗必须使用抽象后的 `ProviderConfigModal.qml`。
- **严禁使用未捕获的裸异常**：所有后端接口必须返回格式化 JSON，前端解析必须包含 `try...catch` 降级保护。

---

## 8. 实施与分阶段落地计划 (Phased Implementation Plan)

```
PHASE 1: 后端核心库收敛 (Python Core Consolidation)
   ├── 构建 core/ 目录与 lib/types.py
   ├── 整合 8 个脚本为单一入口 dms-calendar-core
   └── 补充完整自动化测试与类型检查覆盖

PHASE 2: 前端状态中心抽象 (QML Store Layer)
   ├── 建立 DankCalendarConstants.qml
   ├── 抽象 CalendarStore.qml 与 TaskStore.qml
   └── 抽象 ProviderStore.qml 与 AiStore.qml

PHASE 3: UI 表现层细粒度组件拆解 (Component Decomposition)
   ├── 拆解 DankCalendarWidget.qml (剥离胶囊栏与弹窗头)
   ├── 拆解 ChatView.qml (分离消息列表、输入区域与抽屉)
   └── 提炼共享组件 ProviderConfigModal.qml 并替换设置页与聊天页

PHASE 4: 全链路联调与验证 (System Integration & Verification)
   ├── 验证顶栏日程/待办双向切换与助理独立性
   ├── 验证 AI 排程流式输出与提案批量落盘
   └── 验证多服务商动态模型拉取与快捷切换
```

---

## 9. 验收标准 (Success Criteria)

1. **代码量健康度**：
   - `DankCalendarWidget.qml` 代码量从 1700+ 行压缩至 300 行以内。
   - `ChatView.qml` 代码量从 1600+ 行压缩至 250 行以内。
   - 单个 QML 文件平均代码行数 <= 200 行。
2. **架构指标**：
   - 后端脚本数量由 8 个收敛为 1 个统一 CLI（含子命令），通过 `mypy --strict` 静态类型检查。
   - 彻底消除 `ChatView` 与 `Settings` 之间的服务商配置重复代码。
3. **功能与稳定性指标**：
   - 顶栏与弹窗联动行为符合预期（顶栏仅在日程/待办切换，助理模式不影响顶栏）。
   - 任务创建、完成、删除乐观更新 100% 具备失败回滚能力。
   - 所有测试用例 `tests/test-backend-services.sh` 100% 通过。

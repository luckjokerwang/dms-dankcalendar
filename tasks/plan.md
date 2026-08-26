# Plan: Dank Calendar Plus AI 排程智能体实施规划

## 1. 架构分解与依赖图谱 (Architecture Decomposition)

```
                       ┌─────────────────────────┐
                       │  DankCalendarWidget.qml │ (顶栏挂件 & 弹窗控制器)
                       └───────────┬─────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
 ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
 │  AgendaView  │          │  TasksView   │          │   ChatView   │ (AI 交互核心)
 └──────────────┘          └──────────────┘          └───────┬──────┘
                                                             │
                                   ┌─────────────────────────┴─────────────────────────┐
                                   ▼                                                   ▼
                       ┌─────────────────────────┐                         ┌─────────────────────────┐
                       │  ScheduleProposalCard   │ (确认卡片)               │      SessionDrawer      │ (历史抽屉)
                       └───────────┬─────────────┘                         └───────────┬─────────────┘
                                   │                                                   │
                                   ▼                                                   ▼
                       ┌─────────────────────────┐                         ┌─────────────────────────┐
                       │   batch-create-items    │                         │     session-manager     │
                       └───────────┬─────────────┘                         └─────────────────────────┘
                                   │
                                   ▼
                       ┌─────────────────────────┐
                       │    dcal (IPC Daemon)    │
                       └─────────────────────────┘
```

## 2. 垂直切片与实现顺序 (Vertical Slices)

| 阶段 | 切片名称 | 涉及文件 | 风险级别 | 应对策略 |
|---|---|---|---|---|
| **Slice 1** | 底层日历/待办写入契约 | `batch-create-items` | 极高 (时间/参数兼容) | 自动注入本地时区偏移，严格映射 `summary`/`calendarId` |
| **Slice 2** | 设置中心与模型拉取 | `DankCalendarSettings.qml`, `ai-client` | 中 | 采用官方 `PluginSettings`，增加连接测试 CLI |
| **Slice 3** | 会话持久化与抽屉 | `session-manager`, `SessionDrawer.qml` | 低 | 统一 `data/sessions` 存储，增加展开事件自动刷新 |
| **Slice 4** | 聊天交互与纯键盘流 | `ChatView.qml` | 中 (焦点状态机) | 捕获 `Key_Up`/`Key_Down`/`Key_Return`/`Key_Tab` |
| **Slice 5** | 卡片确认与 UI 规范 | `ScheduleProposalCard.qml`, `Theme` | 中 (视觉一致性) | 统一 `Theme.cornerRadiusSmall`，优化反馈提示 |
| **Slice 6** | 全局 IPC 快捷键协议 | `DankCalendarWidget.qml` | 低 | 注册 `IpcHandler { target: "dankCalendarPlus" }` |

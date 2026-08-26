# Tasks: Dank Calendar Plus AI 排程智能体 7 项缺陷修复清单

- [ ] **Task 1: 直接粘贴图片与文件 (对齐主流 LLM 对话框体验，支持直接发送)**
  - **Issue**: 无法直接按 Ctrl+V 粘贴剪贴板中的纯图片数据，且存在发送拦截；
  - **DoD**: 按 Ctrl+V、点击“📋 粘贴截图”或拖拽图片/文件，自动提取为 64x64 真实缩略图/文件卡片，无需输入额外文字即可一键点击发送并交给 AI 解析。
  - **Files**: `clipboard-paste-helper`, `components/ai/ChatView.qml`

- [ ] **Task 2: 全局 UI 质感与圆角风格一致性优化**
  - **Issue**: 部分元素圆角不协调，排版有局促感；
  - **DoD**: 统一采用 Material 3 标准小圆角 (`Theme.cornerRadiusSmall` / `Theme.cornerRadius` ~12px)，优化内边距与留白。
  - **Files**: `components/ai/ChatView.qml`, `components/ai/ScheduleProposalCard.qml`

- [ ] **Task 3: 会话历史抽屉数据即时呈现与切换 (图二)**
  - **Issue**: 抽屉打开时显示“暂无历史会话”；
  - **DoD**: 展开抽屉瞬间完整列出所有历史会话（带标题、修改时间、消息数），点击秒级切换并载入上下文。
  - **Files**: `components/ai/SessionDrawer.qml`, `session-manager`

- [ ] **Task 4: `/` 指令初次触发字体黑色与高亮修复 (图三、四)**
  - **Issue**: 初次键入 `/` 时第一个条目字体为黑色，暗色背景下看不清；
  - **DoD**: 初次弹出及键盘上下切换时，选中的指令文字与图标 100% 保持高对比度纯白亮色。
  - **Files**: `components/ai/ChatView.qml`

- [ ] **Task 5: 文件上传 (📎) 修复 (解决弹窗收起且无法挂载问题)**
  - **Issue**: 点击 📎 唤起外部选择器导致助理弹窗被强制收起，文件无法上传；
  - **DoD**: 集成 DMS 原生 `FileBrowserSurfaceModal`（支持 `keepPopoutsOpen: true`），弹窗常驻不关闭，选定文件后自动挂载附件。
  - **Files**: `components/ai/ChatView.qml`, `DankCalendarWidget.qml`

- [ ] **Task 6: 待办截止时间少一天修复 (图五 UTC 时区转换 Bug)**
  - **Issue**: 26 号任务写入后在待办中显示为 8月25日；
  - **DoD**: 将无具体时分的 Task 截止时间对齐为当日 `23:59:59+08:00`，彻底消除 UTC 跨天偏移。
  - **Files**: `batch-create-items`

- [ ] **Task 7: 设置中心打不开修复 (图四 DMS 官方组件重构)**
  - **Issue**: DMS 设置中心展开 Dank Calendar Plus 时无法呈现；
  - **DoD**: 移除私有 Category 组件，全面重构为 DMS 原生 `PluginSettings` 标准设置项与模型测试容器。
  - **Files**: `DankCalendarSettings.qml`

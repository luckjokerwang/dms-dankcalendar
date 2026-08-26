# Tasks: Dank Calendar Plus AI 排程智能体 7 项缺陷修复清单

- [x] **Task 1: 直接粘贴图片与文件 (对齐主流 LLM 对话框体验，支持直接发送)**
  - **Status**: ✅ 已完成 (Verified by User & Local Test)
  - **Details**: 编写底层 `clipboard-paste-helper`，通过 Wayland 协议层直接捕获截图像素并转为 64x64 缩略图预览卡片；支持无文字直接点击发送。
  - **Files**: `clipboard-paste-helper`, `components/ai/ChatView.qml`

- [x] **Task 2: 全局 UI 质感与会话导航栏等宽美化**
  - **Status**: ✅ 已完成 (Verified)
  - **Details**: 将会话顶部导航栏调整为与“助理”容器及顶层选项卡 100% 等宽；重构为 Material 3 大圆角卡片、精致模型药丸与操作图标，消除多余内边距与视觉断层。
  - **Files**: `components/ai/ChatView.qml`

- [x] **Task 3: 会话历史抽屉数据即时呈现与切换 (图二)**
  - **Status**: ✅ 已完成 (Verified)
  - **Details**: 使用 `SplitParser` 流式解析 `./session-manager list`，展开抽屉瞬间完整呈现 9 个真实历史会话，支持秒级切换与会话载入。
  - **Files**: `components/ai/SessionDrawer.qml`, `session-manager`

- [x] **Task 4: `/` 指令初次触发字体黑色与高亮修复 (图三、四)**
  - **Status**: ✅ 已完成 (Verified)
  - **Details**: 选中的指令文字与图标 100% 保持高对比度纯白亮色（`#ffffff`），消除暗色主题下的深色计算问题。
  - **Files**: `components/ai/ChatView.qml`

- [x] **Task 5: 文件上传 (📎) 修复 (解决弹窗收起且无法挂载问题)**
  - **Status**: ✅ 已完成 (Verified by User)
  - **Details**: 集成 DMS 原生 `FileBrowserSurfaceModal`（支持 `keepPopoutsOpen: true`），内置图层弹窗绝不收起日历窗口。
  - **Files**: `components/ai/ChatView.qml`

- [x] **Task 6: 待办截止时间少一天修复 (图五 UTC 时区转换 Bug)**
  - **Status**: ✅ 已完成 (Verified)
  - **Details**: 将无具体时分的 Task 截止时间统一对齐为当日 `23:59:59+08:00`，实测 26 号任务在系统待办列表精确显示为 8月26日。
  - **Files**: `batch-create-items`

- [x] **Task 7: 设置中心打不开修复 (图四 DMS 官方组件重构)**
  - **Status**: ✅ 已完成 (Verified)
  - **Details**: 全面重构为 DMS 原生 `PluginSettings` 标准设置项（`SelectionSetting`, `ToggleSetting`, `SliderSetting` + 模型测试容器），秒级展开。
  - **Files**: `DankCalendarSettings.qml`

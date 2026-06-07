# Mac 一键开关工具 —— 完整项目设计方案

## 项目概述

这是一个运行在 macOS 菜单栏（Menu Bar）中的原生应用，用户点击右上角图标后弹出一个面板，面板中展示一系列系统功能的开关。用户可以自由勾选显示哪些开关、拖拽调整顺序。整个应用轻量、无主窗口、常驻后台。

---

## 技术栈

- **语言**：Swift
- **UI 框架**：SwiftUI（面板 UI） + AppKit（Menu Bar 宿主）
- **系统框架**：根据功能按需引入（CoreAudio、IOKit、IOBluetooth、ScreenSaver 等）
- **包管理**：Swift Package Manager
- **图标系统**：SF Symbols
- **持久化**：UserDefaults
- **分发方式**：直接分发 .dmg，不上 App Store（避免沙盒限制）
- **最低系统要求**：macOS 13 Ventura

---

## 核心架构设计

整个项目最重要的设计是一个叫做 `ToggleProvider` 的协议（Protocol）。每一个系统功能开关都是这个协议的一个具体实现。这样设计的好处是：添加新功能只需新建一个文件实现协议，完全不需要修改已有代码，扩展性极强。

```swift
protocol ToggleProvider: Identifiable, ObservableObject {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }   // 比如 AirPods 显示电量
    var iconName: String { get }    // SF Symbols 图标名
    var isOn: Bool { get set }
    func apply(newValue: Bool)      // 执行实际的系统操作
}
```

所有开关统一由一个 `ToggleRegistry` 管理，负责：
- 维护所有可用开关的列表
- 记录每个开关是否启用显示
- 记录开关的排列顺序
- 将状态持久化到 UserDefaults

---

## 目录结构

```
MenuBarToggles/
├── App/
│   ├── MenuBarTogglesApp.swift       # 应用入口，AppDelegate
│   └── AppDelegate.swift             # 创建 NSStatusItem，管理 Popover
├── UI/
│   ├── PopoverView.swift             # 主面板 SwiftUI 视图
│   ├── ToggleRowView.swift           # 单个开关行的视图
│   └── SettingsView.swift            # 设置面板（管理开关显示和排序）
├── Toggles/
│   ├── ToggleProvider.swift          # 协议定义
│   ├── ToggleRegistry.swift          # 注册中心
│   ├── HideDesktopToggle.swift       # 隐藏桌面
│   ├── DarkModeToggle.swift          # 深色模式
│   ├── KeepAwakeToggle.swift         # 保持亮屏
│   ├── MicMuteToggle.swift           # 麦克风静音
│   ├── ScreenSaverToggle.swift       # 屏幕保护程序
│   └── DoNotDisturbToggle.swift      # 勿扰模式
└── Utilities/
    └── ShellHelper.swift             # 执行 shell 命令的工具函数
```

---

## 第一版功能范围（MVP）

第一版只实现以下功能，保持简单，跑通整体架构：

| 功能 | 实现方式 |
|------|---------|
| 隐藏桌面图标 | `defaults write com.apple.finder` + `killall Finder` |
| 深色模式切换 | `NSAppearance` 或 AppleScript |
| 保持亮屏 | `IOKit` 的 `IOPMAssertionCreateWithName` |
| 屏幕保护程序 | 启动 `ScreenSaverEngine` 进程 |

UI 上第一版只做：
- 菜单栏图标点击弹出面板
- 面板中展示开关列表，支持点击切换
- 点击底部「设置」按钮打开设置面板
- 设置面板中可以勾选开关、拖拽排序

---

## 开发执行路径

### 第一步：搭建项目骨架

创建一个 macOS App 项目，在 Info.plist 中设置 `Application is agent (UIElement) = YES`，让应用不出现在 Dock 和 App Switcher 中。在 `AppDelegate` 中创建 `NSStatusItem`，绑定点击事件弹出 `NSPopover`。此时运行应用，菜单栏应该出现一个图标，点击弹出空白面板。

### 第二步：实现 ToggleProvider 协议和 Registry

写好协议定义和 `ToggleRegistry`，让 Registry 能够从 UserDefaults 读写开关的启用状态和顺序。此时不需要任何真实功能，可以先用模拟数据（mock）填充。

### 第三步：实现基础 UI

用 SwiftUI 写 `PopoverView` 和 `ToggleRowView`，从 Registry 读取数据并展示开关列表。每行显示图标、标题、右侧的 Toggle 控件。实现 `SettingsView`，支持 `List` 的 `onMove` 拖拽排序和 `onDelete` 或勾选框控制显示。

### 第四步：逐个实现真实功能

按照从简单到复杂的顺序实现每个 `ToggleProvider`：

1. **深色模式**（最简单，一行 AppleScript 即可）
2. **保持亮屏**（IOKit API 固定用法，网上示例多）
3. **隐藏桌面**（Shell 命令）
4. **屏幕保护程序**（启动进程）

每实现一个，立刻集成进 Registry 测试，不要攒到一起。

### 第五步：细节打磨

- 应用登录时自动启动（使用 `SMAppService.mainApp.register()`）
- 开关状态在系统变更时能实时同步（比如系统层面关闭了深色模式，面板里的开关也要更新）
- Popover 点击外部自动关闭
- 图标在深色/浅色菜单栏下都清晰可见（使用 Template Image）

---

## 扩展性约定

后续每新增一个功能开关，只需要：

1. 在 `Toggles/` 目录下新建一个 Swift 文件
2. 实现 `ToggleProvider` 协议
3. 在 `ToggleRegistry` 的初始化列表里加一行注册

不需要改动任何 UI 代码和其他功能代码。这是这个项目架构最重要的约定，所有开发过程中必须严格遵守。

---

## 需要特别注意的事项

**权限问题**：部分功能（如麦克风）需要在 `Info.plist` 中声明权限描述字符串，否则 macOS 会拒绝访问并崩溃。开发每个功能前先确认是否需要额外权限声明。

**状态同步问题**：开关的状态必须反映系统的真实状态，而不只是记录「上次点击的结果」。每次 Popover 弹出时，应该重新从系统读取所有开关的当前状态。

**Shell 命令的稳定性**：`defaults write` + `killall Finder` 这类方式在不同 macOS 版本下偶有差异，需要在目标系统版本上实测。

**非沙盒应用的签名**：分发时需要用开发者证书进行公证（Notarization），否则用户打开时会被 Gatekeeper 拦截。如果只是自用，直接在终端执行 `xattr -d com.apple.quarantine` 绕过即可。

---

这份方案可以直接交给 Claude 作为上下文，从「第一步搭建项目骨架」开始逐步推进。建议每完成一个步骤都让应用能跑起来再继续，不要一次性写太多再运行。
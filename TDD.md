# SwitchBar 技术设计文档 (TDD)

> 基于 SRD.md 设计方案，经技术讨论后确定的完整实施方案。

---

## 1. 已对齐的技术决策

| 决策点 | 结论 | 理由 |
|--------|------|------|
| `isOn` vs `apply` 职责 | 分离：`isOn` 纯状态，`apply` 纯执行 | shell 命令/系统 API 可能失败，需要回滚 `isOn` |
| 异构 ToggleProvider 持有 | `AnyToggleProvider` 类型擦除包装 | `ObservableObject` 有 associated type，不能直接 `[any ToggleProvider]` |
| UI 状态源 | `AnyToggleProvider` 是唯一 UI 状态源 | SwiftUI 不直接绑定具体 Provider，避免 UI 先改状态导致失败难回滚 |
| 状态提交 | 显示 busy，系统操作成功后再更新 `isOn` | MVP 优先保证真实状态正确，不做乐观更新 |
| 错误提示 | Row 下方轻量错误文案 | 不弹窗、不 toast，保持菜单栏工具轻量 |
| 状态同步 | `DistributedNotificationCenter` 实时监听 + Popover 弹出时 `refreshAll()` 兜底 | 深色模式等可能在 Popover 打开期间被系统改变 |
| 屏保功能 | `ControlType.action` 单次触发，非 toggle | 屏保是"立刻激活"动作，无 on/off 状态 |

---

## 2. 技术选型

| 项目 | 选型 | 说明 |
|------|------|------|
| 语言 | Swift 5.9+ | |
| UI 框架 | SwiftUI (面板) + AppKit (宿主) | NSStatusItem + NSPopover 需要 AppKit |
| 最低版本 | macOS 13 Ventura | SMAppService 要求 13+ |
| 持久化 | UserDefaults | 开关启用状态 + 排序顺序 |
| 图标系统 | SF Symbols | template image 适配深色/浅色菜单栏 |
| 构建 | Xcode project | 需要 Info.plist 配置 LSUIElement |
| 签名 | 开发阶段不签名，分发时公证 | 非沙盒应用 |

---

## 3. 核心架构

### 3.1 ToggleProvider 协议

```swift
enum ControlType {
    case toggle   // 标准开关（深色模式、保持亮屏...）
    case action   // 单次触发（屏保、锁屏...）
}

protocol ToggleProvider: Identifiable, ObservableObject {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }       // 可选副标题（如 AirPods 电量）
    var iconName: String { get }        // SF Symbols 图标名
    var controlType: ControlType { get }
    var isOn: Bool { get set }
    func apply(newValue: Bool) async -> Bool   // 执行系统操作，返回是否成功
    func refreshState()                        // 从系统读取真实状态
}

extension ToggleProvider {
    var controlType: ControlType { .toggle }
    var subtitle: String? { nil }
}
```

### 3.2 AnyToggleProvider 类型擦除

```swift
class AnyToggleProvider: Identifiable, ObservableObject {
    let id: String
    let title: String
    var subtitle: String? { _subtitle() }
    let iconName: String
    let controlType: ControlType

    // UI 只读取 AnyToggleProvider 的状态，不直接绑定原始 provider。
    // 用户点击后调用 requestSet/triggerAction；系统操作成功后才提交 isOn。
    @Published private(set) var isOn: Bool
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var errorMessage: String?

    private let _subtitle: () -> String?
    private let _setIsOn: (Bool) -> Void
    private let _apply: (Bool) async -> Bool
    private let _refresh: () -> Void
    private let _readIsOn: () -> Bool
    private let providerObject: AnyObject

    init<T: ToggleProvider>(_ provider: T) {
        self.id = provider.id
        self.title = provider.title
        self.iconName = provider.iconName
        self.controlType = provider.controlType
        self.isOn = provider.isOn
        self.providerObject = provider
        self._subtitle = { provider.subtitle }
        self._setIsOn = { provider.isOn = $0 }
        self._apply = { await provider.apply(newValue: $0) }
        self._refresh = { provider.refreshState() }
        self._readIsOn = { provider.isOn }
    }

    @MainActor
    func requestSet(_ newValue: Bool) async {
        guard controlType == .toggle else { return }
        guard !isBusy else { return }

        let oldValue = isOn
        isBusy = true
        errorMessage = nil

        let success = await _apply(newValue)
        if success {
            _setIsOn(newValue)
            isOn = newValue
        } else {
            _setIsOn(oldValue)
            errorMessage = "操作失败，请稍后重试"
            _refresh()
            isOn = _readIsOn()
        }

        isBusy = false
    }

    @MainActor
    func triggerAction() async {
        guard controlType == .action else { return }
        guard !isBusy else { return }

        isBusy = true
        errorMessage = nil

        let success = await _apply(true)
        if !success {
            errorMessage = "操作失败，请稍后重试"
        }

        _setIsOn(false)
        isOn = false
        isBusy = false
    }

    @MainActor
    func refreshState() {
        guard !isBusy else { return }

        _refresh()
        isOn = controlType == .action ? false : _readIsOn()
        if controlType == .action {
            _setIsOn(false)
        }
    }
}
```

约束：

- SwiftUI 只观察 `AnyToggleProvider`，不直接绑定或修改具体 `ToggleProvider`。
- `AnyToggleProvider` 必须强持有原始 provider，避免闭包 weak capture 后 provider 被提前释放。
- Toggle 点击时不做乐观更新：先进入 `isBusy`，`apply` 成功后再更新 `isOn`。
- `apply` 失败时保持旧状态，并在当前 row 下方显示 `errorMessage`。
- `.action` 类型不保留状态，触发后 `isOn` 始终回到 `false`。

### 3.3 ToggleRegistry

```swift
class ToggleRegistry: ObservableObject {
    @Published var toggles: [AnyToggleProvider] = []
    @Published var enabledIDs: Set<String> = []
    @Published var order: [String] = []

    // 主面板使用：按顺序返回已启用的开关
    var visibleToggles: [AnyToggleProvider] {
        order.compactMap { id in
            toggles.first { $0.id == id && enabledIDs.contains(id) }
        }
    }

    func register(_ provider: AnyToggleProvider) { ... }
    func refreshAll() { toggles.forEach { $0.refreshState() } }
    func saveState()  // enabledIDs + order -> UserDefaults
    func loadState()  // UserDefaults -> enabledIDs + order
}
```

`ToggleRegistry` 只持久化显示配置：

- `enabledIDs`: 用户启用了哪些 row
- `order`: row 的显示顺序

不得把系统开关当前状态持久化到 UserDefaults。比如 `KeepAwakeToggle` 的 IOPMAssertion 只在当前进程生命周期有效，应用重启后必须重新读取真实状态，而不是恢复上次 UI 状态。

### 3.4 状态同步机制

每个 Toggle 内部负责监听自己关心的系统通知：

| Toggle | 监听方式 |
|--------|---------|
| DarkMode | `DistributedNotificationCenter`: `AppleInterfaceThemeChangedNotification` |
| KeepAwake | 无需监听（应用内完全控制 IOPMAssertion） |
| HideDesktop | 无直接通知，依赖 Popover 弹出时 `refreshState()` |
| ScreenSaver | 无需监听（action 类型，无状态） |

`AppDelegate` 在 `popoverWillShow` 时调用 `registry.refreshAll()` 作为兜底。

---

## 4. 目录结构

```
SwitchBar/
├── SwitchBar.xcodeproj
├── SwitchBar/
│   ├── Info.plist                    # LSUIElement = YES
│   ├── SwitchBar.entitlements
│   ├── Assets.xcassets/              # App icon + menu bar icon
│   ├── App/
│   │   ├── SwitchBarApp.swift        # @main 入口
│   │   └── AppDelegate.swift         # NSStatusItem + NSPopover
│   ├── Core/
│   │   ├── ToggleProvider.swift      # 协议 + ControlType 枚举
│   │   ├── AnyToggleProvider.swift   # 类型擦除包装
│   │   └── ToggleRegistry.swift      # 注册中心
│   ├── Toggles/
│   │   ├── DarkModeToggle.swift      # 深色模式
│   │   ├── KeepAwakeToggle.swift     # 保持亮屏
│   │   ├── HideDesktopToggle.swift   # 隐藏桌面图标
│   │   └── ScreenSaverToggle.swift   # 触发屏保
│   ├── UI/
│   │   ├── PopoverView.swift         # 主面板
│   │   ├── ToggleRowView.swift       # 开关行（toggle/action 两种样式）
│   │   └── SettingsView.swift        # 设置面板（勾选+拖拽排序）
│   └── Utilities/
│       └── ShellHelper.swift         # shell 命令执行工具
```

---

## 5. 各功能实现方案

### 5.1 DarkModeToggle

```swift
// apply:
//   AppleScript: tell app "System Events" to tell appearance preferences to set dark mode to {value}
// refreshState:
//   NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
// 监听:
//   DistributedNotificationCenter.default().addObserver(
//     forName: Notification.Name("AppleInterfaceThemeChangedNotification"), ...)
```

### 5.2 KeepAwakeToggle

```swift
// apply(true):
//   IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertionLevelOn, "SwitchBar KeepAwake", &assertionID)
// apply(false):
//   IOPMAssertionRelease(assertionID)
// refreshState:
//   检查 assertionID != kIOPMNullAssertionID
```

### 5.3 HideDesktopToggle

```swift
// apply(true):  隐藏桌面图标
//   ShellHelper.run("defaults write com.apple.finder CreateDesktop -bool false && killall Finder")
// apply(false): 显示桌面图标
//   ShellHelper.run("defaults write com.apple.finder CreateDesktop -bool true && killall Finder")
// refreshState:
//   ShellHelper.run("defaults read com.apple.finder CreateDesktop") 解析结果
```

### 5.4 ScreenSaverToggle (action)

```swift
// controlType = .action
// isOn 永远 false
// apply:
//   Process() 启动 /System/Library/CoreServices/ScreenSaverEngine.app
//   或 open -a ScreenSaverEngine
// refreshState: 空实现
```

### 5.5 ShellHelper

```swift
struct ShellHelper {
    @discardableResult
    static func run(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
```

---

## 6. 执行步骤

### Step 1: 项目骨架 + Menu Bar 宿主

**产出**: 菜单栏出现图标，点击弹出空白 Popover

- 创建 Xcode macOS App 项目
- `Info.plist`: `LSUIElement = YES`
- `SwitchBarApp.swift`: `@main` + `@NSApplicationDelegateAdaptor`
- `AppDelegate.swift`: `NSStatusItem` + `NSPopover(behavior: .transient)`
- 菜单栏图标: `switch.2` (SF Symbol, template image)

**验证**: 运行后菜单栏出现图标，点击弹出/关闭 Popover，应用不出现在 Dock。

### Step 2: Core 协议层

**产出**: 协议 + 类型擦除 + 注册中心完整可用

- `Core/ToggleProvider.swift`
- `Core/AnyToggleProvider.swift`
- `Core/ToggleRegistry.swift`
- 用 mock toggle 验证注册、排序、UserDefaults 持久化

**验证**: 注册 mock toggle，kill 重启后排序和启用状态保持。

### Step 3: 基础 UI

**产出**: Popover 显示开关列表 + 设置面板

- `UI/PopoverView.swift`: 从 Registry 读取 visibleToggles 渲染
- `UI/ToggleRowView.swift`: `.toggle` 渲染 Toggle 控件，`.action` 渲染触发按钮
- `UI/SettingsView.swift`: 勾选框 + `onMove` 拖拽排序
- Toggle 控件不得直接使用 `$toggle.isOn` 双向绑定；setter 中必须调用 `requestSet(_:)`
- 操作中禁用当前 row 或显示 `ProgressView`
- `errorMessage` 非空时，在 row 下方显示一行轻量错误文案

**验证**: 面板显示 mock 开关，设置面板可勾选/排序，关闭重开状态保持。

### Step 4: 逐个实现真实功能

按复杂度递增，每实现一个立刻集成测试：

1. **DarkModeToggle** — 最简单，AppleScript 一行
2. **KeepAwakeToggle** — IOKit 固定用法
3. **HideDesktopToggle** — Shell 命令 + killall Finder
4. **ScreenSaverToggle** — 启动进程（action 类型）

同步实现 `ShellHelper` 工具。

### Step 5: 细节打磨

- 登录自启动: `SMAppService.mainApp.register()` / `unregister()`
- 设置面板加「开机启动」开关
- Popover 弹出时 `registry.refreshAll()` 兜底同步
- Menu bar icon template image 确保深色/浅色适配

---

## 7. 验证清单

- [ ] 菜单栏图标可见，深色/浅色模式下均清晰
- [ ] 点击弹出 Popover，点外部自动关闭
- [ ] 深色模式开关正常工作
- [ ] 保持亮屏开关正常工作
- [ ] 隐藏桌面图标开关正常工作
- [ ] 屏保按钮点击后立刻进入屏保
- [ ] 设置面板勾选/排序 → 关闭重开保持
- [ ] 系统侧改变深色模式 → 面板开关实时同步
- [ ] 应用不出现在 Dock / App Switcher
- [ ] 开机启动功能正常
- [ ] Toggle 点击后进入 busy 状态，成功后才更新 `isOn`
- [ ] `apply` 失败时 `isOn` 不被错误提交，并在 row 下方显示错误文案
- [ ] busy 期间重复点击不会重复执行 `apply`
- [ ] action 类型触发后不保留 `isOn` 状态
- [ ] `ToggleRegistry` 只持久化 enabled/order，不持久化系统开关值

---

## 8. 扩展性约定

后续新增功能开关，只需：

1. 在 `Toggles/` 目录下新建 Swift 文件
2. 实现 `ToggleProvider` 协议
3. 在 `ToggleRegistry` 初始化列表加一行注册

不需要改动任何 UI 代码和其他功能代码。

# Development Log

## 2026-06-08

- 根据 `TDD.md` 落地 SwitchBar MVP 骨架。
- 采用测试先行流程，先编写 `SwitchBarCoreTestRunner` 覆盖核心行为，再实现核心代码。
- 完成 `SwitchBarCore`：
  - `ToggleProvider`
  - `AnyToggleProvider`
  - `ToggleRegistry`
  - `TogglePreferencesStore`
  - `ShellHelper`
  - `DarkModeToggle`
  - `KeepAwakeToggle`
  - `HideDesktopToggle`
  - `ScreenSaverToggle`
- 完成菜单栏宿主与 SwiftUI 面板：
  - `AppDelegate`
  - `PopoverView`
  - `ToggleRowView`
  - `SettingsView`
- 补充 `Info.plist`、entitlements 和 asset catalog 基础文件。
- 自动化验证：
  - `SwitchBarCoreTestRunner` 12 个核心测试全部通过。
  - `SwitchBar` 菜单栏宿主通过 `swiftc` 编译。
- 环境限制：
  - 当前机器只有 Command Line Tools，没有完整 Xcode，`swift test` / `swift run` 会因缺少 `xctest` 失败。
  - 当前 `swift --version` 为 5.3.2，无法使用 `async/await` 语法；实现中保留了 `apply(newValue:) -> Bool` 的行为语义，但没有使用文档伪代码里的 `async` 关键字。

## 2026-06-08 一键启动脚本

- 新增 `scripts/start.sh`。
- 默认流程：编译 `SwitchBarCore` -> 编译并运行 `SwitchBarCoreTestRunner` -> 编译 `SwitchBar` -> 启动菜单栏程序。
- 支持参数：
  - `--skip-tests`: 跳过核心测试，直接编译启动。
  - `--build-only`: 只编译，不启动。
  - `--background`: 后台启动，并把日志写到构建目录。

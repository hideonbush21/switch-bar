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

## 2026-06-08 隐藏桌面不重启 Finder

- 该方案是中间版本，已被后续“Finder 功能解耦重构”取代；当前实现允许受控重启 Finder。
- 按新需求调整 `HideDesktopToggle`：隐藏/显示桌面图标时只写入 `com.apple.finder CreateDesktop`，不再执行 `killall Finder`。
- 更新测试断言，明确禁止 `HideDesktopToggle` 执行 `killall Finder` 或 `open -a Finder`。
- 更新 `TDD.md`，记录该方案的行为边界：不会主动影响 Finder 窗口或其他应用，但是否立即刷新桌面图标取决于 Finder 自身刷新机制。

## 2026-06-08 Finder 功能解耦重构

- 按新的产品取舍调整方案：用户接受 Finder 重启，要求 HideDesktop 与 ShowHiddenFiles 业务模块彼此独立。
- 新增 Finder 操作分层：
  - `FinderPreferenceStore`: 统一读写 `com.apple.finder` 布尔偏好。
  - `FinderReloader`: 唯一允许执行 `killall Finder` / `open -a Finder` 的组件。
  - `FinderDesktopIconService`: 只管理 `CreateDesktop`。
  - `FinderHiddenFilesService`: 只管理 `AppleShowAllFiles`。
- 默认 reload 策略为 `reopenIfUserHadFinderWindow`：用户原本有 Finder 窗口时才尝试重开 Finder；重开失败不再导致 Toggle 操作失败。
- 改造 `HideDesktopToggle` 和 `ShowHiddenFilesToggle`，让它们只依赖各自 service，不再直接拼 Finder shell 命令。
- 自动化测试从 12 个扩展到 20 个，新增职责边界、偏好 key 隔离、Finder reload 策略和 Finder 重开 best-effort 覆盖。

## 2026-06-08 Finder 重开失败不阻断 Toggle

- 修复 Finder 窗口打开时点击“隐藏桌面图标”显示“操作失败”的问题。
- 根因：`FinderReloader` 把 `open -a Finder` 或等待 Finder 恢复失败当成整个 reload 失败，导致 `HideDesktopToggle` 返回失败。
- 调整后：`killall Finder` 失败才算 reload 失败；等待 Finder 恢复和 `open -a Finder` 均为 best-effort。
- 新增 2 个回归测试，覆盖 Finder 等待失败和重开失败时仍返回成功。

## 2026-06-09 新增系统开关

- 新增 `TrueToneToggle`：通过 `CoreBrightness` 私有框架读取/设置原彩显示状态。
  - `TrueToneClient` 协议隔离私有框架依赖，便于测试注入。
  - `CoreBrightnessTrueToneClient` 使用 `dlopen` + `NSSelectorFromString` 动态调用 `CBTrueToneClient`。
- 新增 `LowPowerModeToggle`：通过 `pmset -a lowpowermode` 读取/设置低电量模式。
  - 首次执行弹管理员密码框，同时写入 `/etc/sudoers.d/switchbar-pmset` 实现后续免密。
  - 使用临时脚本避免 `osascript` 嵌套引号问题。
- `AppDelegate` 注册两个新 Toggle，自动加入用户启用列表。

## 2026-06-26 Toggle apply 异步化

- `AnyToggleProvider.requestSet` / `triggerAction` 原先在主线程同步执行 shell 命令，Finder 重启等耗时操作会冻住 popover。
- 新增可注入的 `executeInBackground` / `executeOnMain` 执行器：生产环境通过 `DispatchQueue` 异步派发，测试注入同步执行器保持确定性。
- `isBusy` 在派发前即设为 `true`，UI 可立即响应显示忙碌态。
- 新增 3 个测试覆盖异步派发路径和忙碌态时序。

## 2026-06-26 低电量模式 sudoers 写入安全加固

- 临时脚本路径使用 UUID 随机化，防止固定路径被符号链接抢占。
- 脚本文件创建后立即设置 `0700` 权限。
- sudoers 规则先写临时文件，经 `visudo -cf` 校验通过后再 `mv` 到目标位置，避免语法错误损坏 sudoers 链。
- 脚本使用 `set -e` 确保任意步骤失败立即中止。
- 脚本执行后自清理（`rm -f`），不再残留在 `/tmp`。
- 新增 `LowPowerModeToggle.removeSudoersRule()` 静态方法，供卸载或设置页面清理免密规则。
- 新增 4 个测试覆盖快速路径、随机路径、visudo 校验和规则移除。

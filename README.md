# SwitchBar

A macOS menu bar app for toggling common system settings with a single click.

![macOS](https://img.shields.io/badge/macOS-10.15%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.3%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Dark Mode** — toggle system dark/light appearance
- **Keep Awake** — prevent display sleep
- **Hide Desktop** — hide/show desktop icons
- **Screen Saver** — trigger screen saver immediately
- Drag to reorder toggles
- Show/hide individual toggles via Settings
- State persisted across launches

## Requirements

- macOS 10.15 Catalina or later
- Xcode 12+ / Swift 5.3+

## Build & Run

```bash
git clone https://github.com/hideonbush21/switch-bar.git
cd switch-bar
swift run SwitchBar
```

Or open in Xcode:

```bash
open Package.swift
```

Select the `SwitchBar` scheme and run.

## Project Structure

```
Sources/
  SwitchBarCore/     # Core toggle abstractions and implementations
  SwitchBar/         # macOS app (AppDelegate, SwiftUI views)
  SwitchBarCoreTestRunner/  # Test runner
SwitchBar/
  Assets.xcassets/   # App icons and assets
  Info.plist
  SwitchBar.entitlements
```

## Adding a Custom Toggle

1. Create a struct conforming to `ToggleProvider` in `Sources/SwitchBarCore/`
2. Register it in `AppDelegate.registerToggles()`

```swift
public struct MyToggle: ToggleProvider {
    public let id = "my-toggle"
    public let label = "My Feature"
    public var isOn: Bool = false

    public mutating func refreshState() { /* read system state */ }
    public mutating func toggle() { /* apply change */ }
}
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

## License

[MIT](LICENSE)

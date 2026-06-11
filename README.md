# RingLight

> **High-performance screen illumination for everyone.**

[![macOS](https://img.shields.io/badge/platform-macOS-blue.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/language-Swift-orange.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

RingLight is a lightweight macOS utility that turns your screen edges into a professional-grade ring light for video calls.

---

## Fork Notice

This is a fork of [itsOmSarraf/ringlight](https://github.com/itsOmSarraf/ringlight) by [@itsOmSarraf](https://github.com/itsOmSarraf), the best macOS edge-light implementation I found. The original repo went unmaintained, so I forked it to continue the work.

Apple's own Edge Light has two problems that sent me looking for alternatives: it's been broken on multi-monitor setups since macOS 26.4 (still unfixed in 26.5), only showing on the built-in display, and there's no way to control placement or behavior across monitors at all.

---

### Project Origin

Apple recently introduced "Edge Light" in macOS Tahoe (26.2), but the feature is restricted by hardware and OS version:

1. **Hardware**: Requires Apple Silicon.
2. **OS**: Requires macOS Tahoe or later.
3. **Auto-Mode**: Limited to 2024+ Macs.

**RingLight provides this functionality for all Mac users today.** It removes the need to upgrade your hardware or OS just to access basic video call illumination.

---

## Screenshots

<img width="3024" height="1964" alt="image" src="https://github.com/user-attachments/assets/2e3ca99c-157f-4f08-9bbb-932030109c9e" />
---

## Features

- **Rectangular Ring**: Matches the aspect ratio of your display for maximum coverage.
- **Mouse Avoidance**: Smart transparency hole follows your cursor to prevent blocking your view while working.
- **Click-Through Center**: The center remains transparent and ignores mouse events, allowing you to interact with windows behind the light normally.
- **Temperature Slider**: Adjust from Warm (Studio Orange) to Cool (Arctic Blue) to match your environment.
- **Brightness & Thickness**: Fine-tune the intensity and width of the illumination.
- **Roundness Control**: Adjust corner radius to match your display's physical corners.
- **Lightweight Build**: Written in pure SwiftUI and AppKit with minimal CPU overhead.
- **Menu Bar Utility**: Runs as an accessory app with no Dock clutter.

---

## Installation & Usage

1. **Clone the repository**: `git clone https://github.com/ocolunga/ringlight.git`
2. **Open in Xcode**: `ringlight.xcodeproj`
3. **Build and Run**: Press `⌘R`.
4. **Operation**: Click the rectangular icon in the menu bar to adjust brightness, thickness, temperature, and toggle **Avoid Mouse**.
5. **Shortcuts**:
   - `SPACE`: Toggle light ON/OFF.
   - `ESC`: Quit application.

---

## Roadmap

Items marked ✅ were completed in this fork. The rest carry forward from the original proposed roadmap.

- [x] ✅ **Multi-Display Support** — dynamic screen detection; the overlay now correctly tracks the active display and adapts its geometry and corner radius to any monitor.
- [x] ✅ **Improved Mouse Tracking** — more accurate cursor-avoidance across display configurations.
- [ ] **Face Tracking**: Dynamic dimming near the user's face using the Vision framework.
- [ ] **Camera Activity Detection**: Auto-closing the ring light when no camera activity is detected to save resources (includes user alerts).
- [ ] **App Integration**: Auto-activation when conferencing apps (Zoom, Teams) start.
- [ ] **Preset Modes**: Quick settings for specific lighting conditions.
- [ ] **Homebrew distribution**: Package and publish via Homebrew for easy installation.
- [ ] **App Store release**: Distribute as a proper signed app through the Mac App Store.

---

## Contributing

Contributions are welcome. Please follow these steps:

1. Fork the Project
2. Create a Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

*Built for the Mac community.*

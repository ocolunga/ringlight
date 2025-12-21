# RingLight

> **High-performance screen illumination for everyone.** 

[![macOS](https://img.shields.io/badge/platform-macOS-blue.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/language-Swift-orange.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

RingLight is a lightweight macOS utility that turns your screen edges into a professional-grade ring light for video calls. 

### Project Origin
Apple recently introduced "Edge Light" in macOS Tahoe (26.2), but the feature is restricted by hardware and OS version:
1. **Hardware**: Requires Apple Silicon.
2. **OS**: Requires macOS Tahoe or later.
3. **Auto-Mode**: Limited to 2024+ Macs.

**RingLight provides this functionality for all Mac users today.** It removes the need to upgrade your hardware or OS just to access basic video call illumination.

---

## Screenshots

[Insert Main App Screenshot Here]
*The ring light in action: full-screen illumination with a transparent, click-through center.*

### Menu Bar Controls
[Insert Menu Bar Popover Screenshot Here]
*Native control panel accessible directly from the macOS menu bar.*

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

1. **Clone the repository**: `git clone https://github.com/itsOmSarraf/ringlight.git`
2. **Open in Xcode**: `ringlight.xcodeproj`
3. **Build and Run**: Press `⌘R`.
4. **Operation**: Click the rectangular icon in the menu bar to adjust brightness, thickness, temperature, and toggle **Avoid Mouse**.
5. **Shortcuts**: 
   - `SPACE`: Toggle light ON/OFF.
   - `ESC`: Quit application.

---

## Roadmap

- [ ] **Face Tracking**: Dynamic dimming near the user's face using the Vision framework.
- [ ] **Camera Activity Detection**: Auto-closing the ring light when no camera activity is detected to save resources (includes user alerts).
- [ ] **App Integration**: Auto-activation when conferencing apps (Zoom, Teams) start.
- [ ] **Preset Modes**: Quick settings for specific lighting conditions.
- [ ] **Multi-Display Support**: Ability to choose the target display for the effect.

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

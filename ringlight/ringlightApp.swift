//
//  ringlightApp.swift
//  ringlight
//
//  Created by Om Sarraf on 20/12/25.
//

import SwiftUI
import AppKit

@main
struct ringlightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var overlayWindow: NSWindow?
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    @Published var ringThickness: CGFloat = 45
    @Published var brightness: CGFloat = 1.0
    @Published var colorTemperature: CGFloat = 0.5
    @Published var cornerRadius: CGFloat = 40
    @Published var glowIntensity: CGFloat = 0.5
    @Published var isActive: Bool = true
    @Published var margin: CGFloat = 0
    
    var ringColor: NSColor {
        temperatureToColor(colorTemperature)
    }
    
    func temperatureToColor(_ temp: CGFloat) -> NSColor {
        if temp < 0.5 {
            let t = temp * 2
            let r: CGFloat = 1.0
            let g: CGFloat = 0.7 + (0.3 * t)
            let b: CGFloat = 0.4 + (0.6 * t)
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            let t = (temp - 0.5) * 2
            let r: CGFloat = 1.0 - (0.15 * t)
            let g: CGFloat = 1.0 - (0.05 * t)
            let b: CGFloat = 1.0
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - make it a pure menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        NSApplication.shared.windows.forEach { $0.close() }
        createOverlayWindow()
        createMenuBarIcon()
        setupGlobalKeyboardShortcuts()
    }
    
    func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        let fullFrame = screen.frame
        overlayWindow = OverlayWindow(
            contentRect: fullFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        guard let window = overlayWindow else { return }
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let hostingView = NSHostingView(rootView: RingLightOverlay(appDelegate: self))
        hostingView.frame = fullFrame
        window.contentView = hostingView
        window.orderFrontRegardless()
    }
    
    func createMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Create a custom Rectangular Ring Light icon for the menu bar
            let size = NSSize(width: 20, height: 16)
            let image = NSImage(size: size, flipped: false) { rect in
                let inset: CGFloat = 2
                let thickness: CGFloat = 2.0
                let outerRect = rect.insetBy(dx: inset, dy: inset)
                
                // Draw a rounded rectangular ring to match the app's look
                let path = NSBezierPath(roundedRect: outerRect, xRadius: 3, yRadius: 3)
                path.lineWidth = thickness
                NSColor.labelColor.setStroke()
                path.stroke()
                
                return true
            }
            image.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 260, height: 360)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarControlView(appDelegate: self))
    }
    
    @objc func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func setupGlobalKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            switch event.keyCode {
            case 53: // ESC
                NSApplication.shared.terminate(nil)
                return nil
            case 49: // SPACE
                self?.isActive.toggle()
                return nil
            default:
                return event
            }
        }
    }
}

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Components
struct ControlSlider: View {
    let icon: String
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var unit: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(unit == "%" ? value * 100 : value))\(unit)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range)
                .controlSize(.small)
        }
    }
}

struct TemperatureSlider: View {
    @Binding var value: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                Text("Temperature")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.3),
                                    Color.white,
                                    Color(red: 0.75, green: 0.88, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 20)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .offset(x: value * (geometry.size.width - 18))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let newValue = gesture.location.x / geometry.size.width
                                    value = min(max(newValue, 0), 1)
                                }
                        )
                }
            }
            .frame(height: 20)
            
            HStack {
                Text("Warm")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Cool")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Views
struct RingLightOverlay: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        GeometryReader { geometry in
            if appDelegate.isActive {
                ZStack {
                    ForEach(0..<3) { layer in
                        RoundedRingShape(
                            thickness: appDelegate.ringThickness + CGFloat(layer) * 12,
                            cornerRadius: appDelegate.cornerRadius,
                            margin: appDelegate.margin,
                            menuBarHeight: getMenuBarHeight()
                        )
                        .fill(
                            Color(nsColor: appDelegate.ringColor)
                                .opacity(appDelegate.brightness * appDelegate.glowIntensity / Double(layer + 2))
                        )
                        .blur(radius: CGFloat(layer + 1) * 8)
                    }
                    
                    RoundedRingShape(
                        thickness: appDelegate.ringThickness,
                        cornerRadius: appDelegate.cornerRadius,
                        margin: appDelegate.margin,
                        menuBarHeight: getMenuBarHeight()
                    )
                    .fill(Color(nsColor: appDelegate.ringColor).opacity(appDelegate.brightness))
                }
            }
        }
        .ignoresSafeArea()
    }
    
    func getMenuBarHeight() -> CGFloat {
        guard let screen = NSScreen.main else { return 25 }
        let height = screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
        return max(height, 0)
    }
}

struct RoundedRingShape: Shape {
    var thickness: CGFloat
    var cornerRadius: CGFloat
    var margin: CGFloat
    var menuBarHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let outerRect = CGRect(
            x: rect.minX + margin,
            y: rect.minY + margin + menuBarHeight,
            width: rect.width - margin * 2,
            height: rect.height - margin * 2 - menuBarHeight
        )
        path.addRoundedRect(in: outerRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        
        let innerRect = CGRect(
            x: rect.minX + margin + thickness,
            y: rect.minY + margin + thickness + menuBarHeight,
            width: rect.width - (margin + thickness) * 2,
            height: rect.height - (margin + thickness) * 2 - menuBarHeight
        )
        let innerCornerRadius = max(cornerRadius - thickness * 0.6, 20)
        path.addRoundedRect(in: innerRect, cornerSize: CGSize(width: innerCornerRadius, height: innerCornerRadius))
        return path
    }
}

extension RoundedRingShape {
    func fill(_ content: some ShapeStyle) -> some View {
        self.fill(content, style: FillStyle(eoFill: true))
    }
}

struct MenuBarControlView: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimal Header
            HStack {
                Text("Ring Light")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Toggle("", isOn: $appDelegate.isActive)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
            
            // Controls - No Scroll
            VStack(spacing: 20) {
                ControlSlider(icon: "sun.max", label: "Brightness", value: $appDelegate.brightness, range: 0.1...1.0, unit: "%")
                
                TemperatureSlider(value: $appDelegate.colorTemperature)
                
                ControlSlider(icon: "rectangle.expand.vertical", label: "Thickness", value: $appDelegate.ringThickness, range: 10...100, unit: "px")
                
                ControlSlider(icon: "squareshape.controlhandles.on.squareshape.controlhandles", label: "Roundness", value: $appDelegate.cornerRadius, range: 20...120, unit: "px")
            }
            .padding(16)
            
            Divider()
            
            // Minimal Footer
            HStack {
                Text("ESC to quit")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14) // More balanced padding
        }
        .frame(width: 260, height: 360) // Slightly taller for breathing room
    }
}

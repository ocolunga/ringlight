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
        NSApplication.shared.windows.forEach { $0.close() }
        createOverlayWindow()
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

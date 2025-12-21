//
//  ringlightApp.swift
//  ringlight
//
//  Created by Om Sarraf on 20/12/25.
//

import SwiftUI
import AppKit
import AVFoundation
import CoreMediaIO

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
    var mouseMonitor: Any?
    var localMouseMonitor: Any?
    
    @Published var ringThickness: CGFloat = 45
    @Published var brightness: CGFloat = 1.0
    @Published var colorTemperature: CGFloat = 0.5
    let cornerRadius: CGFloat = 40 // Default fixed roundness
    @Published var glowIntensity: CGFloat = 0.5
    @Published var isActive: Bool = true
    @Published var avoidMouse: Bool = true
    @Published var showCameraPreview: Bool = false {
        didSet {
            if showCameraPreview {
                startCamera()
            } else {
                stopCamera()
            }
            updatePopoverSize()
        }
    }
    @Published var margin: CGFloat = 20
    @Published var mouseLocation: CGPoint = .zero
    @Published var isMouseOverRing: Bool = false
    
    var captureSession: AVCaptureSession?
    
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
    
    func startCamera() {
        if captureSession != nil { return }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.captureSession = session
            }
        }
    }
    
    func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    func updatePopoverSize() {
        let height: CGFloat = showCameraPreview ? 500 : 360
        popover?.contentSize = NSSize(width: 260, height: height)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - make it a pure menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        NSApplication.shared.windows.forEach { $0.close() }
        createOverlayWindow()
        createMenuBarIcon()
        setupGlobalKeyboardShortcuts()
        setupMouseTracking()
    }
    
    func setupMouseTracking() {
        // Track mouse globally
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.updateMouseLocation()
        }
        // Also track locally for when the app is active
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.updateMouseLocation()
            return event
        }
    }
    
    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let localMonitor = localMouseMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
    
    func updateMouseLocation() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        
        // Convert from screen coordinates (bottom-left) to SwiftUI (top-left)
        let screenFrame = screen.frame
        let convertedLocation = CGPoint(
            x: location.x - screenFrame.origin.x,
            y: screenFrame.height - (location.y - screenFrame.origin.y)
        )
        
        if self.mouseLocation != convertedLocation {
            self.mouseLocation = convertedLocation
        }
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
                .mask(
                    Group {
                        if appDelegate.avoidMouse {
                            Canvas { context, size in
                                // Draw a full-screen white mask
                                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                                
                                // Draw a "hole" at the mouse position
                                let holeRadius: CGFloat = 60
                                let holeRect = CGRect(
                                    x: appDelegate.mouseLocation.x - holeRadius,
                                    y: appDelegate.mouseLocation.y - holeRadius,
                                    width: holeRadius * 2,
                                    height: holeRadius * 2
                                )
                                
                                // Use destinationOut to create a hole in the mask
                                context.blendMode = .destinationOut
                                context.fill(Path(ellipseIn: holeRect), with: .color(.white))
                                // Add some blur to the hole for smoother transition
                                context.addFilter(.blur(radius: 20))
                            }
                        } else {
                            Rectangle().fill(Color.white)
                        }
                    }
                )
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

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let session = session {
            let existingLayer = nsView.layer?.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer
            if existingLayer == nil {
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = nsView.bounds
                
                // Mirror the preview
                if let connection = layer.connection {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    }
                }
                
                nsView.layer?.addSublayer(layer)
            } else {
                existingLayer?.frame = nsView.bounds
                
                // Ensure mirroring is maintained on update
                if let connection = existingLayer?.connection {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    }
                }
            }
        } else {
            nsView.layer?.sublayers?.forEach { if $0 is AVCaptureVideoPreviewLayer { $0.removeFromSuperlayer() } }
        }
    }
}

struct MenuBarControlView: View {
    @ObservedObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            // Camera Preview
            if appDelegate.showCameraPreview {
                CameraPreviewView(session: appDelegate.captureSession)
                    .frame(height: 140)
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                Divider()
            }
            
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
            VStack(spacing: 12) {
                ControlSlider(icon: "sun.max", label: "Brightness", value: $appDelegate.brightness, range: 0.1...1.0, unit: "%")
                
                TemperatureSlider(value: $appDelegate.colorTemperature)
                
                ControlSlider(icon: "rectangle.expand.vertical", label: "Thickness", value: $appDelegate.ringThickness, range: 10...100, unit: "px")
                
                HStack(spacing: 8) {
                    Toggle("", isOn: $appDelegate.avoidMouse)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .frame(width: 18)
                    Text("Avoid Mouse")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Toggle("", isOn: $appDelegate.showCameraPreview)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .frame(width: 18)
                    HStack(spacing: 4) {
                        Text("Camera Preview")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(16)
            
            Divider()
            
            // Minimal Footer
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "https://github.com/itsOmSarraf/ringlight") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Star on GitHub")
                    }
                    .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                
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
        .frame(width: 260, height: appDelegate.showCameraPreview ? 500 : 360)
    }
}

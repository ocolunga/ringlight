//
//  RimLightApp.swift
//  RimLight
//
//  Created by Om Sarraf on 20/12/25.
//

import SwiftUI
import AppKit
import AVFoundation
import CoreMediaIO
import CoreGraphics

// Brightness control helper using dynamic loading
class BrightnessControl {
    typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    
    private static var setBrightnessFunc: SetBrightnessFunc?
    private static var getBrightnessFunc: GetBrightnessFunc?
    private static var isLoaded = false
    
    static func loadDisplayServices() {
        guard !isLoaded else { return }
        isLoaded = true
        
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        if handle != nil {
            if let setBrightness = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessFunc = unsafeBitCast(setBrightness, to: SetBrightnessFunc.self)
            }
            if let getBrightness = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessFunc = unsafeBitCast(getBrightness, to: GetBrightnessFunc.self)
            }
        }
    }
    
    static func setBrightness(_ level: Float) {
        loadDisplayServices()
        if let setFunc = setBrightnessFunc {
            _ = setFunc(CGMainDisplayID(), level)
        }
    }
    
    static func getBrightness() -> Float {
        loadDisplayServices()
        var level: Float = 1.0
        if let getFunc = getBrightnessFunc {
            _ = getFunc(CGMainDisplayID(), &level)
        }
        return level
    }
}

@main
struct RimLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSPopoverDelegate {
    var overlayWindow: NSWindow?
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var mouseMonitor: Any?
    var localMouseMonitor: Any?
    var overlayScreen: NSScreen?
    
    @Published var ringThickness: CGFloat = 45
    @Published var brightness: CGFloat = 1.0 {
        didSet {
            setSystemBrightness(Float(brightness))
        }
    }
    @Published var colorTemperature: CGFloat = 0.5
    var overlayCornerRadius: CGFloat {
        guard let screen = overlayScreen ?? NSScreen.main else { return 200 }
        // Use 30% of the shorter dimension so the ring looks oval on all displays.
        return min(screen.frame.width, screen.frame.height) * 0.30
    }
    @Published var currentMonitorIndex: Int = 0
    @Published var glowIntensity: CGFloat = 0.5
    @Published var isActive: Bool = true
    @Published var avoidMouse: Bool = true
    @Published var showCameraPreview: Bool = false
    @Published var margin: CGFloat = 0
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
        popover?.contentSize = NSSize(width: 260, height: 500)
    }
    
    func setSystemBrightness(_ level: Float) {
        BrightnessControl.setBrightness(level)
    }
    
    func getSystemBrightness() -> Float {
        return BrightnessControl.getBrightness()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.brightness = CGFloat(getSystemBrightness())
        NSApp.setActivationPolicy(.accessory)
        NSApplication.shared.windows.forEach { $0.close() }
        createOverlayWindow()
        createMenuBarIcon()
        setupGlobalKeyboardShortcuts()
        setupMouseTracking()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc func screensDidChange() {
        let screens = NSScreen.screens
        if currentMonitorIndex >= screens.count {
            currentMonitorIndex = max(0, screens.count - 1)
        }
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        createOverlayWindow()
    }
    
    func setupMouseTracking() {
        let dragEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: dragEvents) { [weak self] _ in
            self?.updateMouseLocation()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: dragEvents) { [weak self] event in
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
        guard let windowFrame = overlayWindow?.frame else { return }

        let converted = CGPoint(
            x: location.x - windowFrame.origin.x,
            y: windowFrame.height - (location.y - windowFrame.origin.y)
        )
        if mouseLocation != converted { mouseLocation = converted }
    }
    
    func createOverlayWindow() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let screen = screens[min(currentMonitorIndex, screens.count - 1)]
        overlayScreen = screen
        let fullFrame = screen.frame
        overlayWindow = OverlayWindow(
            contentRect: fullFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        guard let window = overlayWindow else { return }
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let hostingView = NSHostingView(rootView: RingLightOverlay(appDelegate: self))
        hostingView.frame = CGRect(origin: .zero, size: fullFrame.size)
        hostingView.wantsLayer = true
        window.contentView = hostingView
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.9999
        anim.duration = 1.0
        anim.repeatCount = .greatestFiniteMagnitude
        anim.autoreverses = true
        hostingView.layer?.add(anim, forKey: "keepAlive")
        window.orderFrontRegardless()
    }
    
    func switchMonitor() {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }
        let newIndex = (currentMonitorIndex + 1) % screens.count
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow = nil
            self.currentMonitorIndex = newIndex
            self.createOverlayWindow()
        }
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
        popover?.contentSize = NSSize(width: 260, height: 500)
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(rootView: MenuBarControlView(appDelegate: self))
    }
    
    func popoverWillShow(_ notification: Notification) {
        showCameraPreview = true
        startCamera()
        updatePopoverSize()
    }
    
    func popoverDidClose(_ notification: Notification) {
        showCameraPreview = false
        stopCamera()
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
                    let glowScale = min(geometry.size.width, geometry.size.height) / 800.0
                    let cr = appDelegate.overlayCornerRadius
                    let menuBarH = getMenuBarHeight()
                    let T = appDelegate.ringThickness
                    let b = appDelegate.brightness
                    let baseMargin = appDelegate.margin
                    let color = Color(nsColor: appDelegate.ringColor)

                    // White core — this is what grows with thickness
                    let w2 = T * 0.65
                    let m2 = baseMargin + (T - w2) / 2
                    let cr2 = max(cr - (T - w2) / 2 * 0.6, 20)

                    // Amber fringe — narrow fixed border on each side of the white core, capped at 25px
                    let amberBorder: CGFloat = min(T * 0.18, 25)
                    let w0 = min(w2 + amberBorder * 2, T)
                    let m0 = baseMargin + (T - w0) / 2
                    let cr0 = max(cr - (T - w0) / 2 * 0.6, 20)

                    // Layer 0: amber fringe wrapping the white core
                    RoundedRingShape(thickness: w0, cornerRadius: cr0, margin: m0, menuBarHeight: menuBarH)
                        .fill(color.opacity(b * 0.85))
                        .blur(radius: amberBorder * 0.6 * glowScale)

                    // Layer 1: warm color on core face — 1pt blur regardless of screen size
                    RoundedRingShape(thickness: w2, cornerRadius: cr2, margin: m2, menuBarHeight: menuBarH)
                        .fill(color.opacity(b * 0.95))
                        .blur(radius: 1.0)

                    // Layer 2: bright white core — nearly sharp
                    RoundedRingShape(thickness: w2, cornerRadius: cr2, margin: m2, menuBarHeight: menuBarH)
                        .fill(Color.white.opacity(b * 0.92))
                        .blur(radius: 1.0)
                }
                .mask(
                    Group {
                        if appDelegate.avoidMouse {
                            Canvas { context, size in
                                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

                                // Scale radii with screen diagonal so the effect is
                                // proportionally larger on bigger displays.
                                let diag = sqrt(size.width * size.width + size.height * size.height)
                                let outerRadius = diag * 0.067
                                let innerRadius = outerRadius * 0.5
                                let center = appDelegate.mouseLocation

                                context.blendMode = .destinationOut
                                context.fill(
                                    Path(ellipseIn: CGRect(
                                        x: center.x - outerRadius,
                                        y: center.y - outerRadius,
                                        width: outerRadius * 2,
                                        height: outerRadius * 2
                                    )),
                                    with: .radialGradient(
                                        Gradient(stops: [
                                            .init(color: .white, location: 0),
                                            .init(color: .white, location: 0.5),
                                            .init(color: .clear, location: 1)
                                        ]),
                                        center: center,
                                        startRadius: 0,
                                        endRadius: outerRadius
                                    )
                                )
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
        guard let screen = appDelegate.overlayScreen ?? NSScreen.main else { return 25 }
        return max(screen.frame.maxY - screen.visibleFrame.maxY, 0)
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
                Text("RimLight")
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
                ControlSlider(icon: "sun.max.fill", label: "Brightness", value: $appDelegate.brightness, range: 0.1...1.0, unit: "%")
                
                TemperatureSlider(value: $appDelegate.colorTemperature)
                
                ControlSlider(icon: "rectangle.expand.vertical", label: "Thickness", value: $appDelegate.ringThickness, range: 10...200, unit: "px")
                
                HStack(spacing: 8) {
                    Toggle("", isOn: $appDelegate.avoidMouse)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .frame(width: 18)
                    Text("Avoid Mouse")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }

                let screenCount = NSScreen.screens.count
                if screenCount > 1 {
                    HStack(spacing: 8) {
                        Image(systemName: "display.2")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 18)
                        Text("Monitor \(appDelegate.currentMonitorIndex + 1) of \(screenCount)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Button("Switch") {
                            appDelegate.switchMonitor()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(16)
            
            Divider()
            
            // Minimal Footer
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "https://github.com/ocolunga/rimlight") {
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
        .frame(width: 260, height: 500)
    }
}

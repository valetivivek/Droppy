import Cocoa
import SwiftUI

class ClipboardWindowController: NSObject, NSWindowDelegate {
    static let shared = ClipboardWindowController()
    
    var window: NSWindow!
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    private override init() {
        super.init()
        // Lazy setup when needed or on init? Let's do on init to be ready.
        setupWindow()
    }
    
    func setupWindow() {
        let clipboardView = ClipboardManagerView(
            onPaste: { item in
                self.paste(item)
            },
            onClose: {
                self.close()
            },
            onReset: {
                self.resetWindowSize()
            }
        )
        
        let hostingController = NSHostingController(rootView: clipboardView)
        
        // Borderless, transparent window, but RESIZABLE for manual resizing
        window = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.borderless, .fullSizeContentView, .resizable], 
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = false // Only header area should move window
        
        // Floating above normal windows
        window.level = .floating 
        
        // Auto-close behavior
        window.delegate = self
        
        // Allow clicking on it and becoming key
        window.ignoresMouseEvents = false
    }

    func resetWindowSize() {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let newRect = NSRect(
                x: screenRect.midX - 360, 
                y: screenRect.midY - 240, 
                width: 720, 
                height: 480
            )
            DispatchQueue.main.async {
                self.window.setFrame(newRect, display: true, animate: true)
            }
        }
    }
    
    private var isAnimating = false
    private var previousApp: NSRunningApplication?

    func toggle() {
        if window.isVisible {
            close()
        } else {
            show()
        }
    }
    
    func show() {
        guard !isAnimating else { return }
        
        // Save previous app to restore focus for paste
        // Only if it's not Droppy itself!
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }
        
        // Center on main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let x = screenRect.midX - (windowRect.width / 2)
            let y = screenRect.midY - (windowRect.height / 2)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        isAnimating = true
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("⌨️ Droppy: Showing Clipboard Window (Aggressive Activation)")
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
        })
    }

    func close() {
        guard window.isVisible && !isAnimating else { return }
        
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window.orderOut(nil)
            self?.isAnimating = false
        })
    }
    
    func paste(_ item: ClipboardItem) {
        // Dismiss clipboard immediately
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window.orderOut(nil)
            self?.isAnimating = false
            
            // The Mirror Method (V12): Refined Sequence
            if let targetApp = self?.previousApp {
                let pid = targetApp.processIdentifier
                
                // 1. Hide Droppy first
                NSApp.hide(nil)
                NSApp.deactivate()
                
                // 2. Tiny wait to ensure Droppy is gone from focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // 3. Activate target app with all windows
                    targetApp.activate(options: .activateAllWindows)
                    
                    // 4. Wait for focus to settle (Matches ClipBook's 150ms)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        ClipboardManager.shared.paste(item: item, targetPID: pid)
                    }
                }
            } else {
                NSApp.hide(nil)
                NSApp.deactivate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    ClipboardManager.shared.paste(item: item)
                }
            }
        })
    }

    func windowDidResignKey(_ notification: Notification) {
        // This is triggered when clicking outside
        // Add a tiny delay check to prevent "flicker closure" during app activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.window.isVisible && !self.window.isKeyWindow {
                self.close()
            }
        }
    }
    
    // MARK: - Global Shortcut (Beta)
    func startMonitoringShortcut() {
        stopMonitoringShortcut()
        
        // Load saved shortcut
        var targetKeyCode = 49 // Space
        var targetModifiers: UInt = NSEvent.ModifierFlags([.command, .shift]).rawValue
        
        if let data = UserDefaults.standard.data(forKey: "clipboardShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            targetKeyCode = decoded.keyCode
            targetModifiers = decoded.modifiers
        }
        
        // 1. Global Monitor (when other apps are frontmost)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Use rawValue to handle exact match, but ensure we aren't blocked by minor flags
            if flags.rawValue == targetModifiers && event.keyCode == targetKeyCode {
                print("⌨️ Droppy: Global Shortcut Triggered")
                DispatchQueue.main.async { self?.toggle() }
            }
        }

        // 2. Local Monitor (when Droppy is frontmost)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.rawValue == targetModifiers && event.keyCode == targetKeyCode {
                DispatchQueue.main.async { self?.toggle() }
                return nil // Swallow
            }
            return event
        }
    }
    
    func stopMonitoringShortcut() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}

// MARK: - Custom Panel Class
class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

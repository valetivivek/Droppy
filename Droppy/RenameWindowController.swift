import Cocoa
import SwiftUI

class RenameWindowController: NSObject, NSWindowDelegate {
    static let shared = RenameWindowController()
    
    var window: NSPanel!
    private var onRename: ((String) -> Void)?
    
    private override init() {
        super.init()
        setupWindow()
    }
    
    private func setupWindow() {
        // Create the window (panel)
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], // Frameless appearance
            backing: .buffered,
            defer: false
        )
        
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Visual styling
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        
        // Delegate for lifecycle management
        window.delegate = self
    }
    
    func show(itemTitle: String, onRename: @escaping (String) -> Void) {
        self.onRename = onRename
        
        // Create the view
        let renameView = RenameWindowView(
            text: itemTitle,
            originalText: itemTitle,
            onRename: { [weak self] newText in
                self?.submit(newText)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        
        // Host it
        window.contentView = NSHostingView(rootView: renameView)
        
        // Center on screen
        window.center()
        
        // PREMIUM: Start scaled down and invisible for spring animation
        window.alphaValue = 0
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            contentView.layer?.opacity = 0
        }
        
        // Show and activate
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // PREMIUM: CASpringAnimation for bouncy appear
        if let layer = window.contentView?.layer {
            // Fade in
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0
            fadeAnim.toValue = 1
            fadeAnim.duration = 0.2
            fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            layer.add(fadeAnim, forKey: "fadeIn")
            layer.opacity = 1
            
            // Scale with spring overshoot
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.85
            scaleAnim.toValue = 1.0
            scaleAnim.mass = 1.0
            scaleAnim.stiffness = 280
            scaleAnim.damping = 20
            scaleAnim.initialVelocity = 8
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "scaleSpring")
            layer.transform = CATransform3DIdentity
        }
        
        // Fade window alpha
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        })
        
        // PREMIUM: Haptic confirms rename window opened
        HapticFeedback.expand()
    }
    
    private func submit(_ text: String) {
        onRename?(text)
        close()
    }
    
    func close() {
        // Clear content view first to trigger onDisappear and stop animations
        window.contentView = nil
        window.orderOut(nil)
        onRename = nil
    }
    
    // REMOVED: Auto-close on resign key
    // Keeping the rename window open when it loses focus allows the clipboard to stay visible
    // and prevents accidental data loss. User must explicitly Cancel or Save.
    // func windowDidResignKey(_ notification: Notification) {
    //     close()
    // }
}

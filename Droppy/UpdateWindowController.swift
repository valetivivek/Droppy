//
//  UpdateWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import Cocoa
import SwiftUI

class UpdateWindowController: NSObject, NSWindowDelegate {
    static let shared = UpdateWindowController()
    
    /// The update window
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    /// Shows the update window, creating it if necessary
    func showWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If window already exists, just bring it to front
            if let window = self.window {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                return
            }
            
            // Create the SwiftUI view
            let updateView = UpdateView()
                .preferredColorScheme(.dark) // Force dark mode always
            let hostingView = NSHostingView(rootView: updateView)
            
            // Compact window size - height determined by content
            let windowWidth: CGFloat = 400
            let windowHeight: CGFloat = 150 // Initial size, will adjust to content
            
            // Create the window - borderless style without traffic lights
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            newWindow.center()
            newWindow.title = "Check for Updates"
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            
            // Hide traffic lights
            newWindow.standardWindowButton(.closeButton)?.isHidden = true
            newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
            newWindow.standardWindowButton(.zoomButton)?.isHidden = true
            
            // Configure background and appearance
            newWindow.isMovableByWindowBackground = true
            newWindow.backgroundColor = .clear
            newWindow.isOpaque = false
            newWindow.hasShadow = true
            newWindow.isReleasedWhenClosed = false
            
            newWindow.delegate = self
            newWindow.contentView = hostingView
            
            self.window = newWindow
            
            // PREMIUM: Start scaled down and invisible for spring animation
            newWindow.alphaValue = 0
            if let contentView = newWindow.contentView {
                contentView.wantsLayer = true
                contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
                contentView.layer?.opacity = 0
            }
            
            // Bring to front and activate
            newWindow.orderFront(nil)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                newWindow.makeKeyAndOrderFront(nil)
            }
            
            // PREMIUM: CASpringAnimation for bouncy appear
            if let layer = newWindow.contentView?.layer {
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
                newWindow.animator().alphaValue = 1.0
            })
        }
    }
    
    func closeWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

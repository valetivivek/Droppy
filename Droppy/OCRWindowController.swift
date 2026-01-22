//
//  OCRWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import AppKit
import SwiftUI

final class OCRWindowController: NSObject {
    static let shared = OCRWindowController()
    
    private(set) var window: NSPanel?
    
    private override init() {
        super.init()
    }
    
    func show(with text: String) {
        // If window already exists, close and recreate to ensure clean state
        close()
        
        let contentView = OCRResultView(text: text) { [weak self] in
            self?.close()
        }
        .preferredColorScheme(.dark) // Force dark mode always
        let hostingView = NSHostingView(rootView: contentView)
        
        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newWindow.center()
        newWindow.title = "Extracted Text"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        
        newWindow.isMovableByWindowBackground = false
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .screenSaver
        newWindow.hidesOnDeactivate = false
        
        newWindow.contentView = hostingView
        
        // PREMIUM: Start scaled down and invisible for spring animation
        newWindow.alphaValue = 0
        if let contentView = newWindow.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            contentView.layer?.opacity = 0
        }
        
        // Show - use deferred makeKey to avoid NotchWindow conflicts
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
        
        self.window = newWindow
    }
    
    func close() {
        guard let panel = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.close()
            self?.window = nil
        })
    }
}

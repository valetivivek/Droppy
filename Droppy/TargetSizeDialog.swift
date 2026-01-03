//
//  TargetSizeDialog.swift
//  Droppy
//
//  Created by Jordy Spruit on 03/01/2026.
//

import SwiftUI
import AppKit

/// A dialog for entering a target file size for compression
struct TargetSizeDialogView: View {
    let currentSize: Int64
    let fileName: String
    let onCompress: (Int64) -> Void
    let onCancel: () -> Void
    
    @State private var targetSizeMB: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue.gradient)
                
                VStack(alignment: .leading) {
                    Text("Compress File")
                        .font(.headline)
                    Text(fileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Current size info
            HStack {
                Text("Current Size:")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(FileCompressor.formatSize(currentSize))
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Target size input
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Size (MB)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    TextField("e.g. 2.5", text: $targetSizeMB)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            compress()
                        }
                    
                    Text("MB")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(isTextFieldFocused ? 0.5 : 0), lineWidth: 2)
                )
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
                
                Button("Compress") {
                    compress()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(targetBytes == nil || targetBytes! >= currentSize)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            // Default to 50% of current size
            let suggestedMB = Double(currentSize) / (1024 * 1024) / 2
            targetSizeMB = String(format: "%.1f", suggestedMB)
            isTextFieldFocused = true
        }
    }
    
    private var targetBytes: Int64? {
        guard let mb = Double(targetSizeMB.replacingOccurrences(of: ",", with: ".")),
              mb > 0 else {
            return nil
        }
        return Int64(mb * 1024 * 1024)
    }
    
    private func compress() {
        guard let bytes = targetBytes else { return }
        onCompress(bytes)
    }
}

/// Window controller for showing the target size dialog
class TargetSizeDialogController {
    static let shared = TargetSizeDialogController()
    
    private var window: NSWindow?
    private var continuation: CheckedContinuation<Int64?, Never>?
    
    private init() {}
    
    /// Shows the dialog and returns the target size in bytes, or nil if cancelled
    @MainActor
    func show(currentSize: Int64, fileName: String) async -> Int64? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            let dialogView = TargetSizeDialogView(
                currentSize: currentSize,
                fileName: fileName,
                onCompress: { [weak self] bytes in
                    self?.dismiss(result: bytes)
                },
                onCancel: { [weak self] in
                    self?.dismiss(result: nil)
                }
            )
            
            let hostingView = NSHostingView(rootView: dialogView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 280)
            
            let window = NSPanel(
                contentRect: hostingView.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            window.contentView = hostingView
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .floating
            window.isMovableByWindowBackground = true
            
            // Center on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.frame
                let x = (screenFrame.width - 320) / 2
                let y = (screenFrame.height - 280) / 2
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            self.window = window
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func dismiss(result: Int64?) {
        window?.close()
        window = nil
        continuation?.resume(returning: result)
        continuation = nil
    }
}

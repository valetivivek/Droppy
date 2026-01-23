//
//  DropZoneIcon.swift
//  Droppy
//
//  Premium animated icons for drop zones - subtle and refined.
//

import SwiftUI

/// Premium drop zone icon with subtle hover animations
/// Clean, minimal, and professional look
struct DropZoneIcon: View {
    enum IconType {
        case shelf      // Main drop zone - tray icon
        case airDrop    // AirDrop zone - wireless icon
    }
    
    let type: IconType
    let size: CGFloat
    let isActive: Bool  // Whether files are currently hovering over
    
    var body: some View {
        iconContent
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.08 : 1.0)
            .opacity(isActive ? 1.0 : 0.5)
            .animation(DroppyAnimation.expandOpen, value: isActive)
    }
    
    // MARK: - Icon Content
    
    @ViewBuilder
    private var iconContent: some View {
        switch type {
        case .shelf:
            // Clean tray icon for drop zone
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(shelfGradient)
                .symbolRenderingMode(.hierarchical)
            
        case .airDrop:
            // Real AirDrop-style icon (matches settings tooltip)
            Image(systemName: "airplayaudio")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(airDropGradient)
                .symbolRenderingMode(.hierarchical)
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconSize: CGFloat {
        size * 0.5
    }
    
    private var shelfGradient: LinearGradient {
        LinearGradient(
            colors: isActive 
                ? [Color.white, Color(red: 0.85, green: 0.92, blue: 1.0)]
                : [Color.white.opacity(0.8), Color.white.opacity(0.5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var airDropGradient: LinearGradient {
        LinearGradient(
            colors: isActive
                ? [Color.white, Color(red: 0.7, green: 0.88, blue: 1.0)]
                : [Color.white.opacity(0.8), Color.white.opacity(0.5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview("Drop Zone Icons") {
    HStack(spacing: 40) {
        VStack {
            DropZoneIcon(type: .shelf, size: 50, isActive: false)
            Text("Drop (idle)")
                .font(.caption)
        }
        VStack {
            DropZoneIcon(type: .shelf, size: 50, isActive: true)
            Text("Drop (active)")
                .font(.caption)
        }
        VStack {
            DropZoneIcon(type: .airDrop, size: 50, isActive: false)
            Text("AirDrop (idle)")
                .font(.caption)
        }
        VStack {
            DropZoneIcon(type: .airDrop, size: 50, isActive: true)
            Text("AirDrop (active)")
                .font(.caption)
        }
    }
    .padding(40)
    .background(Color.black)
}

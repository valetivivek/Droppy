//
//  LockScreenHUDView.swift
//  Droppy
//
//  Created by Droppy on 13/01/2026.
//  Lock/Unlock HUD - icon only, centered in Dynamic Island
//

import SwiftUI

/// Compact Lock Screen HUD that sits inside the notch
/// Shows just the lock icon - centered in Dynamic Island, left wing in notch mode
struct LockScreenHUDView: View {
    @ObservedObject var lockScreenManager: LockScreenManager
    let notchWidth: CGFloat   // Physical notch width
    let notchHeight: CGFloat  // Physical notch height
    let hudWidth: CGFloat     // Total HUD width
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Lock icon based on state
    private var lockIcon: String {
        lockScreenManager.lastEvent == .unlocked ? "lock.open.fill" : "lock.fill"
    }
    
    /// Whether we're in Dynamic Island mode
    private var isDynamicIslandMode: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Centered icon only
                Image(systemName: lockIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolVariant(.fill)
                    .frame(width: 20, height: 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Icon on left wing only
                HStack(spacing: 0) {
                    // Left wing: Lock icon near left edge
                    HStack {
                        Image(systemName: lockIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolVariant(.fill)
                            .frame(width: 26, height: 26)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: Empty
                    Spacer()
                        .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        LockScreenHUDView(
            lockScreenManager: LockScreenManager.shared,
            notchWidth: 180,
            notchHeight: 32,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}

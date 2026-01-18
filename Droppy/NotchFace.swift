//
//  NotchFace.swift
//  Droppy
//
//  Minimal animated face for the shelf when empty.
//  Reacts to hover to invite users to drop files.
//

import SwiftUI

/// Minimal face with blinking eyes that reacts to hover
struct NotchFace: View {
    @State private var isBlinking = false
    @State private var blinkTimer: Timer?
    var size: CGFloat = 30
    var isExcited: Bool = false  // When files are being dragged/hovered
    
    var body: some View {
        VStack(spacing: isExcited ? 3 : 4) {
            // Eyes - get bigger when excited
            HStack(spacing: isExcited ? 6 : 4) {
                Eye(isBlinking: isBlinking && !isExcited, isExcited: isExcited)
                Eye(isBlinking: isBlinking && !isExcited, isExcited: isExcited)
            }
            
            // Nose and mouth
            VStack(spacing: 2) {
                // Nose
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 3, height: 4)
                
                // Mouth - opens wider when excited
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        if isExcited {
                            // Open mouth (surprised/excited)
                            path.addEllipse(in: CGRect(x: width * 0.2, y: 0, width: width * 0.6, height: height))
                        } else {
                            // Normal smile
                            path.move(to: CGPoint(x: 0, y: height / 2))
                            path.addQuadCurve(
                                to: CGPoint(x: width, y: height / 2),
                                control: CGPoint(x: width / 2, y: height)
                            )
                        }
                    }
                    .fill(isExcited ? Color.white : Color.clear)
                    .overlay(
                        Path { path in
                            if !isExcited {
                                let width = geometry.size.width
                                let height = geometry.size.height
                                path.move(to: CGPoint(x: 0, y: height / 2))
                                path.addQuadCurve(
                                    to: CGPoint(x: width, y: height / 2),
                                    control: CGPoint(x: width / 2, y: height)
                                )
                            }
                        }
                        .stroke(Color.white, lineWidth: 2)
                    )
                }
                .frame(width: isExcited ? 10 : 14, height: isExcited ? 8 : 10)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isExcited ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isExcited)
        .onAppear {
            startBlinking()
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
    }
    
    private func startBlinking() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            withAnimation(.spring(duration: 0.2)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(duration: 0.2)) {
                    isBlinking = false
                }
            }
        }
    }
}

/// Single eye that blinks and gets excited
private struct Eye: View {
    var isBlinking: Bool
    var isExcited: Bool = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
            .frame(
                width: isExcited ? 5 : 4,
                height: isBlinking ? 1 : (isExcited ? 5 : 4)
            )
            .frame(maxWidth: 15, maxHeight: 15)
            .animation(.easeInOut(duration: 0.1), value: isBlinking)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isExcited)
    }
}

#Preview {
    HStack(spacing: 40) {
        ZStack {
            Color.black
            VStack {
                Text("Normal").foregroundStyle(.gray).font(.caption)
                NotchFace(size: 40, isExcited: false)
            }
        }
        .frame(width: 80, height: 80)
        
        ZStack {
            Color.black
            VStack {
                Text("Excited").foregroundStyle(.gray).font(.caption)
                NotchFace(size: 40, isExcited: true)
            }
        }
        .frame(width: 80, height: 80)
    }
}

//
//  VoiceTranscribeCard.swift
//  Droppy
//
//  Voice Transcribe extension card for Settings extensions grid
//

import SwiftUI

struct VoiceTranscribeCard: View {
    @StateObject private var manager = VoiceTranscribeManager.shared
    @State private var showInfoSheet = false
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // Icon from remote URL
                AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.blue)
                    default:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(white: 0.2))
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Spacer()
                
                // Stats row: installs + rating + badge
                HStack(spacing: 8) {
                    // Installs (always visible)
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text("\(installCount ?? 0)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    // Rating (always visible)
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption2.weight(.medium))
                        } else {
                            Text("–")
                                .font(.caption2.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                    
                    // Category badge
                    Text("AI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Transcribe")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Record and transcribe audio instantly using local AI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status / Action row
            HStack {
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(manager.isModelDownloaded ? Color.blue : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(manager.isModelDownloaded ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 3)
                        )
                    
                    Text(manager.isModelDownloaded ? "Ready" : "Setup Required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Open button
                Button {
                    showInfoSheet = true
                } label: {
                    Text("Open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(height: 180)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showInfoSheet) {
            VoiceTranscribeInfoView(installCount: installCount, rating: rating)
        }
    }
}

#Preview {
    VoiceTranscribeCard()
        .frame(width: 260)
        .padding()
        .background(Color.black)
}

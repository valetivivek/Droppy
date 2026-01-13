//
//  VoiceTranscribeInfoView.swift
//  Droppy
//
//  Voice Transcribe extension info sheet with recording UI
//

import SwiftUI

struct VoiceTranscribeInfoView: View {
    @StateObject private var manager = VoiceTranscribeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var showReviewsSheet = false
    @State private var showModelPicker = false
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Content
            contentSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action Buttons
            buttonSection
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .voiceTranscribe)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon with recording animation
            ZStack {
                // Pulse animation while recording
                if case .recording = manager.state {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .scaleEffect(manager.audioLevel + 0.8)
                        .animation(.easeOut(duration: 0.1), value: manager.audioLevel)
                }
                
                // Main icon
                AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "waveform.and.mic").font(.system(size: 32)).foregroundStyle(.blue)
                    default:
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: stateColor.opacity(0.4), radius: 8, y: 4)
            }
            
            Text(stateTitle)
                .font(.title2.bold())
                .foregroundStyle(stateColor)
            
            // Stats row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                        } else {
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Text("AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.15)))
            }
            
            Text("Transcribe audio using local AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var stateTitle: String {
        switch manager.state {
        case .idle: return "Voice Transcribe"
        case .recording: return "Recording..."
        case .processing: return "Transcribing..."
        case .complete: return "Transcription Complete"
        case .error: return "Error"
        }
    }
    
    private var stateColor: Color {
        switch manager.state {
        case .idle: return .white
        case .recording: return .red
        case .processing: return .orange
        case .complete: return .green
        case .error: return .red
        }
    }
    
    // MARK: - Content
    
    private var contentSection: some View {
        VStack(spacing: 16) {
            switch manager.state {
            case .idle:
                idleContent
            case .recording:
                recordingContent
            case .processing:
                processingContent
            case .complete:
                completeContent
            case .error(let message):
                errorContent(message)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private var idleContent: some View {
        VStack(spacing: 16) {
            // Model selector
            HStack {
                Text("Model")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Menu {
                    ForEach(WhisperModel.allCases) { model in
                        Button {
                            manager.selectedModel = model
                        } label: {
                            HStack {
                                Text(model.displayName)
                                if manager.selectedModel == model {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(manager.selectedModel.displayName)
                            .font(.callout.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .menuStyle(.borderlessButton)
            }
            
            // Language selector
            HStack {
                Text("Language")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Menu {
                    ForEach(manager.supportedLanguages, id: \.code) { lang in
                        Button {
                            manager.selectedLanguage = lang.code
                        } label: {
                            HStack {
                                Text(lang.name)
                                if manager.selectedLanguage == lang.code {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(manager.supportedLanguages.first { $0.code == manager.selectedLanguage }?.name ?? "Auto")
                            .font(.callout.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .menuStyle(.borderlessButton)
            }
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "cpu", text: "100% on-device processing")
                featureRow(icon: "lock.fill", text: "Audio never leaves your Mac")
                featureRow(icon: "globe", text: "99+ languages supported")
            }
            .padding(.top, 8)
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var recordingContent: some View {
        VStack(spacing: 16) {
            // Duration
            Text(manager.formattedDuration)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundStyle(.red)
            
            // Waveform visualization
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 4)
                        .frame(height: CGFloat.random(in: 10...40) * CGFloat(manager.audioLevel + 0.3))
                        .animation(.easeOut(duration: 0.1), value: manager.audioLevel)
                }
            }
            .frame(height: 50)
            
            Text("Tap Stop when finished")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var processingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Transcribing audio...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
    }
    
    private var completeContent: some View {
        VStack(spacing: 12) {
            // Transcription result
            ScrollView {
                Text(manager.transcriptionResult)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 150)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Copy button
            Button {
                manager.copyToClipboard()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy to Clipboard")
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(isHoveringCancel ? 0.15 : 0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringCancel = h
                }
            }
            
            Spacer()
            
            // Main action button
            Button {
                manager.toggleRecording()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(actionTitle)
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(actionColor.opacity(isHoveringAction ? 1.0 : 0.85))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(case: manager.state, is: .processing)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringAction = h
                }
            }
        }
        .padding(16)
    }
    
    private var actionIcon: String {
        switch manager.state {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .processing: return "hourglass"
        case .complete, .error: return "arrow.counterclockwise"
        }
    }
    
    private var actionTitle: String {
        switch manager.state {
        case .idle: return "Start Recording"
        case .recording: return "Stop"
        case .processing: return "Processing..."
        case .complete, .error: return "New Recording"
        }
    }
    
    private var actionColor: Color {
        switch manager.state {
        case .idle: return .blue
        case .recording: return .red
        case .processing: return .gray
        case .complete: return .blue
        case .error: return .orange
        }
    }
}

// Helper for disabled button
extension View {
    func disabled(case state: RecordingState, is targetState: RecordingState) -> some View {
        self.disabled({
            if case targetState = state { return true }
            return false
        }())
    }
}

#Preview {
    VoiceTranscribeInfoView()
        .frame(height: 500)
}

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String = "General"
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    
    // Background Hover Effect State
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    
    // For Fluid Sidebar Animation
    @Namespace private var animationNamespace
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Structural Glass Sidebar
            VStack(alignment: .leading, spacing: 12) {
                Text("SETTINGS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 16)
                    .padding(.top, 20)
                
                Group {
                    SidebarItem(title: "General", icon: "gear", selection: $selectedTab, namespace: animationNamespace)
                    SidebarItem(title: "Display", icon: "display", selection: $selectedTab, namespace: animationNamespace)
                    SidebarItem(title: "What's New", icon: "sparkles", selection: $selectedTab, namespace: animationNamespace)
                    SidebarItem(title: "About", icon: "info.circle", selection: $selectedTab, namespace: animationNamespace)
                }
                
                Spacer()
            }
            .frame(width: 200)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundStyle(.white.opacity(0.1)),
                alignment: .trailing
            )
            
            // MARK: - Liquid Content Area
            ZStack {
                // Dynamic Background
                HexagonDotsEffect(
                    mouseLocation: hoverLocation,
                    isHovering: isHovering,
                    coordinateSpaceName: "settingsContent"
                )
                .opacity(0.5) // Subtle background
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if selectedTab == "General" {
                            generalSettings
                        } else if selectedTab == "Display" {
                            displaySettings
                        } else if selectedTab == "What's New" {
                            changelogSettings
                        } else if selectedTab == "About" {
                            aboutSettings
                        }
                    }
                    .padding(30)
                }
            }
            .coordinateSpace(name: "settingsContent")
            .onContinuousHover(coordinateSpace: .named("settingsContent")) { phase in
                switch phase {
                case .active(let location):
                    hoverLocation = location
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHovering = true
                    }
                case .ended:
                    withAnimation(.linear(duration: 0.2)) {
                        isHovering = false
                    }
                }
            }
        }
        .frame(width: 700, height: 450) // Fixed size for custom window feel
        .background(Color.black.opacity(0.2)) // Darker window backing
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - Sidebar Item Component
    struct SidebarItem: View {
        let title: String
        let icon: String
        @Binding var selection: String
        var namespace: Namespace.ID
        
        var isSelected: Bool { selection == title }
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : .secondary)
                
                Text(title)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(isSelected ? .white : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.8))
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "SidebarSelection", in: namespace)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    selection = title
                }
            }
        }
    }
    
    // MARK: - Content Sections WITH Liquid Design
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.largeTitle.weight(.bold))
            
            VStack(spacing: 16) {
                ToggleRow(title: "Menu Bar Icon", subtitle: "Show Droppy in the menu bar", isOn: $showInMenuBar)
                
                ToggleRow(title: "Startup", subtitle: "Start automatically at login", isOn: Binding(
                    get: { startAtLogin },
                    set: { newValue in
                        startAtLogin = newValue
                        LaunchAtLoginManager.setLaunchAtLogin(enabled: newValue)
                    }
                ))
            }
        }
    }
    
    private var displaySettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Display")
                .font(.largeTitle.weight(.bold))
            
            VStack(spacing: 16) {
                ToggleRow(title: "Transparent Background", subtitle: "Make the shelf and notch transparent", isOn: $useTransparentBackground)
            }
        }
    }
    
    private var changelogSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "party.popper.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.purple.gradient)
                VStack(alignment: .leading) {
                    Text("What's New")
                        .font(.largeTitle.weight(.bold))
                }
            }
            
            // Prism Card for Changelog
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey(ChangelogData.current))
                    .font(.body)
                    .lineSpacing(4)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            // The Prism Border
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.6), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.4),
                                .init(color: .purple.opacity(0.3), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
    
    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About")
                .font(.largeTitle.weight(.bold))
            
            VStack(alignment: .center, spacing: 20) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
                    .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                
                Text("Droppy")
                    .font(.title.bold())
                
                Text("Version \(UpdateChecker.shared.currentVersion)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Created by Jordy Spruit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                LiquidButton(title: "Check for Updates", icon: "arrow.triangle.2.circlepath") {
                    UpdateChecker.shared.checkAndNotify()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .liquidGlass(radius: 24, depth: 1.0)
        }
    }
    
    // Helper Component for Toggles in Liquid Style
    struct ToggleRow: View {
        let title: String
        let subtitle: String
        @Binding var isOn: Bool
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
            }
            .padding(16)
            .liquidGlass(radius: 16, depth: 0.5)
        }
    }
}

// MARK: - Changelog Data
struct ChangelogData {
    // This string is automatically updated by the release script
    static let current = """
### 🧺 The Floating Basket
*   **Jiggle to Reveal**: Give your mouse a little jiggle while dragging to summon the basket.
*   **Drag & Drop**: Drop files in to hold them, drag them out when ready.
*   **Push to Shelf**: Move items to the main shelf with one click.

### ⚡ Power Tools
*   **Smart Zipping**: Auto-renames new ZIP files.
*   **Instant ZIP**: Create archives instantly from selection.
*   **OCR**: Extract text from images/PDFs.
*   **Conversion**: Convert images (HEIC, PNG, JPEG) on the fly.

### 🎨 Refined Experience
*   **Sonoma Ready**: Fully compatible with macOS 14+.
*   **Smoother Animations**: Polished interactions.
*   **Fix**: Closing the Settings window no longer quits the app.
"""
}

// MARK: - Launch Handler
struct LaunchAtLoginManager {
    static func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.register()
                }
            } else {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
}


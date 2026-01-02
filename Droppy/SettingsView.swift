import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String? = "General"
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    
    // Background Hover Effect State
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    
    var body: some View {
        ZStack {
            // Interactive background effect
            HexagonDotsEffect(
                mouseLocation: hoverLocation,
                isHovering: isHovering,
                coordinateSpaceName: "settingsView"
            )
            
            NavigationSplitView {
                List(selection: $selectedTab) {
                    Label("General", systemImage: "gear")
                        .tag("General")
                    Label("Display", systemImage: "display")
                        .tag("Display")
                    Label("About Droppy", systemImage: "info.circle")
                        .tag("About Droppy")
                }
                .navigationTitle("Settings")
                // Fix: Use compatible background modifer
                .background(Color.clear) 
            } detail: {
                Form {
                    if selectedTab == "General" {
                        generalSettings
                    } else if selectedTab == "Display" {
                        displaySettings
                    } else if selectedTab == "About Droppy" {
                        aboutSettings
                    }
                }
                .formStyle(.grouped)
                // Fix: Use compatible background modifier
                .background(Color.clear)
            }
        }
        .coordinateSpace(name: "settingsView")
        // Fix: Replace visionOS glassEffect with macOS material
        .background(.ultraThinMaterial)
        .onContinuousHover(coordinateSpace: .named("settingsView")) { phase in
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
    
    // MARK: - Sections
    
    private var generalSettings: some View {
        Section {
            Toggle(isOn: $showInMenuBar) {
                VStack(alignment: .leading) {
                    Text("Menu Bar Icon")
                    Text("Show Droppy in the menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle(isOn: Binding(
                get: { startAtLogin },
                set: { newValue in
                    startAtLogin = newValue
                    LaunchAtLoginManager.setLaunchAtLogin(enabled: newValue)
                }
            )) {
                VStack(alignment: .leading) {
                    Text("Startup")
                    Text("Start automatically at login")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("General")
        } footer: {
            Text("Basic settings for the application.")
        }
    }
    
    private var displaySettings: some View {
        Section {
            Toggle(isOn: $useTransparentBackground) {
                VStack(alignment: .leading) {
                    Text("Transparent Background")
                    Text("Make the shelf and notch transparent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Display")
        }
    }
    
    private var aboutSettings: some View {
        Section {
            HStack {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
                
                VStack(alignment: .leading) {
                    Text("Droppy")
                        .font(.headline)
                    Text("Version \(UpdateChecker.shared.currentVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            
            LabeledContent("Developer", value: "Jordy Spruit")
            
            Button {
                UpdateChecker.shared.checkAndNotify()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Check for Updates")
                }
            }
        } header: {
            Text("About")
        }
    }
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

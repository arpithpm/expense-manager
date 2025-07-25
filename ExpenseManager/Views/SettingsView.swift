import SwiftUI
import Foundation

struct SettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var showingConfigurationSheet = false
    @State private var showingClearAlert = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            List {
                connectionStatusSection
                configurationSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingConfigurationSheet) {
            ReconfigurationView()
                .environmentObject(configurationManager)
        }
        .alert("Clear Configuration", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                configurationManager.clearConfiguration()
                showingSuccessAlert = true
            }
        } message: {
            Text("This will remove all stored API credentials. You'll need to reconfigure them to use the app.")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Configuration cleared successfully.")
        }
    }
    
    private var connectionStatusSection: some View {
        Section("Connection Status") {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.accentColor)
                Text("API Connections")
                Spacer()
                connectionStatusIndicator
            }
            
            if case .failure(let error) = configurationManager.connectionStatus {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
            
            Button("Test Connections") {
                Task {
                    await configurationManager.testConnections()
                }
            }
            .disabled(configurationManager.isTestingConnection)
        }
    }
    
    private var connectionStatusIndicator: some View {
        Group {
            switch configurationManager.connectionStatus {
            case .notTested:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
            case .testing:
                ProgressView()
                    .scaleEffect(0.8)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var configurationSection: some View {
        Section("Configuration") {
            Button(action: {
                showingConfigurationSheet = true
            }) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.accentColor)
                    Text("Reconfigure APIs")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: {
                showingClearAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Clear Configuration")
                }
            }
            .foregroundColor(.red)
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.accentColor)
                Text("Database")
                Spacer()
                Text("Supabase")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.accentColor)
                Text("AI Service")
                Spacer()
                Text("OpenAI Vision")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ReconfigurationView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @Environment(\.dismiss) private var dismiss
    @State private var supabaseUrl: String = ""
    @State private var supabaseKey: String = ""
    @State private var openaiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    configurationForm
                    testConnectionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Reconfigure APIs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveConfiguration()
                        }
                    }
                    .disabled(isFieldsEmpty || isProcessing || !isConnectionSuccessful)
                }
            }
        }
        .onAppear {
            loadCurrentConfiguration()
        }
        .alert("Configuration", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var configurationForm: some View {
        VStack(spacing: 20) {
            GroupBox("Supabase Configuration") {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supabase URL")
                            .font(.headline)
                        TextField("https://xxx.supabase.co", text: $supabaseUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supabase Anon Key")
                            .font(.headline)
                        SecureField("eyJhbGciOiJIUzI1NiIsInR5cCI6...", text: $supabaseKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox("OpenAI Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    SecureField("sk-proj-...", text: $openaiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 8)
            }
            
            Button("Test Connections") {
                Task {
                    await testConnections()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isFieldsEmpty || isProcessing)
        }
    }
    
    private var testConnectionSection: some View {
        Group {
            if configurationManager.isTestingConnection {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing connections...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                switch configurationManager.connectionStatus {
                case .notTested:
                    EmptyView()
                case .testing:
                    EmptyView()
                case .success:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All connections successful!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding()
                case .failure(let error):
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                }
            }
        }
    }
    
    private var isFieldsEmpty: Bool {
        supabaseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        supabaseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        openaiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isConnectionSuccessful: Bool {
        if case .success = configurationManager.connectionStatus {
            return true
        }
        return false
    }
    
    private func loadCurrentConfiguration() {
        supabaseUrl = configurationManager.getSupabaseUrl() ?? ""
        supabaseKey = configurationManager.getSupabaseKey() ?? ""
        openaiKey = configurationManager.getOpenAIKey() ?? ""
    }
    
    private func testConnections() async {
        isProcessing = true
        
        let success = await configurationManager.saveConfiguration(
            supabaseUrl: supabaseUrl,
            supabaseKey: supabaseKey,
            openaiKey: openaiKey
        )
        
        if success {
            await configurationManager.testConnections()
        } else {
            alertMessage = "Failed to save configuration temporarily for testing"
            showingAlert = true
        }
        
        isProcessing = false
    }
    
    private func saveConfiguration() async {
        isProcessing = true
        
        let success = await configurationManager.saveConfiguration(
            supabaseUrl: supabaseUrl,
            supabaseKey: supabaseKey,
            openaiKey: openaiKey
        )
        
        if success {
            alertMessage = "Configuration updated successfully!"
        } else {
            alertMessage = "Failed to update configuration. Please try again."
        }
        
        showingAlert = true
        isProcessing = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(ConfigurationManager())
}
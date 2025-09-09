import SwiftUI
import Foundation

struct ConfigurationView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var openaiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    @State private var validationError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    configurationForm
                    testConnectionSection
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Configuration", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear.badge")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Welcome to ReceiptRadar")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Configure your OpenAI API key to get started with AI-powered receipt processing")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var configurationForm: some View {
        VStack(spacing: 20) {
            GroupBox("OpenAI Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    SecureField("sk-proj-...", text: $openaiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: openaiKey) { _, newValue in
                            validateOpenAIKey(newValue)
                        }
                    
                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }
                    
                    Text("Required for AI-powered receipt processing. Data is stored locally on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Model: GPT-4o")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    Text("Cost-effective receipt processing with excellent accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var testConnectionSection: some View {
        Group {
            if configurationManager.isTestingConnection {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing connection...")
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
                        Text("OpenAI connection successful!")
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
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Test Connection") {
                Task {
                    await testConnections()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isFieldsEmpty || isProcessing || validationError != nil)
            
            Button("Save Configuration") {
                Task {
                    await saveConfiguration()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isFieldsEmpty || isProcessing || !isConnectionSuccessful || validationError != nil)
        }
    }
    
    private var isFieldsEmpty: Bool {
        openaiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func validateOpenAIKey(_ key: String) {
        let sanitized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        if sanitized.isEmpty {
            validationError = "API key cannot be empty"
            return
        }
        
        // Check minimum length
        if sanitized.count < 10 {
            validationError = "API key appears to be too short"
            return
        }
        
        // Check maximum length
        if sanitized.count > 200 {
            validationError = "API key appears to be too long"
            return
        }
        
        // Check for valid OpenAI key format
        if !sanitized.hasPrefix("sk-") {
            validationError = "OpenAI API key should start with 'sk-'"
            return
        }
        
        // Check for only allowed characters
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if sanitized.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            validationError = "API key contains invalid characters"
            return
        }
        
        // Valid
        validationError = nil
    }
    
    private var isConnectionSuccessful: Bool {
        if case .success = configurationManager.connectionStatus {
            return true
        }
        return false
    }
    
    private func testConnections() async {
        isProcessing = true
        
        // Validate input before processing
        let sanitizedKey = openaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate key format
        if sanitizedKey.isEmpty {
            alertMessage = "API key cannot be empty"
            showingAlert = true
            isProcessing = false
            return
        }
        
        if sanitizedKey.count < 10 {
            alertMessage = "API key appears to be too short"
            showingAlert = true
            isProcessing = false
            return
        }
        
        if !sanitizedKey.hasPrefix("sk-") {
            alertMessage = "OpenAI API key should start with 'sk-'"
            showingAlert = true
            isProcessing = false
            return
        }
        
        let success = await configurationManager.saveConfiguration(
            openaiKey: sanitizedKey
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
        
        // Validate input before processing
        let sanitizedKey = openaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate key format
        if sanitizedKey.isEmpty {
            alertMessage = "API key cannot be empty"
            showingAlert = true
            isProcessing = false
            return
        }
        
        if sanitizedKey.count < 10 {
            alertMessage = "API key appears to be too short"
            showingAlert = true
            isProcessing = false
            return
        }
        
        if !sanitizedKey.hasPrefix("sk-") {
            alertMessage = "OpenAI API key should start with 'sk-'"
            showingAlert = true
            isProcessing = false
            return
        }
        
        let success = await configurationManager.saveConfiguration(
            openaiKey: sanitizedKey
        )
        
        if success {
            alertMessage = "Configuration saved successfully!"
        } else {
            alertMessage = "Failed to save configuration. Please try again."
        }
        
        showingAlert = true
        isProcessing = false
    }
}

#Preview {
    ConfigurationView()
        .environmentObject(ConfigurationManager())
}
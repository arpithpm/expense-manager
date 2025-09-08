import Foundation
import Combine

class ConfigurationManager: ObservableObject {
    @Published var isConfigured: Bool = false
    @Published var isTestingConnection: Bool = false
    @Published var connectionStatus: ConnectionStatus = .notTested
    
    private let keychain = KeychainService.shared
    
    enum ConnectionStatus {
        case notTested, testing, success, failure(String)
    }
    
    init() {
        checkConfiguration()
    }
    
    private func checkConfiguration() {
        let hasOpenAIKey = keychain.retrieve(for: .openaiKey) != nil
        isConfigured = hasOpenAIKey
    }
    
    func saveConfiguration(openaiKey: String) async -> Bool {
        let trimmedOpenAIKey = openaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedOpenAIKey.isEmpty else {
            return false
        }
        
        let openaiKeySaved = keychain.save(trimmedOpenAIKey, for: .openaiKey)
        
        if openaiKeySaved {
            checkConfiguration()
            return true
        }
        return false
    }
    
    func testConnections() async {
        connectionStatus = .testing
        isTestingConnection = true
        
        let openaiResult = await testOpenAIConnection()
        
        isTestingConnection = false
        
        if openaiResult.success {
            connectionStatus = .success
        } else {
            connectionStatus = .failure(openaiResult.error ?? "Unknown error")
        }
    }
    
    
    private func testOpenAIConnection() async -> (success: Bool, error: String?) {
        guard let key = keychain.retrieve(for: .openaiKey),
              let url = URL(string: "https://api.openai.com/v1/models") else {
            return (false, "Invalid OpenAI credentials")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return (true, nil)
                } else if httpResponse.statusCode == 401 {
                    return (false, "Invalid OpenAI API key")
                } else {
                    return (false, "OpenAI connection failed (Status: \(httpResponse.statusCode))")
                }
            }
            return (false, "Invalid response from OpenAI")
        } catch {
            return (false, "OpenAI connection error: \(error.localizedDescription)")
        }
    }
    
    func clearConfiguration() {
        _ = keychain.deleteAll()
        checkConfiguration()
        connectionStatus = .notTested
    }
    
    func getOpenAIKey() -> String? { keychain.retrieve(for: .openaiKey) }
}
import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    private let service = "com.yourcompany.ExpenseManager"
    
    enum KeychainKey: String {
        case openaiKey = "openai_key"
    }
    
    func save(_ value: String, for key: KeychainKey) -> Bool {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func retrieve(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    func delete(for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    func deleteAll() -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // Convenience methods for API key management
    func saveAPIKey(_ key: String) -> Bool {
        return save(key, for: .openaiKey)
    }
    
    func getAPIKey() -> String? {
        return retrieve(for: .openaiKey)
    }
    
    func deleteAPIKey() throws {
        let success = delete(for: .openaiKey)
        if !success {
            throw NSError(domain: "KeychainError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete API key from keychain"])
        }
    }
    
    func hasValidAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}
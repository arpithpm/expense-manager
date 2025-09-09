import Foundation

public struct InputValidator {
    
    // MARK: - OpenAI API Key Validation
    
    public static func validateOpenAIKey(_ key: String) -> ValidationResult {
        let trimmed = sanitizeText(key)
        
        // Check if empty
        if trimmed.isEmpty {
            return .invalid("API key cannot be empty")
        }
        
        // Check minimum length
        if trimmed.count < 10 {
            return .invalid("API key appears to be too short")
        }
        
        // Check maximum length (OpenAI keys are typically around 51 characters)
        if trimmed.count > 200 {
            return .invalid("API key appears to be too long")
        }
        
        // Check for valid OpenAI key format (starts with sk-)
        if !trimmed.hasPrefix("sk-") {
            return .invalid("OpenAI API key should start with 'sk-'")
        }
        
        // Check for only allowed characters (alphanumeric, hyphens, underscores)
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if trimmed.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            return .invalid("API key contains invalid characters")
        }
        
        return .valid(trimmed)
    }
    
    // MARK: - Text Sanitization
    
    public static func sanitizeText(_ text: String) -> String {
        // Remove leading and trailing whitespace
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove null characters and other control characters except necessary ones
        let filtered = trimmed.filter { char in
            !char.isASCII || (char.isASCII && (char.isPrintable || char.isWhitespace))
        }
        
        return filtered
    }
    
    // MARK: - General Text Field Validation
    
    public static func validateTextField(_ text: String, minLength: Int = 0, maxLength: Int = 1000, allowEmpty: Bool = true) -> ValidationResult {
        let sanitized = sanitizeText(text)
        
        // Check if empty when not allowed
        if !allowEmpty && sanitized.isEmpty {
            return .invalid("Field cannot be empty")
        }
        
        // Check minimum length
        if sanitized.count < minLength {
            return .invalid("Text must be at least \(minLength) characters")
        }
        
        // Check maximum length
        if sanitized.count > maxLength {
            return .invalid("Text cannot exceed \(maxLength) characters")
        }
        
        return .valid(sanitized)
    }
    
    // MARK: - Expense-specific Validation
    
    public static func validateMerchantName(_ name: String) -> ValidationResult {
        let sanitized = sanitizeText(name)
        
        if sanitized.isEmpty {
            return .invalid("Merchant name cannot be empty")
        }
        
        if sanitized.count > 100 {
            return .invalid("Merchant name cannot exceed 100 characters")
        }
        
        // Prevent potential injection attempts
        let forbiddenPatterns = ["<script", "javascript:", "data:", "vbscript:"]
        for pattern in forbiddenPatterns {
            if sanitized.lowercased().contains(pattern) {
                return .invalid("Invalid merchant name format")
            }
        }
        
        return .valid(sanitized)
    }
    
    public static func validateExpenseDescription(_ description: String) -> ValidationResult {
        let sanitized = sanitizeText(description)
        
        // Allow empty descriptions
        if sanitized.isEmpty {
            return .valid("")
        }
        
        if sanitized.count > 500 {
            return .invalid("Description cannot exceed 500 characters")
        }
        
        // Prevent potential injection attempts
        let forbiddenPatterns = ["<script", "javascript:", "data:", "vbscript:", "<?php"]
        for pattern in forbiddenPatterns {
            if sanitized.lowercased().contains(pattern) {
                return .invalid("Invalid description format")
            }
        }
        
        return .valid(sanitized)
    }
    
    public static func validateCategory(_ category: String) -> ValidationResult {
        let sanitized = sanitizeText(category)
        
        if sanitized.isEmpty {
            return .invalid("Category cannot be empty")
        }
        
        if sanitized.count > 50 {
            return .invalid("Category cannot exceed 50 characters")
        }
        
        // Only allow alphanumeric, spaces, and common symbols
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_&()"))
        if sanitized.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            return .invalid("Category contains invalid characters")
        }
        
        return .valid(sanitized)
    }
    
    public static func validatePaymentMethod(_ paymentMethod: String) -> ValidationResult {
        let sanitized = sanitizeText(paymentMethod)
        
        // Allow empty payment methods
        if sanitized.isEmpty {
            return .valid("")
        }
        
        if sanitized.count > 50 {
            return .invalid("Payment method cannot exceed 50 characters")
        }
        
        // Only allow alphanumeric, spaces, and common symbols
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        if sanitized.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            return .invalid("Payment method contains invalid characters")
        }
        
        return .valid(sanitized)
    }
    
    // MARK: - Numeric Validation
    
    public static func validateAmount(_ amountString: String) -> ValidationResult {
        let sanitized = sanitizeText(amountString)
        
        if sanitized.isEmpty {
            return .invalid("Amount cannot be empty")
        }
        
        // Try to parse as Double
        guard let amount = Double(sanitized) else {
            return .invalid("Amount must be a valid number")
        }
        
        // Check for reasonable bounds
        if amount < 0 {
            return .invalid("Amount cannot be negative")
        }
        
        if amount > 1_000_000 {
            return .invalid("Amount cannot exceed $1,000,000")
        }
        
        // Check decimal places (max 2)
        let decimalComponents = sanitized.split(separator: ".")
        if decimalComponents.count > 2 {
            return .invalid("Invalid amount format")
        }
        
        if decimalComponents.count == 2 && decimalComponents[1].count > 2 {
            return .invalid("Amount cannot have more than 2 decimal places")
        }
        
        return .valid(String(amount))
    }
}

// MARK: - Validation Result

public enum ValidationResult {
    case valid(String)
    case invalid(String)
    
    public var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    public var sanitizedValue: String? {
        switch self {
        case .valid(let value):
            return value
        case .invalid:
            return nil
        }
    }
    
    public var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        }
    }
}

// MARK: - Character Extensions

private extension Character {
    var isPrintable: Bool {
        return self.unicodeScalars.allSatisfy { scalar in
            CharacterSet.controlCharacters.inverted.contains(scalar)
        }
    }
}
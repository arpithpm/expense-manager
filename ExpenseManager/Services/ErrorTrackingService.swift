import Foundation
import UIKit

/// Enhanced error tracking and user-friendly error messaging
class ErrorTrackingService {
    static let shared = ErrorTrackingService()

    private let logger = LoggingService.shared
    private let userDefaults = UserDefaults.standard

    // Error statistics
    private let errorStatsKey = "ErrorStatistics"

    struct ErrorStats: Codable {
        var totalErrors: Int = 0
        var apiKeyErrors: Int = 0
        var networkErrors: Int = 0
        var openaiErrors: Int = 0
        var imageProcessingErrors: Int = 0
        var lastErrorDate: Date?
        var consecutiveFailures: Int = 0
        var mostCommonError: String = ""
    }

    private var errorStats: ErrorStats {
        get {
            if let data = userDefaults.data(forKey: errorStatsKey),
               let stats = try? JSONDecoder().decode(ErrorStats.self, from: data) {
                return stats
            }
            return ErrorStats()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: errorStatsKey)
            }
        }
    }

    private init() {}

    // MARK: - Error Tracking

    func trackError(_ error: Error, context: ReceiptProcessingContext) {
        let startTime = Date()

        // Update statistics
        var stats = errorStats
        stats.totalErrors += 1
        stats.lastErrorDate = Date()
        stats.consecutiveFailures += 1

        // Categorize and log the error
        let errorInfo = analyzeError(error, context: context)

        // Update category-specific counts
        switch errorInfo.category {
        case .apiKey:
            stats.apiKeyErrors += 1
        case .network:
            stats.networkErrors += 1
        case .openai:
            stats.openaiErrors += 1
        case .imageProcessing:
            stats.imageProcessingErrors += 1
        default:
            break
        }

        // Update most common error
        let errorCounts = [
            ("API_KEY", stats.apiKeyErrors),
            ("NETWORK", stats.networkErrors),
            ("OPENAI", stats.openaiErrors),
            ("IMAGE_PROCESSING", stats.imageProcessingErrors)
        ]
        stats.mostCommonError = errorCounts.max(by: { $0.1 < $1.1 })?.0 ?? "UNKNOWN"

        errorStats = stats

        // Log the error with full context
        logger.error(
            errorInfo.message,
            category: errorInfo.category,
            context: [
                "userFriendlyMessage": errorInfo.userMessage,
                "suggestions": errorInfo.suggestions.joined(separator: "; "),
                "isRecoverable": errorInfo.isRecoverable,
                "imageCount": context.imageCount,
                "hasAPIKey": context.hasAPIKey,
                "attemptNumber": context.attemptNumber,
                "totalErrors": stats.totalErrors,
                "consecutiveFailures": stats.consecutiveFailures
            ],
            error: error
        )

        logger.logPerformance(
            operation: "error_tracking",
            duration: Date().timeIntervalSince(startTime),
            success: true
        )
    }

    func trackSuccess() {
        // Reset consecutive failures on success
        var stats = errorStats
        stats.consecutiveFailures = 0
        errorStats = stats

        logger.info("Consecutive failure count reset", category: .unknown)
    }

    // MARK: - Error Analysis

    private func analyzeError(_ error: Error, context: ReceiptProcessingContext) -> ErrorInfo {
        if let openAIError = error as? OpenAIError {
            return analyzeOpenAIError(openAIError, context: context)
        } else if let expenseError = error as? ExpenseManagerError {
            return analyzeExpenseManagerError(expenseError, context: context)
        } else {
            return analyzeGenericError(error, context: context)
        }
    }

    private func analyzeOpenAIError(_ error: OpenAIError, context: ReceiptProcessingContext) -> ErrorInfo {
        switch error {
        case .missingAPIKey:
            return ErrorInfo(
                category: .apiKey,
                message: "OpenAI API key not found",
                userMessage: "Please configure your OpenAI API key to process receipts.",
                suggestions: [
                    "Go to Settings and add your OpenAI API key",
                    "Get an API key from https://openai.com/api"
                ],
                isRecoverable: true
            )
            
        case .invalidAPIKey:
            return ErrorInfo(
                category: .apiKey,
                message: "OpenAI API key is invalid or expired",
                userMessage: "API key issue detected. Please check your OpenAI configuration.",
                suggestions: [
                    "Verify your OpenAI API key in Settings",
                    "Ensure your OpenAI account has sufficient credits",
                    "Check if your API key has the correct permissions"
                ],
                isRecoverable: true
            )

        case .invalidURL:
            return ErrorInfo(
                category: .openai,
                message: "Invalid OpenAI API URL",
                userMessage: "Service configuration error. Please try again.",
                suggestions: [
                    "Try again in a few moments",
                    "Contact support if the problem persists"
                ],
                isRecoverable: true
            )

        case .requestEncodingFailed:
            return ErrorInfo(
                category: .openai,
                message: "Failed to encode request",
                userMessage: "Image couldn't be processed. Try with a different photo.",
                suggestions: [
                    "Take a new photo with better quality",
                    "Ensure the image isn't corrupted",
                    "Try with a smaller image file"
                ],
                isRecoverable: true
            )

        case .invalidResponse:
            return ErrorInfo(
                category: .openai,
                message: "Invalid response from OpenAI",
                userMessage: "Service temporarily unavailable. Please try again.",
                suggestions: [
                    "Try again in a few moments",
                    "Check OpenAI status if issues persist"
                ],
                isRecoverable: true
            )

        case .apiError(let statusCode):
            return handleOpenAIAPIError(statusCode: statusCode, context: context)

        case .noResponseContent:
            return ErrorInfo(
                category: .openai,
                message: "OpenAI returned empty response",
                userMessage: "The image couldn't be processed. Try with a clearer photo.",
                suggestions: [
                    "Ensure the receipt is clearly visible and well-lit",
                    "Make sure text on the receipt is readable",
                    "Try taking the photo from a different angle"
                ],
                isRecoverable: true
            )

        case .responseParsingFailed:
            return ErrorInfo(
                category: .openai,
                message: "Failed to parse OpenAI response",
                userMessage: "Processing failed due to an unexpected response format.",
                suggestions: [
                    "Try again with the same image",
                    "If the problem persists, try with a different receipt",
                    "Check if your OpenAI API key has proper permissions"
                ],
                isRecoverable: true
            )

        case .imageProcessingFailed:
            return ErrorInfo(
                category: .imageProcessing,
                message: "Failed to process image",
                userMessage: "Image couldn't be processed. Try with a different photo.",
                suggestions: [
                    "Take a new photo with better lighting",
                    "Ensure the image isn't corrupted",
                    "Try with a smaller image file"
                ],
                isRecoverable: true
            )

        case .responseTruncated:
            return ErrorInfo(
                category: .openai,
                message: "Response was truncated - try with a simpler receipt",
                userMessage: "Receipt was too complex to process completely.",
                suggestions: [
                    "Try with a simpler receipt",
                    "Crop the image to focus on key information",
                    "Try processing individual sections separately"
                ],
                isRecoverable: true
            )
        }
    }

    private func handleOpenAIAPIError(statusCode: Int, context: ReceiptProcessingContext) -> ErrorInfo {
        switch statusCode {
        case 400:
            return ErrorInfo(
                category: .openai,
                message: "OpenAI API bad request (400)",
                userMessage: "The image format may not be supported.",
                suggestions: [
                    "Try with a JPEG or PNG image",
                    "Ensure the image file isn't corrupted",
                    "Use a smaller image if the file is very large"
                ],
                isRecoverable: true
            )

        case 401:
            return ErrorInfo(
                category: .apiKey,
                message: "OpenAI API authentication failed (401)",
                userMessage: "Authentication failed. Please check your API key.",
                suggestions: [
                    "Update your OpenAI API key in Settings",
                    "Verify your API key is active and has credits"
                ],
                isRecoverable: true
            )

        case 429:
            return ErrorInfo(
                category: .openai,
                message: "OpenAI API rate limit exceeded (429)",
                userMessage: "Too many requests. Please wait a moment and try again.",
                suggestions: [
                    "Wait 1-2 minutes before trying again",
                    "Consider upgrading your OpenAI plan for higher limits"
                ],
                isRecoverable: true
            )

        case 500...599:
            return ErrorInfo(
                category: .openai,
                message: "OpenAI API server error (\(statusCode))",
                userMessage: "OpenAI service is temporarily unavailable.",
                suggestions: [
                    "Try again in a few minutes",
                    "Check OpenAI status page if issues persist"
                ],
                isRecoverable: true
            )

        default:
            return ErrorInfo(
                category: .openai,
                message: "OpenAI API error (\(statusCode))",
                userMessage: "Service temporarily unavailable. Please try again.",
                suggestions: ["Try again in a few moments"],
                isRecoverable: true
            )
        }
    }

    private func analyzeExpenseManagerError(_ error: ExpenseManagerError, context: ReceiptProcessingContext) -> ErrorInfo {
        switch error {
        case .apiKeyMissing:
            return ErrorInfo(
                category: .apiKey,
                message: "OpenAI API key is missing",
                userMessage: "Please configure your OpenAI API key to process receipts.",
                suggestions: [
                    "Go to Settings and add your OpenAI API key",
                    "Get an API key from https://openai.com/api"
                ],
                isRecoverable: true
            )

        case .imageProcessingFailed:
            return ErrorInfo(
                category: .imageProcessing,
                message: "Failed to process image data",
                userMessage: "Image couldn't be processed. Try with a different photo.",
                suggestions: [
                    "Take a new photo with better lighting",
                    "Ensure the image isn't corrupted",
                    "Try with a smaller image file"
                ],
                isRecoverable: true
            )

        case .networkError(let underlying):
            return ErrorInfo(
                category: .network,
                message: "Network error: \(underlying.localizedDescription)",
                userMessage: "Connection problem. Check your internet and try again.",
                suggestions: [
                    "Check your internet connection",
                    "Try connecting to a different network",
                    "Wait a moment and try again"
                ],
                isRecoverable: true
            )
            
        case .invalidAmount:
            return ErrorInfo(
                category: .unknown,
                message: "Invalid expense amount",
                userMessage: "The expense amount is invalid.",
                suggestions: ["Please check the amount and try again"],
                isRecoverable: true
            )
            
        case .invalidDate:
            return ErrorInfo(
                category: .unknown,
                message: "Invalid expense date",
                userMessage: "The expense date is invalid.",
                suggestions: ["Please check the date and try again"],
                isRecoverable: true
            )
            
        case .dataCorruption:
            return ErrorInfo(
                category: .unknown,
                message: "Data corruption detected",
                userMessage: "Some data appears to be corrupted.",
                suggestions: ["Please try again or contact support"],
                isRecoverable: false
            )
            
        case .persistenceError(let underlying):
            return ErrorInfo(
                category: .unknown,
                message: "Failed to save data: \(underlying.localizedDescription)",
                userMessage: "Failed to save your expense.",
                suggestions: ["Please try again", "Check available storage space"],
                isRecoverable: true
            )
            
        case .invalidExpenseData:
            return ErrorInfo(
                category: .unknown,
                message: "Invalid expense data",
                userMessage: "The expense data is invalid.",
                suggestions: ["Please check all fields and try again"],
                isRecoverable: true
            )
        }
    }

    private func analyzeGenericError(_ error: Error, context: ReceiptProcessingContext) -> ErrorInfo {
        let description = error.localizedDescription.lowercased()

        if description.contains("network") || description.contains("internet") || description.contains("connection") {
            return ErrorInfo(
                category: .network,
                message: "Network connectivity error",
                userMessage: "Connection problem. Please check your internet.",
                suggestions: [
                    "Verify your internet connection",
                    "Try again in a few moments"
                ],
                isRecoverable: true
            )
        }

        return ErrorInfo(
            category: .unknown,
            message: "Unexpected error: \(error.localizedDescription)",
            userMessage: "An unexpected error occurred. Please try again.",
            suggestions: [
                "Try again with the same image",
                "Restart the app if problems persist"
            ],
            isRecoverable: false
        )
    }

    // MARK: - User-Friendly Error Messages

    func getUserFriendlyErrorMessage(for error: Error, context: ReceiptProcessingContext) -> UserErrorMessage {
        let errorInfo = analyzeError(error, context: context)
        let stats = errorStats

        // Customize message based on error frequency
        let message = errorInfo.userMessage
        var suggestions = errorInfo.suggestions

        // Add context-based suggestions
        if stats.consecutiveFailures >= 3 {
            suggestions.insert("Multiple failures detected. Consider restarting the app.", at: 0)
        }

        if stats.apiKeyErrors > 5 && errorInfo.category == .apiKey {
            suggestions.append("Frequent API key issues suggest the key may need renewal.")
        }

        if stats.networkErrors > 3 && errorInfo.category == .network {
            suggestions.append("Frequent network issues detected. Check your connection stability.")
        }

        return UserErrorMessage(
            title: getErrorTitle(for: errorInfo.category),
            message: message,
            suggestions: suggestions,
            isRecoverable: errorInfo.isRecoverable,
            canRetry: errorInfo.isRecoverable && stats.consecutiveFailures < 5
        )
    }

    private func getErrorTitle(for category: LoggingService.ErrorCategory) -> String {
        switch category {
        case .apiKey:
            return "Configuration Issue"
        case .network:
            return "Connection Problem"
        case .openai:
            return "Processing Error"
        case .imageProcessing:
            return "Image Error"
        default:
            return "Processing Failed"
        }
    }

    // MARK: - Statistics and Insights

    func getErrorStatistics() -> ErrorStats {
        return errorStats
    }

    func hasRecentErrors(within hours: Int = 24) -> Bool {
        guard let lastError = errorStats.lastErrorDate else { return false }
        return Date().timeIntervalSince(lastError) < TimeInterval(hours * 3600)
    }

    func getHealthScore() -> Double {
        let stats = errorStats

        if stats.totalErrors == 0 { return 1.0 }

        // Calculate health based on recent success rate
        let recentErrorWeight = stats.consecutiveFailures > 0 ? 0.3 : 1.0
        let frequencyPenalty = min(Double(stats.totalErrors) / 100.0, 0.5)

        return max(0.0, recentErrorWeight - frequencyPenalty)
    }

    func resetStatistics() {
        errorStats = ErrorStats()
        logger.info("Error statistics reset", category: .configuration)
    }
}

// MARK: - Supporting Types

struct ReceiptProcessingContext {
    let imageCount: Int
    let hasAPIKey: Bool
    let attemptNumber: Int
    let timestamp: Date = Date()
}

struct ErrorInfo {
    let category: LoggingService.ErrorCategory
    let message: String
    let userMessage: String
    let suggestions: [String]
    let isRecoverable: Bool
}

struct UserErrorMessage {
    let title: String
    let message: String
    let suggestions: [String]
    let isRecoverable: Bool
    let canRetry: Bool

    var fullMessage: String {
        var result = message

        if !suggestions.isEmpty {
            result += "\n\nSuggestions:\n"
            result += suggestions.enumerated().map { "• \($1)" }.joined(separator: "\n")
        }

        return result
    }
}

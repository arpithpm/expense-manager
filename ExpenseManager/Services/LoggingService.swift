import Foundation
import UIKit
import os.log

/// Comprehensive logging and error tracking service for Receipt Radar
class LoggingService {
    static let shared = LoggingService()

    private let logger = Logger(subsystem: "com.muddi1.receiptradar", category: "main")
    private let fileManager = FileManager.default
    private let logsDirectory: URL

    // Log levels
    enum LogLevel: String, CaseIterable {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case critical = "🚨 CRITICAL"

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    // Error categories for better tracking
    enum ErrorCategory: String, CaseIterable {
        case apiKey = "API_KEY"
        case network = "NETWORK"
        case openai = "OPENAI"
        case imageProcessing = "IMAGE_PROCESSING"
        case dataStorage = "DATA_STORAGE"
        case userInput = "USER_INPUT"
        case configuration = "CONFIGURATION"
        case performance = "PERFORMANCE"
        case unknown = "UNKNOWN"
    }

    private init() {
        // Create logs directory in Documents
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        logsDirectory = documentsURL.appendingPathComponent("Logs")

        // Create logs directory if it doesn't exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }

        // Clean up old log files (keep last 7 days)
        cleanupOldLogs()

        info("LoggingService initialized", category: .configuration)
    }

    // MARK: - Public Logging Methods

    func debug(_ message: String, category: ErrorCategory = .unknown, context: [String: Any]? = nil) {
        log(message, level: .debug, category: category, context: context)
    }

    func info(_ message: String, category: ErrorCategory = .unknown, context: [String: Any]? = nil) {
        log(message, level: .info, category: category, context: context)
    }

    func warning(_ message: String, category: ErrorCategory = .unknown, context: [String: Any]? = nil) {
        log(message, level: .warning, category: category, context: context)
    }

    func error(_ message: String, category: ErrorCategory = .unknown, context: [String: Any]? = nil, error: Error? = nil) {
        var contextWithError = context ?? [:]
        if let error = error {
            contextWithError["error"] = error.localizedDescription
            contextWithError["errorType"] = String(describing: type(of: error))
        }
        log(message, level: .error, category: category, context: contextWithError)
    }

    func critical(_ message: String, category: ErrorCategory = .unknown, context: [String: Any]? = nil, error: Error? = nil) {
        var contextWithError = context ?? [:]
        if let error = error {
            contextWithError["error"] = error.localizedDescription
            contextWithError["errorType"] = String(describing: type(of: error))
        }
        log(message, level: .critical, category: category, context: contextWithError)
    }

    // MARK: - Specialized Logging Methods

    func logReceiptProcessingStart(imageCount: Int, hasAPIKey: Bool) {
        info("Started receipt processing", category: .openai, context: [
            "imageCount": imageCount,
            "hasAPIKey": hasAPIKey,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func logReceiptProcessingSuccess(merchant: String, amount: Double, currency: String, processingTime: TimeInterval) {
        info("Receipt processing successful", category: .openai, context: [
            "merchant": merchant,
            "amount": amount,
            "currency": currency,
            "processingTimeSeconds": processingTime,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func logReceiptProcessingFailure(error: Error, context: [String: Any]? = nil) {
        var errorContext = context ?? [:]
        errorContext["timestamp"] = Date().timeIntervalSince1970

        // Categorize the error
        let category: ErrorCategory
        if let openAIError = error as? OpenAIError {
            category = .openai
            errorContext["openaiErrorType"] = String(describing: openAIError)
        } else if let expenseError = error as? ExpenseManagerError {
            category = .apiKey // Most ExpenseManagerErrors are API key related
            errorContext["expenseErrorType"] = String(describing: expenseError)
        } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
            category = .network
        } else {
            category = .unknown
        }

        self.error("Receipt processing failed", category: category, context: errorContext, error: error)
    }

    func logOpenAIAPICall(requestSize: Int, responseCode: Int?, responseSize: Int? = nil) {
        info("OpenAI API call", category: .openai, context: [
            "requestSizeBytes": requestSize,
            "responseCode": responseCode ?? -1,
            "responseSizeBytes": responseSize ?? -1,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func logPerformance(operation: String, duration: TimeInterval, success: Bool) {
        info("Performance metric", category: .performance, context: [
            "operation": operation,
            "durationSeconds": duration,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    // MARK: - Private Methods

    private func log(_ message: String, level: LogLevel, category: ErrorCategory, context: [String: Any]?) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Create log entry
        var logEntry = "\(level.rawValue) [\(category.rawValue)] \(timestamp) - \(message)"

        // Add context if provided
        if let context = context, !context.isEmpty {
            let contextString = context.map { "\"\($0.key)\":\"\($0.value)\"" }.joined(separator: ", ")
            logEntry += " | Context: {\(contextString)}"
        }

        // Log to system logger
        logger.log(level: level.osLogType, "\(logEntry)")

        // Log to console in debug builds
        #if DEBUG
        print(logEntry)
        #endif

        // Write to file
        writeToFile(logEntry)

        // For critical errors, also trigger additional reporting
        if level == .critical {
            handleCriticalError(message, category: category, context: context)
        }
    }

    private func writeToFile(_ entry: String) {
        let today = DateFormatter().string(from: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let fileName = "receiptradar-\(dateFormatter.string(from: Date())).log"
        let fileURL = logsDirectory.appendingPathComponent(fileName)

        let logLine = entry + "\n"

        if fileManager.fileExists(atPath: fileURL.path) {
            // Append to existing file
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logLine.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            }
        } else {
            // Create new file
            try? logLine.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func handleCriticalError(_ message: String, category: ErrorCategory, context: [String: Any]?) {
        // In a production app, this could:
        // 1. Send to crash reporting service (Crashlytics, Sentry, etc.)
        // 2. Trigger user notification if appropriate
        // 3. Save additional diagnostic information

        debug("Critical error handled: \(message)", category: category, context: context)
    }

    private func cleanupOldLogs() {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])

            for fileURL in logFiles {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < sevenDaysAgo {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Failed to cleanup old logs: \(error)")
        }
    }

    // MARK: - Log Retrieval and Export

    func getTodaysLogFile() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "receiptradar-\(dateFormatter.string(from: Date())).log"
        let fileURL = logsDirectory.appendingPathComponent(fileName)

        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    func getAllLogFiles() -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = try? fileManager.attributesOfItem(atPath: file1.path)[.creationDate] as? Date ?? Date.distantPast
                    let date2 = try? fileManager.attributesOfItem(atPath: file2.path)[.creationDate] as? Date ?? Date.distantPast
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }
        } catch {
            return []
        }
    }

    func getRecentLogs(hours: Int = 24) -> String {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(hours * 3600))
        let dateFormatter = ISO8601DateFormatter()

        var recentLogs: [String] = []

        for logFile in getAllLogFiles() {
            do {
                let content = try String(contentsOf: logFile)
                let lines = content.components(separatedBy: .newlines)

                for line in lines {
                    // Extract timestamp and check if it's recent
                    if let timestampRange = line.range(of: #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"#, options: .regularExpression),
                       let timestamp = dateFormatter.date(from: String(line[timestampRange])),
                       timestamp > cutoffDate {
                        recentLogs.append(line)
                    }
                }
            } catch {
                continue
            }
        }

        return recentLogs.joined(separator: "\n")
    }

    func exportLogsForSupport() -> URL? {
        let exportURL = logsDirectory.appendingPathComponent("receiptradar-logs-export.txt")

        var exportContent = """
        Receipt Radar - Log Export
        Generated: \(Date())
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        Device: \(UIDevice.current.model) (\(UIDevice.current.systemName) \(UIDevice.current.systemVersion))

        Recent Logs (Last 24 Hours):
        ============================

        """

        exportContent += getRecentLogs(hours: 24)

        do {
            try exportContent.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            self.error("Failed to export logs", category: .dataStorage, error: error)
            return nil
        }
    }

    // MARK: - Error Analysis

    func getErrorSummary(hours: Int = 24) -> [String: Int] {
        let recentLogs = getRecentLogs(hours: hours)
        let lines = recentLogs.components(separatedBy: .newlines)

        var errorCounts: [String: Int] = [:]

        for line in lines {
            if line.contains("❌ ERROR") || line.contains("🚨 CRITICAL") {
                // Extract category
                if let categoryRange = line.range(of: #"\[([A-Z_]+)\]"#, options: .regularExpression) {
                    let category = String(line[categoryRange])
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                    errorCounts[category, default: 0] += 1
                }
            }
        }

        return errorCounts
    }
}
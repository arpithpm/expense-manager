import Foundation
import Combine
import UIKit
import SwiftUI

/// Manages automatic background AI analysis with caching and weekly refresh
class BackgroundAnalysisManager: ObservableObject {
    static let shared = BackgroundAnalysisManager()

    @Published var isBackgroundAnalysisAvailable = false
    @Published var lastBackgroundUpdate: Date?

    private let insightsService = SpendingInsightsService.shared
    private let expenseService = ExpenseService.shared
    private let logger = LoggingService.shared

    // Cache management
    private let cacheKey = "CachedSpendingInsights"
    private let lastUpdateKey = "LastInsightsUpdate"
    private let lastExpenseCountKey = "LastAnalyzedExpenseCount"

    // Weekly refresh interval (7 days)
    private let refreshInterval: TimeInterval = 7 * 24 * 60 * 60

    // Minimum expenses required for analysis
    private let minimumExpenseCount = 5

    private var cancellables = Set<AnyCancellable>()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private init() {
        loadCachedAnalysis()
        setupExpenseObserver()
        setupAppStateObserver()

        logger.info("BackgroundAnalysisManager initialized", category: .configuration, context: [
            "hasCachedAnalysis": isBackgroundAnalysisAvailable,
            "lastUpdate": lastBackgroundUpdate?.timeIntervalSince1970 ?? 0
        ])
    }

    // MARK: - Public Interface

    /// Starts background analysis if needed (called from app startup)
    func performBackgroundAnalysisIfNeeded() {
        Task {
            await performBackgroundAnalysisIfNeededAsync()
        }
    }

    /// Forces a background refresh (for manual triggers, but still silent)
    func forceBackgroundRefresh() {
        Task {
            await performBackgroundAnalysis(force: true)
        }
    }

    /// Gets cached analysis or nil if not available
    func getCachedAnalysis() -> SpendingInsights? {
        return insightsService.currentInsights
    }

    /// Checks if analysis should be refreshed
    var shouldRefreshAnalysis: Bool {
        guard let lastUpdate = lastBackgroundUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) >= refreshInterval
    }

    // MARK: - Private Methods

    private func performBackgroundAnalysisIfNeededAsync() async {
        logger.debug("Checking if background analysis is needed", category: .performance)

        // Check if we have enough expenses
        guard expenseService.expenses.count >= minimumExpenseCount else {
            logger.info("Insufficient expenses for analysis", category: .performance, context: [
                "expenseCount": expenseService.expenses.count,
                "required": minimumExpenseCount
            ])
            return
        }

        // Check if we need to refresh
        let shouldRefresh = shouldRefreshAnalysis
        let hasNewExpenses = hasSignificantExpenseChanges()

        guard shouldRefresh || hasNewExpenses || !isBackgroundAnalysisAvailable else {
            logger.debug("Background analysis not needed", category: .performance, context: [
                "shouldRefresh": shouldRefresh,
                "hasNewExpenses": hasNewExpenses,
                "hasAnalysis": isBackgroundAnalysisAvailable
            ])
            return
        }

        await performBackgroundAnalysis(force: false)
    }

    private func performBackgroundAnalysis(force: Bool) async {
        // Start background task to ensure completion
        await startBackgroundTask()

        logger.info("Starting background AI analysis", category: .performance, context: [
            "expenseCount": expenseService.expenses.count,
            "forced": force
        ])

        do {
            let startTime = Date()

            // Perform the analysis silently
            let insights = try await insightsService.analyzeSpending(expenses: expenseService.expenses)

            // Cache the results
            await MainActor.run {
                cacheAnalysisResults(insights)
                isBackgroundAnalysisAvailable = true
                lastBackgroundUpdate = Date()
            }

            let duration = Date().timeIntervalSince(startTime)
            logger.info("Background AI analysis completed successfully", category: .performance, context: [
                "duration": duration,
                "totalSavings": insights.savingsOpportunities.reduce(0) { $0 + $1.potentialSavings },
                "opportunityCount": insights.savingsOpportunities.count
            ])

        } catch {
            logger.error("Background AI analysis failed", category: .openai, context: [
                "expenseCount": expenseService.expenses.count,
                "errorType": String(describing: type(of: error))
            ], error: error)

            // Don't show user any error for background analysis
            // Just log it and continue silently
        }

        await endBackgroundTask()
    }

    private func hasSignificantExpenseChanges() -> Bool {
        let lastAnalyzedCount = UserDefaults.standard.integer(forKey: lastExpenseCountKey)
        let currentCount = expenseService.expenses.count

        // Consider it significant if there are 5+ new expenses or 20% increase
        let newExpenses = currentCount - lastAnalyzedCount
        let percentageIncrease = Double(newExpenses) / max(Double(lastAnalyzedCount), 1.0)

        return newExpenses >= 5 || percentageIncrease >= 0.2
    }

    // MARK: - Caching

    private func loadCachedAnalysis() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let insights = try? JSONDecoder().decode(SpendingInsights.self, from: data) {

            insightsService.currentInsights = insights
            isBackgroundAnalysisAvailable = true

            if let updateTimestamp = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date {
                lastBackgroundUpdate = updateTimestamp
            }

            logger.info("Loaded cached AI analysis", category: .dataStorage, context: [
                "savingsCount": insights.savingsOpportunities.count,
                "cacheAge": lastBackgroundUpdate?.timeIntervalSinceNow ?? 0
            ])
        }
    }

    private func cacheAnalysisResults(_ insights: SpendingInsights) {
        do {
            let data = try JSONEncoder().encode(insights)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
            UserDefaults.standard.set(expenseService.expenses.count, forKey: lastExpenseCountKey)

            logger.debug("Cached AI analysis results", category: .dataStorage, context: [
                "dataSize": data.count,
                "expenseCount": expenseService.expenses.count
            ])
        } catch {
            logger.error("Failed to cache analysis results", category: .dataStorage, error: error)
        }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: lastUpdateKey)
        UserDefaults.standard.removeObject(forKey: lastExpenseCountKey)

        isBackgroundAnalysisAvailable = false
        lastBackgroundUpdate = nil
        insightsService.currentInsights = nil

        logger.info("Cleared AI analysis cache", category: .dataStorage)
    }

    // MARK: - Observers

    private func setupExpenseObserver() {
        // Monitor expense changes to trigger analysis
        expenseService.$expenses
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] expenses in
                guard let self = self else { return }

                // If expenses change significantly, schedule background analysis
                if self.hasSignificantExpenseChanges() {
                    logger.debug("Significant expense changes detected, scheduling background analysis", category: .performance)

                    // Delay to avoid immediate analysis on app startup
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5) {
                        Task {
                            await self.performBackgroundAnalysisIfNeededAsync()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupAppStateObserver() {
        // Monitor app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.logger.debug("App entering foreground, checking for background analysis", category: .performance)

                // Check for analysis when app comes to foreground
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
                    self?.performBackgroundAnalysisIfNeeded()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.logger.debug("App entering background", category: .performance)
                // Could schedule background app refresh here if needed
            }
            .store(in: &cancellables)
    }

    // MARK: - Background Task Management

    @MainActor
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AIAnalysis") { [weak self] in
            self?.logger.warning("Background AI analysis task expired", category: .performance)
            self?.endBackgroundTaskSync()
        }
    }

    @MainActor
    private func endBackgroundTask() {
        endBackgroundTaskSync()
    }

    private func endBackgroundTaskSync() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Public Utilities

    /// Returns time until next scheduled refresh
    func timeUntilNextRefresh() -> TimeInterval? {
        guard let lastUpdate = lastBackgroundUpdate else { return nil }
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        let timeUntilRefresh = refreshInterval - timeSinceUpdate
        return timeUntilRefresh > 0 ? timeUntilRefresh : 0
    }

    /// Returns formatted string for next refresh time
    func nextRefreshDescription() -> String? {
        guard let timeUntil = timeUntilNextRefresh() else { return nil }

        if timeUntil <= 0 {
            return "Refresh available now"
        }

        let days = Int(timeUntil) / (24 * 60 * 60)
        let hours = Int(timeUntil.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60)

        if days > 0 {
            return "Refreshes in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "Refreshes in \(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "Refreshes soon"
        }
    }

    /// Manual cache management
    func clearAnalysisCache() {
        clearCache()
        logger.info("Manually cleared analysis cache", category: .configuration)
    }

    /// Get analysis freshness status
    var analysisFreshness: AnalysisFreshness {
        guard let lastUpdate = lastBackgroundUpdate else { return .none }

        let daysSinceUpdate = Date().timeIntervalSince(lastUpdate) / (24 * 60 * 60)

        if daysSinceUpdate < 1 { return .fresh }
        if daysSinceUpdate < 3 { return .recent }
        if daysSinceUpdate < 7 { return .stale }
        return .expired
    }
}

// MARK: - Supporting Types

enum AnalysisFreshness: String, CaseIterable {
    case none = "No Analysis"
    case fresh = "Fresh" // < 1 day
    case recent = "Recent" // 1-3 days
    case stale = "Stale" // 3-7 days
    case expired = "Expired" // > 7 days

    var color: Color {
        switch self {
        case .none: return .gray
        case .fresh: return .green
        case .recent: return .blue
        case .stale: return .orange
        case .expired: return .red
        }
    }
}

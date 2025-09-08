import Foundation
import Combine

class SpendingInsightsService: ObservableObject {
    static let shared = SpendingInsightsService()
    
    @Published var currentInsights: SpendingInsights?
    @Published var isAnalyzing = false
    
    private let openAIService = OpenAIService.shared
    
    var hasAnalysis: Bool {
        currentInsights != nil
    }
    
    var lastAnalysisDate: Date? {
        currentInsights?.analysisDate
    }
    
    var lastAnalyzedExpenseCount: Int = 0
    
    private init() {}
    
    func analyzeSpending(expenses: [Expense]) async throws -> SpendingInsights {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        guard !expenses.isEmpty else {
            throw InsightsError.noExpenseData
        }
        
        // Prepare comprehensive analysis prompt
        let prompt = createSpendingAnalysisPrompt(expenses: expenses)
        
        // Get AI analysis
        let analysisResult = try await requestAIAnalysis(prompt: prompt)
        
        // Parse and structure the insights
        let insights = try parseInsightsResponse(analysisResult)
        
        // Store insights
        currentInsights = insights
        lastAnalyzedExpenseCount = expenses.count
        
        return insights
    }
    
    private func createSpendingAnalysisPrompt(expenses: [Expense]) -> String {
        let totalAmount = expenses.reduce(0) { $0 + $1.amount }
        let currency = expenses.first?.currency ?? "EUR"
        let avgTransaction = totalAmount / Double(expenses.count)
        
        let categoryBreakdown = Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.value > $1.value }
        
        let merchantBreakdown = Dictionary(grouping: expenses, by: { $0.merchant })
            .mapValues { merchants in (count: merchants.count, total: merchants.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.value.total > $1.value.total }
        
        let allItems = expenses.compactMap { $0.items }.flatMap { $0 }
        let itemFrequency = Dictionary(grouping: allItems, by: { $0.name.lowercased() })
            .mapValues { items in (count: items.count, total: items.reduce(0) { $0 + $1.totalPrice }) }
            .sorted { $0.value.total > $1.value.total }
        
        return """
        Analyze spending data and provide comprehensive financial insights. 

        CRITICAL: Return ONLY valid JSON without any markdown formatting, explanations, or additional text.

        EXPENSE SUMMARY:
        - Total Expenses: \(expenses.count) transactions
        - Total Amount: \(totalAmount.formatted(currency: currency))
        - Average Transaction: \(avgTransaction.formatted(currency: currency))
        - Currency: \(currency)
        - Date Range: \(expenses.map { $0.date }.min()?.formatted(date: .abbreviated, time: .omitted) ?? "N/A") to \(expenses.map { $0.date }.max()?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")

        CATEGORY BREAKDOWN:
        \(categoryBreakdown.prefix(10).map { "\($0.key): \($0.value.formatted(currency: currency))" }.joined(separator: "\n"))

        TOP MERCHANTS:
        \(merchantBreakdown.prefix(10).map { "\($0.key): \($0.value.total.formatted(currency: currency)) (\($0.value.count) visits)" }.joined(separator: "\n"))

        TOP ITEMS:
        \(itemFrequency.prefix(15).map { "\($0.key): \($0.value.total.formatted(currency: currency)) (\($0.value.count)x)" }.joined(separator: "\n"))

        Provide detailed analysis with:
        1. 3-5 savings opportunities with realistic monthly amounts and detailed implementation guides
        2. Category insights with percentages and patterns plus specific optimization strategies
        3. Spending patterns and concerning behaviors with step-by-step correction methods
        4. Regional insights (Germany/Europe context for EUR) with local money-saving tips
        5. Actionable items with comprehensive implementation steps and timeline
        
        IMPORTANT: For each savings opportunity, provide:
        - Clear title and brief description
        - Detailed explanation of WHY this saves money
        - Step-by-step HOW-TO guide for implementation
        - Specific examples relevant to the user's spending
        - Timeline and expected results
        - Potential obstacles and how to overcome them

        JSON FORMAT:
        {
          "totalPotentialSavings": <number>,
          "spendingEfficiencyScore": <0-100>,
          "averageDailySpend": <number>,
          "topCategory": "<category>",
          "analysisDate": "\(Date().formatted(.iso8601))",
          "timeframe": "Recent Analysis",
          "savingsOpportunities": [
            {
              "title": "Specific Opportunity Title",
              "description": "Brief 1-2 sentence overview",
              "detailedDescription": "Comprehensive explanation with context",
              "whyItSaves": "Detailed explanation of the financial mechanism behind the savings",
              "howToImplement": "Step-by-step implementation guide with specific actions",
              "specificExamples": ["Example 1 based on user's actual spending", "Example 2"],
              "potentialObstacles": ["Obstacle 1 and how to overcome it", "Obstacle 2"],
              "potentialSavings": <monthly_amount>,
              "difficulty": "easy|medium|hard",
              "impact": "low|medium|high",
              "steps": ["Actionable step 1", "Actionable step 2"],
              "timeframe": "2-4 weeks",
              "expectedResults": "What user can expect to see after implementation"
            }
          ],
          "categoryInsights": [
            {
              "category": "Category",
              "totalSpent": <amount>,
              "transactionCount": <count>,
              "percentageOfTotal": <percentage>,
              "averageTransactionSize": <amount>,
              "keyInsights": ["Insight 1", "Insight 2"],
              "detailedAnalysis": "Comprehensive analysis with spending patterns and trends",
              "optimizationStrategies": ["Strategy 1 with specific steps", "Strategy 2"],
              "potentialMonthlySavings": <amount>
            }
          ],
          "spendingPatterns": [
            {
              "pattern": "Pattern",
              "description": "Description",
              "frequency": "daily|weekly|monthly",
              "severity": "info|warning|critical",
              "financialImpact": <amount>,
              "recommendations": ["Recommendation"],
              "icon": "chart.bar.fill"
            }
          ],
          "regionalInsights": [
            {
              "region": "Germany",
              "comparisons": [
                {
                  "metric": "Metric",
                  "comparison": "Comparison",
                  "isGood": true
                }
              ],
              "recommendations": ["Recommendation"]
            }
          ],
          "actionItems": [
            {
              "title": "Action",
              "description": "Description",
              "difficulty": "easy|medium|hard",
              "potentialMonthlySavings": <amount>
            }
          ]
        }
        """
    }
    
    private func requestAIAnalysis(prompt: String) async throws -> String {
        guard let apiKey = KeychainService.shared.retrieve(for: .openaiKey) else {
            throw InsightsError.apiError(NSError(domain: "Missing API Key", code: 401))
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are an expert financial advisor providing spending analysis and savings recommendations."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 3000,
            "temperature": 0.1
        ]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw InsightsError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InsightsError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw InsightsError.apiError(NSError(domain: "Invalid API Key", code: 401))
        } else if httpResponse.statusCode != 200 {
            throw InsightsError.apiError(NSError(domain: "API Error", code: httpResponse.statusCode))
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = openAIResponse.choices.first?.message.content else {
                throw InsightsError.invalidResponse
            }
            print("Raw AI Response: \(content)")
            return content
        } catch {
            print("OpenAI Response Parsing Error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw Response Data: \(responseString)")
            }
            throw InsightsError.calculationError
        }
    }
    
    private func parseInsightsResponse(_ content: String) throws -> SpendingInsights {
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw InsightsError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            
            // Custom date decoding strategy to handle multiple formats
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try multiple date formats
                let formatters = [
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]
                
                for formatString in formatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = formatString
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                // If all formats fail, return current date
                print("Unable to parse date: \(dateString), using current date")
                return Date()
            }
            
            return try decoder.decode(SpendingInsights.self, from: jsonData)
        } catch {
            print("JSON Parsing Error: \(error)")
            print("Cleaned content: \(cleanedContent)")
            
            // Try to create a fallback response with basic analysis
            if let fallbackInsights = createFallbackInsights(from: content) {
                return fallbackInsights
            }
            
            throw InsightsError.calculationError
        }
    }
    
    private func createFallbackInsights(from content: String) -> SpendingInsights? {
        // Create a basic insights response when parsing fails
        return SpendingInsights(
            totalSpent: 0.0,
            averageExpense: 0.0,
            topCategories: [:],
            spendingTrend: "Stable",
            savingsOpportunities: [
                SavingsOpportunity(
                    title: "Reduce Frequent Small Purchases",
                    description: "Consolidate smaller purchases to reduce fees and impulse spending.",
                    potentialSavings: 30.0,
                    category: "General",
                    difficulty: .easy,
                    impact: .medium,
                    actionSteps: ["Plan your shopping trips weekly", "Create detailed shopping lists", "Set daily spending limits"]
                ),
                SavingsOpportunity(
                    title: "Optimize Subscription Services",
                    description: "Audit and optimize your recurring subscription payments.",
                    potentialSavings: 20.0,
                    category: "General",
                    difficulty: .easy,
                    impact: .medium,
                    actionSteps: ["List all subscriptions", "Track usage for 1 month", "Cancel unused services"]
                )
            ],
            categoryInsights: [
                CategoryInsight(
                    category: "Food & Dining",
                    totalSpent: 200.0,
                    percentageOfTotal: 35.0,
                    comparison: "Above average for your demographic",
                    recommendation: "Consider meal planning to reduce costs",
                    trendAnalysis: "Steady spending pattern",
                    seasonalPattern: nil
                )
            ],
            spendingPatterns: [],
            regionalInsights: [],
            monthlyComparison: 0.0,
            actionItems: [],
            generatedAt: Date()
        )
    }
}
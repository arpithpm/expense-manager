import SwiftUI
import CoreData

// Use legacy ExpenseService as bridge to CoreDataExpenseService

struct SpendingInsightsView: View {
    @ObservedObject private var expenseService = ExpenseService.coreDataService
    @ObservedObject private var insightsService = SpendingInsightsService.shared
    @State private var isAnalyzing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with analysis trigger
                    analysisHeader
                    
                    if insightsService.hasAnalysis {
                        // Quick Stats
                        quickStatsSection
                        
                        // Savings Opportunities
                        savingsOpportunitiesSection
                        
                        // Category Insights
                        if let insights = insightsService.currentInsights {
                            categoryInsightsSection(insights.categoryInsights)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Analysis Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var analysisHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("AI Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Get personalized insights on your spending patterns and discover opportunities to save money")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            
            if !insightsService.hasAnalysis || expenseService.expenses.count > insightsService.lastAnalyzedExpenseCount {
                Button(action: {
                    Task {
                        await performAnalysis()
                    }
                }) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Analyzing spending...")
                        } else {
                            Image(systemName: "sparkles")
                            Text(insightsService.hasAnalysis ? "Update Analysis" : "Analyze My Spending")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.purple, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(isAnalyzing || expenseService.expenses.isEmpty)
            }
            
            if let lastAnalysis = insightsService.lastAnalysisDate {
                Text("Last analyzed: \(lastAnalysis, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var quickStatsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Key Metrics")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InsightMetricCard(
                    title: "Potential Monthly Savings",
                    value: insightsService.currentInsights?.totalSpent ?? 0,
                    currency: expenseService.getPrimaryCurrency(),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                InsightMetricCard(
                    title: "Average Daily Spending",
                    value: insightsService.currentInsights?.averageExpense ?? 0,
                    currency: expenseService.getPrimaryCurrency(),
                    icon: "gauge.high",
                    color: .blue
                )
            }
        }
    }
    
    private var savingsOpportunitiesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("💰 Savings Opportunities")
                    .font(.headline)
                Spacer()
            }
            
            if let opportunities = insightsService.currentInsights?.savingsOpportunities {
                LazyVStack(spacing: 12) {
                    ForEach(Array(opportunities.enumerated()), id: \.offset) { index, opportunity in
                        DetailedSavingsOpportunityCard(opportunity: opportunity, rank: index + 1)
                    }
                }
            }
        }
    }
    
    private func categoryInsightsSection(_ insights: [CategoryInsight]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("📊 Category Analysis")
                    .font(.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(insights, id: \.category) { insight in
                    CategoryInsightCard(insight: insight)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("Ready to Analyze Your Spending?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("I'll analyze your expenses to find patterns, identify savings opportunities, and provide personalized recommendations.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if expenseService.expenses.isEmpty {
                VStack(spacing: 8) {
                    Text("No expenses found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Add some expenses first to get insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 40)
    }
    
    private func performAnalysis() async {
        isAnalyzing = true
        
        do {
            let insights = try await insightsService.analyzeSpending(expenses: expenseService.expenses)
            
            if insights.totalSpent > 0 {
                alertMessage = "Analysis complete! Found insights about your spending patterns."
            } else {
                alertMessage = "Analysis complete! Your spending looks efficient, but I found some interesting patterns."
            }
            showingAlert = true
        } catch {
            alertMessage = "Analysis failed: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isAnalyzing = false
    }
}

// MARK: - Supporting Views

struct InsightMetricCard: View {
    let title: String
    let value: Double
    let currency: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Text(formatValue())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func formatValue() -> String {
        if currency == "%" {
            return String(format: "%.0f%%", value)
        } else {
            return value.formatted(currency: currency)
        }
    }
}

struct DetailedSavingsOpportunityCard: View {
    let opportunity: SavingsOpportunity
    let rank: Int
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(rankColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Text("\(rank)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(opportunity.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("💸 \(opportunity.potentialSavings.formatted(currency: "EUR"))/month")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Text(opportunity.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(isExpanded ? nil : 2)
                        
                        HStack {
                            Text(opportunity.difficulty.rawValue.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(opportunity.difficulty.color.opacity(0.2))
                                )
                                .foregroundColor(opportunity.difficulty.color)
                            
                            Text(opportunity.impact.rawValue.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(opportunity.impact.color.opacity(0.2))
                                )
                                .foregroundColor(opportunity.impact.color)
                            
                            Spacer()
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Action Steps
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Action Steps", systemImage: "list.bullet")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            ForEach(Array(opportunity.actionSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(step)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(rankColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .green
        case 2: return .orange  
        case 3: return .blue
        default: return .gray
        }
    }
}

struct SavingsOpportunityCard: View {
    let opportunity: SavingsOpportunity
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(opportunity.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text("💸 \(opportunity.potentialSavings.formatted(currency: "EUR"))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Text(opportunity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                HStack {
                    Text(opportunity.difficulty.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(opportunity.difficulty.color.opacity(0.2))
                        )
                        .foregroundColor(opportunity.difficulty.color)
                    
                    Spacer()
                    
                    Text(opportunity.impact.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(opportunity.impact.color.opacity(0.2))
                        )
                        .foregroundColor(opportunity.impact.color)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(rankColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .green
        case 2: return .orange
        case 3: return .blue
        default: return .gray
        }
    }
}

struct CategoryInsightCard: View {
    let insight: CategoryInsight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(insight.totalSpent.formatted(currency: "EUR"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(insight.percentageOfTotal, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("of total spending")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(categoryColor)
                                .frame(width: geometry.size.width * (insight.percentageOfTotal / 100), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack {
                        Text("💡 \(insight.recommendation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Comparison
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Analysis", systemImage: "chart.bar.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            Text(insight.comparison)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // Trend Analysis
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Trend Analysis", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                            
                            Text(insight.trendAnalysis)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    private var categoryColor: Color {
        switch insight.category {
        case "Food & Dining": return .orange
        case "Transportation": return .blue
        case "Shopping": return .purple
        case "Entertainment": return .pink
        case "Bills & Utilities": return .yellow
        case "Healthcare": return .red
        case "Travel": return .green
        case "Education": return .indigo
        case "Business": return .brown
        default: return .gray
        }
    }
}
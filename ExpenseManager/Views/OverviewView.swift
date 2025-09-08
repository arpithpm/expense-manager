import SwiftUI
import PhotosUI
import Foundation
import CoreData

// Use legacy ExpenseService as bridge to CoreDataExpenseService

struct OverviewView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @ObservedObject private var expenseService = ExpenseService.coreDataService
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isProcessingReceipts = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false
    
    // Animation states
    @State private var shimmerOffset: CGFloat = -1
    @State private var iconRotation: Double = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var shimmerTimer: Timer?
    
    @Binding var selectedTab: Int
    // Computed properties that automatically update when expenseService.expenses changes
    private var totalExpenses: Double {
        expenseService.getTotalInPrimaryCurrency()
    }
    
    private var monthlyTotal: Double {
        expenseService.getMonthlyTotalInPrimaryCurrency()
    }
    
    // Additional animation states for other elements
    @State private var addButtonScale: CGFloat = 1.0
    @State private var addButtonRotation: Double = 0
    @State private var cameraButtonPulse: Bool = false
    @State private var scanningAnimation: Bool = false
    @State private var glowIntensity: Double = 0.0
    @State private var photoSelectionOffset: CGFloat = 0
    
    private var recentExpenses: [Expense] {
        Array(expenseService.expenses.sorted { $0.date > $1.date }.prefix(5))
    }
    
    // Animation functions
    private func startAnimations() {
        // Initial shimmer animation - starts immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.linear(duration: 1.5)) {
                shimmerOffset = 1.3
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                shimmerOffset = -1
            }
        }
        
        // Shimmer animation - repeats every 4 seconds with proper cleanup
        shimmerTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.linear(duration: 1.5)) {
                shimmerOffset = 1.3
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                shimmerOffset = -1
            }
        }
        
        // Icon rotation animation - gentle continuous rotation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            iconRotation = 360
        }
        
        // Subtle breathing animation for cards
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            cardScale = 1.01
        }
    }
    
    private var customAppHeader: some View {
        HStack(spacing: 12) {
            // Animated radar icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .scaleEffect(cardScale)
                
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(iconRotation))
            }
            
            // App name with shimmer animation
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    // "Receipt" with shimmer effect
                    Text("Receipt")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .overlay(
                            // Shimmer overlay
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: shimmerOffset - 0.3),
                                    .init(color: .white.opacity(0.8), location: shimmerOffset),
                                    .init(color: .clear, location: shimmerOffset + 0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .blendMode(.overlay)
                        )
                        .mask(
                            Text("Receipt")
                                .font(.title)
                                .fontWeight(.bold)
                        )
                    
                    // "Radar" with shimmer effect
                    Text("Radar")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            // Shimmer overlay
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: shimmerOffset - 0.3),
                                    .init(color: .white.opacity(0.6), location: shimmerOffset),
                                    .init(color: .clear, location: shimmerOffset + 0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .blendMode(.overlay)
                        )
                        .mask(
                            Text("Radar")
                                .font(.title)
                                .fontWeight(.bold)
                        )
                    
                    Text("1")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.1))
                        )
                        .scaleEffect(cardScale)
                }
                
                Text("Smart Expense Tracking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 8)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            shimmerTimer?.invalidate()
            shimmerTimer = nil
        }
    }
    
    private var demoBanner: some View {
        VStack(spacing: 0) {
            if expenseService.hasDemoData() {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Demo Mode")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("Clear Demo Data") {
                                withAnimation(.spring(duration: 0.5)) {
                                    expenseService.clearDemoData()
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        }
                        
                        Text("You're viewing sample expenses to explore the app. Clear this data to start tracking your own expenses.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    customAppHeader
                        .transition(.opacity.combined(with: .slide))
                    
                    demoBanner
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    
                    summaryCards
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    
                    addReceiptSection
                        .transition(.opacity.combined(with: .scale))
                    
                    recentExpensesSection
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .animation(.easeInOut(duration: 0.6), value: expenseService.expenses.count)
            }
            .navigationBarHidden(true)
            .refreshable {
                // Data refreshes automatically through @Published properties
                // Add haptic feedback for pull to refresh
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }
        .onAppear {
            // Expenses are automatically loaded from ExpenseService init
        }
        .alert("Processing Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Delete Expense", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    try? expenseService.deleteExpense(expense)
                    expenseToDelete = nil
                }
            }
        } message: {
            if let expense = expenseToDelete {
                Text("Are you sure you want to delete the expense from \(expense.merchant) for \(expense.formattedAmount)?")
            }
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            if !newValue.isEmpty {
                Task {
                    await processSelectedPhotos()
                }
            }
        }
    }
    
    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            SummaryCard(
                title: "This Month",
                amount: expenseService.getMonthlyTotalInPrimaryCurrency(),
                icon: "calendar",
                color: .blue,
                currency: expenseService.getPrimaryCurrency()
            )
            
            SummaryCard(
                title: "Total Expenses",
                amount: expenseService.getTotalInPrimaryCurrency(),
                icon: "dollarsign.circle",
                color: .green,
                currency: expenseService.getPrimaryCurrency()
            )
        }
    }
    
    private var addReceiptSection: some View {
        VStack(spacing: 20) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                    Text("Add New Expenses")
                        .font(.headline)
                }
                Spacer()
            }
            
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                ZStack {
                    // Background with gradient and glow effect
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.15),
                                    Color.accentColor.opacity(0.25),
                                    Color.accentColor.opacity(0.15)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.accentColor.opacity(0.5),
                                            Color.accentColor.opacity(0.8),
                                            Color.accentColor.opacity(0.3)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.accentColor.opacity(glowIntensity), radius: 10, x: 0, y: 0)
                        .scaleEffect(addButtonScale)
                    
                    // Animated scanning lines (when processing)
                    if isProcessingReceipts {
                        ZStack {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(height: 2)
                                .offset(y: scanningAnimation ? 30 : -30)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: scanningAnimation)
                            
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(height: 1)
                                .offset(y: scanningAnimation ? 20 : -40)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scanningAnimation)
                        }
                        .mask(RoundedRectangle(cornerRadius: 18))
                    }
                    
                    // Main content
                    HStack(spacing: 16) {
                        // Camera icon with animations
                        ZStack {
                            // Pulsing background circle
                            Circle()
                                .fill(Color.accentColor.opacity(cameraButtonPulse ? 0.3 : 0.1))
                                .frame(width: 60, height: 60)
                                .scaleEffect(cameraButtonPulse ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: cameraButtonPulse)
                            
                            if isProcessingReceipts {
                                // Processing state - animated dots
                                HStack(spacing: 4) {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 6, height: 6)
                                            .scaleEffect(scanningAnimation ? 1.5 : 0.5)
                                            .animation(
                                                .easeInOut(duration: 0.6)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(index) * 0.2),
                                                value: scanningAnimation
                                            )
                                    }
                                }
                            } else {
                                // Camera icon with flash effect
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.accentColor)
                                    .scaleEffect(addButtonScale * (cameraButtonPulse ? 1.05 : 1.0))
                                    .rotationEffect(.degrees(addButtonRotation))
                                    .overlay(
                                        // Flash effect
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundColor(.white)
                                            .opacity(glowIntensity)
                                            .scaleEffect(1.2)
                                            .blur(radius: 4)
                                    )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isProcessingReceipts ? "Processing Receipts..." : "Select Receipt Photos")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    if isProcessingReceipts {
                                        Text("AI is analyzing your receipts")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Tap to scan receipts with AI")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Animated arrow or processing indicator
                                if isProcessingReceipts {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .tint(.accentColor)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.accentColor)
                                        .scaleEffect(addButtonScale)
                                        .rotationEffect(.degrees(addButtonRotation * 0.1))
                                }
                            }
                            
                            // Feature highlights
                            if !isProcessingReceipts {
                                HStack(spacing: 12) {
                                    Label("AI-Powered", systemImage: "brain.head.profile")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                    
                                    Label("Multi-Photo", systemImage: "square.stack.3d.up.fill")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                    
                                    Label("Instant", systemImage: "bolt.fill")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .frame(minHeight: 100)
            }
            .disabled(isProcessingReceipts)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    addButtonScale = pressing ? 0.96 : 1.0
                    glowIntensity = pressing ? 0.4 : 0.0
                }
            }, perform: {})
            .onTapGesture {
                // Enhanced camera button animation on tap
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                    addButtonRotation += 360
                    addButtonScale = 1.08
                    glowIntensity = 0.8
                }
                
                // Flash effect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        glowIntensity = 0.0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        addButtonScale = 1.0
                    }
                }
            }
            .onAppear {
                // Start continuous animations
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    cameraButtonPulse = true
                }
                
                if isProcessingReceipts {
                    withAnimation(.linear(duration: 0.1)) {
                        scanningAnimation = true
                    }
                }
            }
            .onChange(of: isProcessingReceipts) { oldValue, newValue in
                if newValue {
                    withAnimation(.linear(duration: 0.1)) {
                        scanningAnimation = true
                    }
                } else {
                    scanningAnimation = false
                }
            }
            
            // Enhanced selected photos indicator
            if !selectedPhotos.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedPhotos.count) photo\(selectedPhotos.count == 1 ? "" : "s") selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Ready for AI processing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Clear") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedPhotos.removeAll()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                .offset(y: photoSelectionOffset)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        photoSelectionOffset = 0
                    }
                }
            }
        }
    }
    
    private var recentExpensesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Expenses")
                    .font(.headline)
                Spacer()
                HStack(spacing: 16) {
                    if !recentExpenses.isEmpty {
                        Button("View All") {
                            selectedTab = 1
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .accessibilityLabel("View All Expenses")
                        .accessibilityHint("Navigate to complete expense list")
                    }
                    
                    if recentExpenses.count >= 3 {
                        Button(action: {
                            selectedTab = 2
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile")
                                    .font(.caption)
                                Text("AI Insights")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.purple)
                        }
                    }
                }
            }
            
            if recentExpenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "receipt")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No expenses yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Use the camera button above to scan your first receipt")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentExpenses.prefix(5)) { expense in
                        ExpenseRowView(expense: expense) {
                            deleteExpense(expense)
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
        }
    }
    
    private func processSelectedPhotos() async {
        isProcessingReceipts = true
        
        let processedCount = await expenseService.processReceiptPhotos(selectedPhotos)
        
        selectedPhotos.removeAll()
        // No need to manually load expenses - the computed properties will automatically update
        
        if processedCount > 0 {
            alertMessage = "Successfully processed \(processedCount) receipt\(processedCount == 1 ? "" : "s") and added to your expenses."
        } else {
            alertMessage = "Failed to process receipts. Please check your API credentials and try again."
        }
        showingAlert = true
        
        isProcessingReceipts = false
    }
    
    
    
    private func deleteExpense(_ expense: Expense) {
        expenseToDelete = expense
        showingDeleteConfirmation = true
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    let currency: String
    
    @State private var isPressed = false
    @State private var iconScale: CGFloat = 1.0
    @State private var cardOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .scaleEffect(iconScale)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: iconScale)
                Spacer()
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(amount.formatted(currency: currency))
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(isPressed ? 0.15 : 0.1), radius: isPressed ? 4 : 2, x: 0, y: isPressed ? 2 : 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .offset(y: cardOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.easeInOut(duration: 0.1), value: cardOffset)
        .onTapGesture {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                isPressed = true
                iconScale = 1.2
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                    iconScale = 1.0
                }
            }
        }
        .onAppear {
            // Staggered appearance animation
            let delay = title.contains("Month") ? 0.1 : 0.2
            cardOffset = 30
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    cardOffset = 0
                }
            }
            
            // Icon pulse animation
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    iconScale = 1.1
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        iconScale = 1.0
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(amount.formatted(currency: currency))")
        .accessibilityHint("Summary card showing \(title.lowercased())")
    }
}

struct ExpenseRowView: View {
    let expense: Expense
    let onDelete: () -> Void
    @State private var showingItemDetails = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack {
                    Image(systemName: categoryIcon(for: expense.category))
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.merchant)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(expense.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(expense.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let itemCount = expense.items?.count, itemCount > 0 {
                            Text("• \(itemCount) item\(itemCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(expense.formattedAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let paymentMethod = expense.paymentMethod {
                        Text(paymentMethod)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    
                    if expense.items != nil && !expense.items!.isEmpty {
                        Image(systemName: showingItemDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                print("Row tapped for expense: \(expense.merchant), current state: \(showingItemDetails)")
                print("Expense has items: \(expense.items?.count ?? 0)")
                
                // Always toggle for debugging - later we'll add back the condition
                // Haptic feedback for tap
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingItemDetails.toggle()
                }
                print("New state: \(showingItemDetails)")
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
                print("Long press detected for expense: \(expense.merchant)")
                
                // Haptic feedback for long press
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                onDelete()
            } onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
            
            // Item details section - Debug version
            if showingItemDetails {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    if let items = expense.items, !items.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(items) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if let description = item.description {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let category = item.category {
                                            Text(category)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if let quantity = item.quantity, quantity != 1 {
                                            Text("\(quantity, specifier: "%.1f")x")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(item.formattedTotalPrice(currency: expense.currency))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if let unitPriceFormatted = item.formattedUnitPrice(currency: expense.currency), let quantity = item.quantity, quantity > 1 {
                                            Text("\(unitPriceFormatted) each")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        // Debug: Show message when no items
                        Text("No items found for this expense (Debug Mode)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                    }
                    
                    // Financial breakdown if available
                    if expense.subtotal != nil || expense.tip != nil || expense.fees != nil || expense.discounts != nil {
                        Divider()
                            .padding(.horizontal)
                        
                        VStack(spacing: 4) {
                            if let formattedSubtotal = expense.formattedSubtotal {
                                HStack {
                                    Text("Subtotal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedSubtotal)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let formattedDiscounts = expense.formattedDiscounts {
                                HStack {
                                    Text("Discounts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedDiscounts)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if let formattedFees = expense.formattedFees {
                                HStack {
                                    Text("Fees")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedFees)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let formattedTaxAmount = expense.formattedTaxAmount {
                                HStack {
                                    Text("Tax")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedTaxAmount)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let formattedTip = expense.formattedTip {
                                HStack {
                                    Text("Tip")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formattedTip)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(expense.formattedAmount)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .id("expense-\(expense.id)-\(showingItemDetails)")
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Food & Dining": return "fork.knife"
        case "Transportation": return "car"
        case "Shopping": return "bag"
        case "Entertainment": return "tv"
        case "Bills & Utilities": return "lightbulb"
        case "Healthcare": return "cross.case"
        case "Travel": return "airplane"
        case "Education": return "book"
        case "Business": return "briefcase"
        default: return "doc.text"
        }
    }
}

enum ExpenseSortOption: String, CaseIterable {
    case dateNewest = "Date (Newest First)"
    case dateOldest = "Date (Oldest First)"
    case amountHighest = "Amount (Highest First)"
    case amountLowest = "Amount (Lowest First)"
    case merchantAZ = "Merchant (A-Z)"
    case merchantZA = "Merchant (Z-A)"
    
    var systemImage: String {
        switch self {
        case .dateNewest: return "calendar.badge.minus"
        case .dateOldest: return "calendar.badge.plus"
        case .amountHighest: return "dollarsign.arrow.circlepath"
        case .amountLowest: return "dollarsign.circle"
        case .merchantAZ: return "textformat.abc"
        case .merchantZA: return "textformat.abc.dottedunderline"
        }
    }
}

struct AllExpensesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var expenseService = ExpenseService.coreDataService
    @State private var expenseToDelete: Expense?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""
    @State private var sortOption: ExpenseSortOption = .dateNewest
    @State private var showingSortOptions = false
    
    let isModal: Bool
    
    private var filteredExpenses: [Expense] {
        let expenses: [Expense]
        
        if searchText.isEmpty {
            expenses = expenseService.expenses
        } else {
            expenses = expenseService.expenses.filter { expense in
                let merchantMatch = expense.merchant.localizedCaseInsensitiveContains(searchText)
                let categoryMatch = expense.category.localizedCaseInsensitiveContains(searchText)
                let descriptionMatch = expense.description?.localizedCaseInsensitiveContains(searchText) ?? false
                
                let itemMatch = expense.items?.contains { item in
                    let itemNameMatch = item.name.localizedCaseInsensitiveContains(searchText)
                    let itemCategoryMatch = item.category?.localizedCaseInsensitiveContains(searchText) ?? false
                    let itemDescriptionMatch = item.description?.localizedCaseInsensitiveContains(searchText) ?? false
                    return itemNameMatch || itemCategoryMatch || itemDescriptionMatch
                } ?? false
                
                return merchantMatch || categoryMatch || descriptionMatch || itemMatch
            }
        }
        
        return expenses.sorted { expense1, expense2 in
            switch sortOption {
            case .dateNewest:
                return expense1.date > expense2.date
            case .dateOldest:
                return expense1.date < expense2.date
            case .amountHighest:
                return expense1.amount > expense2.amount
            case .amountLowest:
                return expense1.amount < expense2.amount
            case .merchantAZ:
                return expense1.merchant.localizedCaseInsensitiveCompare(expense2.merchant) == .orderedAscending
            case .merchantZA:
                return expense1.merchant.localizedCaseInsensitiveCompare(expense2.merchant) == .orderedDescending
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if filteredExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "receipt")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No expenses found")
                            .font(.title3)
                            .fontWeight(.medium)
                        if !searchText.isEmpty {
                            Text("Try adjusting your search")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredExpenses) { expense in
                        ExpenseRowView(expense: expense) {
                            deleteExpense(expense)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("All Expenses")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search expenses...")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSortOptions = true
                    }) {
                        HStack(spacing: 4) {
                            ZStack {
                                Image(systemName: "arrow.up.arrow.down")
                                
                                // Show indicator dot when not using default sort
                                if sortOption != .dateNewest {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 8, y: -8)
                                }
                            }
                            Text("Sort")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                }
                
                if isModal {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            })
        }
        .alert("Delete Expense", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                expenseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    try? expenseService.deleteExpense(expense)
                    expenseToDelete = nil
                }
            }
        } message: {
            if let expense = expenseToDelete {
                Text("Are you sure you want to delete the expense from \(expense.merchant) for \(expense.formattedAmount)?")
            }
        }
        .sheet(isPresented: $showingSortOptions) {
            SortOptionsView(selectedSort: $sortOption)
        }
    }
    
    
    
    private func deleteExpense(_ expense: Expense) {
        expenseToDelete = expense
        showingDeleteConfirmation = true
    }
}

struct SortOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSort: ExpenseSortOption
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(ExpenseSortOption.allCases, id: \.self) { option in
                        HStack(spacing: 16) {
                            // Icon with colored background
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(option == selectedSort ? Color.accentColor : Color.gray.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: option.systemImage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(option == selectedSort ? .white : .primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(option.rawValue)
                                        .font(.body)
                                        .fontWeight(option == selectedSort ? .semibold : .regular)
                                    
                                    if option == .dateNewest {
                                        Text("(Default)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.blue.opacity(0.1))
                                            )
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if option == selectedSort {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSort = option
                            dismiss()
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                } header: {
                    Text("Sort Options")
                } footer: {
                    Text("Choose how to organize your expenses. The default sorting shows newest expenses first.")
                }
            }
            .navigationTitle("Sort Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
    }
}

extension ExpenseSortOption {
    var description: String {
        switch self {
        case .dateNewest:
            return "Most recent expenses appear first"
        case .dateOldest:
            return "Oldest expenses appear first"
        case .amountHighest:
            return "Largest amounts appear first"
        case .amountLowest:
            return "Smallest amounts appear first"
        case .merchantAZ:
            return "Merchants sorted alphabetically A-Z"
        case .merchantZA:
            return "Merchants sorted alphabetically Z-A"
        }
    }
}

#Preview {
    OverviewView(selectedTab: .constant(0))
        .environmentObject(ConfigurationManager())
}

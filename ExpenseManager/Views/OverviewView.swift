import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit
import Foundation
import CoreData

// Use legacy ExpenseService as bridge to CoreDataExpenseService

struct OverviewView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @ObservedObject private var expenseService = ExpenseService.shared
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedDocuments: [URL] = []
    @State private var showingDocumentPicker = false
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
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(selectedDocuments: $selectedDocuments)
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            if !newValue.isEmpty {
                Task {
                    await processSelectedPhotos()
                }
            }
        }
        .onChange(of: selectedDocuments) { oldValue, newValue in
            if !newValue.isEmpty {
                Task {
                    await processSelectedDocuments()
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
            
            // 50/50 Button Row Layout
            HStack(spacing: 16) {
                // Photos Button (Left 50%)
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    VStack(spacing: 12) {
                        // Camera icon with animations
                        ZStack {
                            // Pulsing background circle
                            Circle()
                                .fill(Color.accentColor.opacity(cameraButtonPulse ? 0.3 : 0.1))
                                .frame(width: 50, height: 50)
                                .scaleEffect(cameraButtonPulse ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: cameraButtonPulse)

                            if isProcessingReceipts {
                                // Processing state - animated dots
                                HStack(spacing: 2) {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 4, height: 4)
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
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.accentColor)
                                    .scaleEffect(addButtonScale * (cameraButtonPulse ? 1.05 : 1.0))
                                    .rotationEffect(.degrees(addButtonRotation))
                                    .overlay(
                                        // Flash effect
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.white)
                                            .opacity(glowIntensity)
                                            .scaleEffect(1.2)
                                            .blur(radius: 4)
                                    )
                            }
                        }

                        VStack(spacing: 4) {
                            Text(isProcessingReceipts ? "Processing..." : "Photos")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            if !isProcessingReceipts {
                                Text("Scan Images")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        // Animated arrow or processing indicator
                        if isProcessingReceipts {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.accentColor)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .scaleEffect(addButtonScale)
                                .rotationEffect(.degrees(addButtonRotation * 0.1))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
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
                                RoundedRectangle(cornerRadius: 16)
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
                            .shadow(color: Color.accentColor.opacity(glowIntensity), radius: 8, x: 0, y: 0)
                            .scaleEffect(addButtonScale)
                    )
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

                // PDF Button (Right 50%)
                Button(action: {
                    showingDocumentPicker = true

                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }) {
                    VStack(spacing: 12) {
                        // PDF icon
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.blue)
                        }

                        VStack(spacing: 4) {
                            Text("PDFs")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("Upload Files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
                }
                .disabled(isProcessingReceipts)
                .scaleEffect(isProcessingReceipts ? 0.95 : 1.0)
                .opacity(isProcessingReceipts ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isProcessingReceipts)
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

            // Feature highlights row
            if !isProcessingReceipts {
                HStack(spacing: 16) {
                    Label("AI-Powered", systemImage: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.accentColor)

                    Label("Multi-Currency", systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.accentColor)

                    Label("50+ Formats", systemImage: "square.stack.3d.up.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }

            // Enhanced selected photos indicator
            if !selectedPhotos.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedPhotos.count) file\(selectedPhotos.count == 1 ? "" : "s") selected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("Photos and PDFs ready for AI processing")
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
                    Text("Use the buttons above to scan your first receipt photos or PDFs")
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

        if processedCount > 0 {
            alertMessage = "Successfully processed \(processedCount) receipt\(processedCount == 1 ? "" : "s") and added to your expenses."
            // Add haptic feedback for successful processing
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } else {
            // Generic fallback - the actual error handling should happen in the service
            alertMessage = "No receipts could be processed. Please try with clearer images or check your settings."
        }

        showingAlert = true
        isProcessingReceipts = false
    }

    private func processSelectedDocuments() async {
        isProcessingReceipts = true
        var processedCount = 0
        let totalDocuments = selectedDocuments.count

        for documentURL in selectedDocuments {
            do {
                // Since we use asCopy: true in DocumentPicker, files are already in app sandbox
                // No need for security scoped resource access
                print("Processing PDF: \(documentURL.lastPathComponent)")

                // Read PDF data directly from copied file
                let pdfData = try Data(contentsOf: documentURL)
                print("Successfully loaded PDF from: \(documentURL.lastPathComponent) (\(pdfData.count) bytes)")

                // Convert PDF to images
                if let images = convertPDFToImages(pdfData) {
                    print("Successfully converted PDF to \(images.count) images")
                    for (index, image) in images.enumerated() {
                        print("Processing page \(index + 1) of \(images.count)")
                        // Process image directly with OpenAI service
                        do {
                            let extractedData = try await OpenAIService.shared.extractExpenseFromReceipt(image)

                            let expense = Expense(
                                date: parseDateFromExtraction(extractedData.date),
                                merchant: extractedData.merchant,
                                amount: extractedData.amount,
                                currency: extractedData.currency.isEmpty ? "USD" : extractedData.currency,
                                category: extractedData.category,
                                description: extractedData.description,
                                paymentMethod: extractedData.paymentMethod,
                                taxAmount: extractedData.taxAmount,
                                items: extractedData.items?.map { openAIItem in
                                    ExpenseItem(
                                        name: openAIItem.name,
                                        quantity: openAIItem.quantity,
                                        unitPrice: openAIItem.unitPrice,
                                        totalPrice: openAIItem.totalPrice,
                                        category: openAIItem.category,
                                        description: openAIItem.description
                                    )
                                },
                                subtotal: extractedData.subtotal,
                                discounts: extractedData.discounts,
                                fees: extractedData.fees,
                                tip: extractedData.tip,
                                itemsTotal: extractedData.itemsTotal
                            )

                            // Add to ExpenseService
                            _ = try expenseService.addExpense(expense)
                            processedCount += 1
                        } catch {
                            print("Failed to process PDF page: \(error)")
                        }
                    }
                }
            } catch {
                print("Failed to process document \(documentURL.lastPathComponent): \(error)")

                // Provide specific error messages based on error type
                if let error = error as NSError? {
                    switch error.code {
                    case NSFileReadNoSuchFileError:
                        print("PDF file not found or inaccessible")
                    case NSFileReadNoPermissionError:
                        print("No permission to read PDF file")
                    default:
                        print("PDF processing error: \(error.localizedDescription)")
                    }
                }
                // Continue processing other documents even if one fails
            }
        }

        selectedDocuments.removeAll()

        if processedCount > 0 {
            if processedCount == totalDocuments {
                alertMessage = "Successfully processed \(processedCount) PDF document\(processedCount == 1 ? "" : "s") and added to your expenses."
            } else {
                alertMessage = "Processed \(processedCount) of \(totalDocuments) PDF documents. Some pages may have failed - check console for details."
            }
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } else {
            alertMessage = "Failed to process PDF documents. Please check your API credentials and ensure PDFs contain readable receipt text."
        }
        showingAlert = true

        isProcessingReceipts = false
    }

    private func convertPDFToImages(_ pdfData: Data) -> [UIImage]? {
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            print("Failed to create PDF document from data")
            return nil
        }

        var images: [UIImage] = []

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Set up rendering parameters for high quality
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)

            let image = renderer.image { ctx in
                // Fill with white background
                UIColor.white.set()
                ctx.fill(pageRect)

                // Render the PDF page
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            images.append(image)
        }

        print("Converted PDF to \(images.count) images")
        return images.isEmpty ? nil : images
    }

    private func parseDateFromExtraction(_ dateString: String) -> Date {
        let dateFormatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "dd.MM.yyyy",
            "MM/dd/yyyy",
            "MM-dd-yyyy"
        ]

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        for format in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")

            if let date = formatter.date(from: dateString) {
                // Handle 2-digit year interpretation
                let year = calendar.component(.year, from: date)
                if year < 100 {
                    let adjustedYear = year + 2000
                    if adjustedYear > currentYear + 10 {
                        let components = calendar.dateComponents([.month, .day], from: date)
                        var newComponents = DateComponents()
                        newComponents.year = adjustedYear - 100
                        newComponents.month = components.month
                        newComponents.day = components.day
                        return calendar.date(from: newComponents) ?? date
                    } else {
                        let components = calendar.dateComponents([.month, .day], from: date)
                        var newComponents = DateComponents()
                        newComponents.year = adjustedYear
                        newComponents.month = components.month
                        newComponents.day = components.day
                        return calendar.date(from: newComponents) ?? date
                    }
                }
                return date
            }
        }

        print("Warning: Could not parse date '\(dateString)', using current date")
        return Date()
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
    @ObservedObject private var expenseService = ExpenseService.shared
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
            .toolbar {
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
            }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedDocuments: [URL]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedDocuments = urls
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    OverviewView(selectedTab: .constant(0))
        .environmentObject(ConfigurationManager())
}

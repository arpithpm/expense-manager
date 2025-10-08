import Foundation
import CoreData
import Combine
import UIKit
import PDFKit
import UniformTypeIdentifiers

// Import PhotosUI conditionally to avoid compilation issues
#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(PhotosUI) && swift(>=5.7)
import PhotosUI
#endif

public class CoreDataExpenseService: ObservableObject {
    public static let shared = CoreDataExpenseService()
    
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private let openAIService = OpenAIService.shared
    private let userDefaults = UserDefaults.standard
    private let lastBackupKey = "LastBackupDate"
    private let firstLaunchKey = "HasLaunchedBefore"
    
    private init() {
        // Perform migration from UserDefaults if needed
        try? migrateFromUserDefaults()
        
        loadExpenses()
        
        // Add sample data on first launch if no expenses exist
        if expenses.isEmpty && !hasLaunchedBefore() {
            addSampleExpenses()
            markFirstLaunchComplete()
        }
    }
    
    // MARK: - Receipt Processing
    
    #if canImport(PhotosUI) && swift(>=5.7)
    @available(iOS 16.0, *)
    func processReceiptPhotos(_ photoItems: [Any]) async -> Int {
        var processedCount = 0
        
        for photoItem in photoItems {
            do {
                if let imageData = try await loadImageData(from: photoItem),
                   let image = UIImage(data: imageData) {
                    
                    let extractedData = try await openAIService.extractExpenseFromReceipt(image)
                    let expense = try createExpenseFromExtraction(extractedData)
                    
                    // Save expense to Core Data
                    _ = try addExpense(expense)
                    
                    processedCount += 1
                }
            } catch {
                // Handle photo processing error silently in production
                // Provide more specific error messages based on error type
                if let openAIError = error as? OpenAIError {
                    switch openAIError {
                    case .invalidAPIKey:
                        errorMessage = "Invalid OpenAI API key. Please check your credentials."
                    case .apiError(let code):
                        errorMessage = "OpenAI API error (Status \(code)). Check your API key and quota."
                    case .missingAPIKey:
                        errorMessage = "OpenAI API key not found. Please configure in settings."
                    case .responseParsingFailed:
                        errorMessage = "Failed to parse receipt data. The response may be incomplete - try a clearer image or simpler receipt."
                    case .responseTruncated:
                        errorMessage = "Receipt has too many items for processing. Try processing a simpler receipt."
                    case .invalidURL:
                        errorMessage = "Invalid OpenAI API URL configuration."
                    case .requestEncodingFailed:
                        errorMessage = "Failed to encode the request. Please try again."
                    case .invalidResponse:
                        errorMessage = "Invalid response from OpenAI. Please try again."
                    case .noResponseContent:
                        errorMessage = "No content received from OpenAI. Please try again."
                    case .imageProcessingFailed:
                        errorMessage = "Failed to process the image. Please try a different image."
                    }
                } else {
                    errorMessage = "Processing failed: \(error.localizedDescription)"
                }
            }
        }
        
        return processedCount
    }

    func processDocuments(_ documentURLs: [URL]) async -> Int {
        var processedCount = 0

        for documentURL in documentURLs {
            do {
                // Check if we can access the file
                guard documentURL.startAccessingSecurityScopedResource() else {
                    print("Failed to access security scoped resource: \(documentURL)")
                    continue
                }

                defer {
                    documentURL.stopAccessingSecurityScopedResource()
                }

                // Read PDF data
                let pdfData = try Data(contentsOf: documentURL)
                print("Successfully loaded PDF from: \(documentURL.lastPathComponent)")

                // Convert PDF to images
                if let images = convertPDFToImages(pdfData) {
                    for image in images {
                        let extractedData = try await openAIService.extractExpenseFromReceipt(image)

                        let expense = Expense(
                            date: parseDateFromExtraction(extractedData.date),
                            merchant: extractedData.merchant,
                            amount: extractedData.amount,
                            currency: CurrencyHelper.isSupported(extractedData.currency) ? extractedData.currency : "USD",
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

                        _ = try addExpense(expense)
                        processedCount += 1
                    }
                }
            } catch {
                print("Failed to process document \(documentURL.lastPathComponent): \(error)")
                // Continue processing other documents even if one fails
            }
        }

        return processedCount
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

        for format in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        print("Warning: Could not parse date '\(dateString)', using current date")
        return Date()
    }

    @available(iOS 16.0, *)
    private func loadImageData(from photoItem: Any) async throws -> Data? {
        // Use dynamic dispatch to handle PhotosPickerItem without compile-time type checking
        guard let item = photoItem as? NSObject else {
            throw ExpenseManagerError.invalidExpenseData
        }
        
        // Use KVC to access loadTransferable method if available
        if item.responds(to: Selector(("loadTransferable:completion:"))) {
            return try await withCheckedThrowingContinuation { continuation in
                let dataType = Data.self
                item.perform(Selector(("loadTransferable:completion:")), with: dataType, with: { (result: Any?) in
                    if let data = result as? Data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(returning: nil)
                    }
                })
            }
        }
        
        return nil
    }
    #endif
    
    private func createExpenseFromExtraction(_ extraction: OpenAIExpenseExtraction) throws -> Expense {
        // Enhanced date parsing with improved fallback logic
        var expenseDate = parseDateFromExtraction(extraction.date)
        
        // Validate and fix date if it's incorrectly parsed as 2023 instead of current year
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let extractedYear = calendar.component(.year, from: expenseDate)
        
        // If the extracted date is from past years but we're in a later year, likely a parsing error
        if extractedYear < currentYear - 1 {
            print("Warning: Date parsed as \(extractedYear), correcting to \(currentYear). Original: \(extraction.date)")
            let components = calendar.dateComponents([.month, .day], from: expenseDate)
            var correctedComponents = DateComponents()
            correctedComponents.year = currentYear
            correctedComponents.month = components.month
            correctedComponents.day = components.day
            expenseDate = calendar.date(from: correctedComponents) ?? expenseDate
            print("Corrected date: \(expenseDate)")
        }
        
        // Convert OpenAI items to ExpenseItems
        let expenseItems: [ExpenseItem]? = extraction.items?.map { openAIItem in
            ExpenseItem(
                name: openAIItem.name,
                quantity: openAIItem.quantity,
                unitPrice: openAIItem.unitPrice,
                totalPrice: openAIItem.totalPrice,
                category: openAIItem.category,
                description: openAIItem.description
            )
        }
        
        // Validate extracted data before creating expense
        let merchantValidation = InputValidator.validateMerchantName(extraction.merchant)
        let sanitizedMerchant = merchantValidation.sanitizedValue ?? "Unknown Merchant"
        
        let categoryValidation = InputValidator.validateCategory(extraction.category)
        let sanitizedCategory = categoryValidation.sanitizedValue ?? "Other"
        
        let amountValidation = InputValidator.validateAmount(String(extraction.amount))
        guard amountValidation.isValid else {
            throw ExpenseManagerError.invalidAmount
        }
        
        var sanitizedDescription: String? = nil
        if let desc = extraction.description {
            let descriptionValidation = InputValidator.validateExpenseDescription(desc)
            sanitizedDescription = descriptionValidation.sanitizedValue
        }
        
        var sanitizedPaymentMethod: String? = nil
        if let payment = extraction.paymentMethod {
            let paymentValidation = InputValidator.validatePaymentMethod(payment)
            sanitizedPaymentMethod = paymentValidation.sanitizedValue
        }
        
        // Enhanced currency validation with intelligence service
        var finalCurrency = extraction.currency
        
        // First check if extracted currency is supported
        if !CurrencyHelper.isSupported(extraction.currency) {
            print("Warning: Unsupported currency '\(extraction.currency)', using intelligent detection")
            
            // Use intelligent currency detection
            let intelligentCurrency = CurrencyIntelligenceService.shared.intelligentCurrencyDetection(
                merchant: extraction.merchant,
                description: extraction.description
            )
            finalCurrency = intelligentCurrency
            
            print("Intelligent currency detection result: \(intelligentCurrency)")
        } else {
            // Even if currency is supported, validate it makes sense for the merchant
            let (intelligentCurrency, confidence) = CurrencyIntelligenceService.shared.analyzeCurrencyWithConfidence(
                merchant: extraction.merchant,
                description: extraction.description
            )
            
            // If we have high confidence in a different currency, log the discrepancy
            if confidence > 0.8 && intelligentCurrency != extraction.currency {
                print("Currency confidence check: AI extracted '\(extraction.currency)' but merchant analysis suggests '\(intelligentCurrency)' with confidence \(confidence)")
                // For now, trust the AI extraction, but log the discrepancy
            }
        }
        
        return Expense(
            date: expenseDate,
            merchant: sanitizedMerchant,
            amount: extraction.amount,
            currency: finalCurrency,
            category: sanitizedCategory,
            description: sanitizedDescription,
            paymentMethod: sanitizedPaymentMethod,
            taxAmount: extraction.taxAmount,
            items: expenseItems,
            subtotal: extraction.subtotal,
            discounts: extraction.discounts,
            fees: extraction.fees,
            tip: extraction.tip,
            itemsTotal: extraction.itemsTotal
        )
    }
    
    // MARK: - Core Data Operations
    
    func loadExpenses() {
        let request: NSFetchRequest<ExpenseEntity> = ExpenseEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseEntity.date, ascending: false)]
        
        do {
            let entities = try coreDataManager.viewContext.fetch(request)
            let mappedExpenses = entities.map { $0.toExpense() }
            
            // Deduplicate by ID to prevent duplicate entries in UI
            var seenIds = Set<UUID>()
            expenses = mappedExpenses.filter { expense in
                if seenIds.contains(expense.id) {
                    print("Warning: Duplicate expense found with ID \(expense.id) for merchant \(expense.merchant)")
                    return false
                }
                seenIds.insert(expense.id)
                return true
            }
        } catch {
            errorMessage = "Failed to load expenses: \(error.localizedDescription)"
            // Handle Core Data fetch error silently in production
        }
    }
    
    func addExpense(_ expense: Expense) throws -> Expense {
        // Check if expense with this ID already exists
        let context = coreDataManager.viewContext
        let existingRequest: NSFetchRequest<ExpenseEntity> = ExpenseEntity.fetchRequest()
        existingRequest.predicate = NSPredicate(format: "id == %@", expense.id as CVarArg)
        
        do {
            let existingEntities = try context.fetch(existingRequest)
            if !existingEntities.isEmpty {
                print("Warning: Expense with ID \(expense.id) already exists, skipping duplicate")
                return expense // Return existing expense instead of creating duplicate
            }
        } catch {
            print("Error checking for existing expense: \(error)")
        }
        
        // Validate expense data using InputValidator
        let amountValidation = InputValidator.validateAmount(String(expense.amount))
        guard amountValidation.isValid else {
            throw ExpenseManagerError.invalidAmount
        }
        
        guard expense.date <= Date() else {
            throw ExpenseManagerError.invalidDate
        }
        
        let merchantValidation = InputValidator.validateMerchantName(expense.merchant)
        guard merchantValidation.isValid else {
            throw ExpenseManagerError.invalidExpenseData
        }
        
        let categoryValidation = InputValidator.validateCategory(expense.category)
        guard categoryValidation.isValid else {
            throw ExpenseManagerError.invalidExpenseData
        }
        
        if let description = expense.description {
            let descriptionValidation = InputValidator.validateExpenseDescription(description)
            guard descriptionValidation.isValid else {
                throw ExpenseManagerError.invalidExpenseData
            }
        }
        
        if let paymentMethod = expense.paymentMethod {
            let paymentValidation = InputValidator.validatePaymentMethod(paymentMethod)
            guard paymentValidation.isValid else {
                throw ExpenseManagerError.invalidExpenseData
            }
        }
        
        let entity = ExpenseEntity(context: context)
        entity.updateFromExpense(expense, context: context)
        
        do {
            try context.save()
            loadExpenses() // Refresh the expenses array
            
            // Update backup timestamp
            userDefaults.set(Date(), forKey: lastBackupKey)
            
            return expense
        } catch {
            throw ExpenseManagerError.persistenceError(underlying: error)
        }
    }
    
    func deleteExpense(_ expense: Expense) throws {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ExpenseEntity> = ExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", expense.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                context.delete(entity)
                try context.save()
                loadExpenses() // Refresh the expenses array
                
                // Update backup timestamp
                userDefaults.set(Date(), forKey: lastBackupKey)
            }
        } catch {
            throw ExpenseManagerError.persistenceError(underlying: error)
        }
    }
    
    func updateExpense(_ expense: Expense) throws {
        // Validate expense data using InputValidator
        let amountValidation = InputValidator.validateAmount(String(expense.amount))
        guard amountValidation.isValid else {
            throw ExpenseManagerError.invalidAmount
        }
        
        guard expense.date <= Date() else {
            throw ExpenseManagerError.invalidDate
        }
        
        let merchantValidation = InputValidator.validateMerchantName(expense.merchant)
        guard merchantValidation.isValid else {
            throw ExpenseManagerError.invalidExpenseData
        }
        
        let categoryValidation = InputValidator.validateCategory(expense.category)
        guard categoryValidation.isValid else {
            throw ExpenseManagerError.invalidExpenseData
        }
        
        if let description = expense.description {
            let descriptionValidation = InputValidator.validateExpenseDescription(description)
            guard descriptionValidation.isValid else {
                throw ExpenseManagerError.invalidExpenseData
            }
        }
        
        if let paymentMethod = expense.paymentMethod {
            let paymentValidation = InputValidator.validatePaymentMethod(paymentMethod)
            guard paymentValidation.isValid else {
                throw ExpenseManagerError.invalidExpenseData
            }
        }
        
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ExpenseEntity> = ExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", expense.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.updateFromExpense(expense, context: context)
                try context.save()
                loadExpenses() // Refresh the expenses array
                
                // Update backup timestamp
                userDefaults.set(Date(), forKey: lastBackupKey)
            }
        } catch {
            throw ExpenseManagerError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Data Migration from UserDefaults
    
    public func migrateFromUserDefaults() throws {
        let userDefaults = UserDefaults.standard
        let expensesKey = "SavedExpenses"
        
        guard let data = userDefaults.data(forKey: expensesKey),
              let userDefaultsExpenses = try? JSONDecoder().decode([Expense].self, from: data) else {
            return // No data to migrate
        }
        
        // Migrating expenses from UserDefaults to Core Data
        
        for expense in userDefaultsExpenses {
            let context = coreDataManager.viewContext
            let entity = ExpenseEntity(context: context)
            entity.updateFromExpense(expense, context: context)
        }
        
        do {
            try coreDataManager.viewContext.save()
            loadExpenses() // Refresh the expenses array
            
            // Remove data from UserDefaults after successful migration
            userDefaults.removeObject(forKey: expensesKey)
            // Successfully migrated expenses and removed UserDefaults data
        } catch {
            throw ExpenseManagerError.persistenceError(underlying: error)
        }
    }
    
    // MARK: - Expense Analytics (same as original)
    
    func getTotalExpenses() -> Double {
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getMonthlyTotal() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return expenses.filter { expense in
            expense.date >= startOfMonth && expense.date < endOfMonth
        }.reduce(0) { $0 + $1.amount }
    }
    
    func fetchRecentExpenses(limit: Int = 10) async throws -> [Expense] {
        isLoading = true
        errorMessage = nil
        
        let recentExpenses = Array(expenses.sorted { $0.date > $1.date }.prefix(limit))
        isLoading = false
        return recentExpenses
    }
    
    // MARK: - Item-Level Analytics
    
    func getItemsFromExpenses() -> [ExpenseItem] {
        return expenses.compactMap { $0.items }.flatMap { $0 }
    }
    
    func getTopItems(limit: Int = 10) -> [(item: String, totalSpent: Double, count: Int)] {
        let allItems = getItemsFromExpenses()
        let itemGroups = Dictionary(grouping: allItems) { $0.name.lowercased() }
        
        return itemGroups.map { (name, items) in
            let totalSpent = items.reduce(0) { $0 + $1.totalPrice }
            let count = items.count
            return (item: items.first?.name ?? name, totalSpent: totalSpent, count: count)
        }
        .sorted { $0.totalSpent > $1.totalSpent }
        .prefix(limit)
        .map { $0 }
    }
    
    func getSpendingByItemCategory() -> [String: Double] {
        let allItems = getItemsFromExpenses()
        let categoryGroups = Dictionary(grouping: allItems) { $0.category ?? "Other" }
        
        return categoryGroups.mapValues { items in
            items.reduce(0) { $0 + $1.totalPrice }
        }
    }
    
    func getAverageItemPrice(for itemName: String) -> Double? {
        let matchingItems = getItemsFromExpenses().filter { 
            $0.name.lowercased().contains(itemName.lowercased()) 
        }
        
        guard !matchingItems.isEmpty else { return nil }
        
        let totalPrice = matchingItems.reduce(0) { $0 + $1.totalPrice }
        return totalPrice / Double(matchingItems.count)
    }
    
    func getItemFrequency() -> [String: Int] {
        let allItems = getItemsFromExpenses()
        let itemGroups = Dictionary(grouping: allItems) { $0.name.lowercased() }
        
        return itemGroups.mapValues { $0.count }
    }
    
    // MARK: - Currency Handling
    
    func getPrimaryCurrency() -> String {
        let currencyGroups = Dictionary(grouping: expenses) { $0.currency }
        let mostCommonCurrency = currencyGroups.max { a, b in a.value.count < b.value.count }?.key
        return mostCommonCurrency ?? "USD"
    }
    
    func getTotalInPrimaryCurrency() -> Double {
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getMonthlyTotalInPrimaryCurrency() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return expenses.filter { expense in
            expense.date >= startOfMonth && expense.date < endOfMonth
        }.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Backup Status Methods
    
    func getLastBackupDate() -> Date? {
        return userDefaults.object(forKey: lastBackupKey) as? Date
    }
    
    func isDataBackedUp() -> Bool {
        guard let lastBackup = getLastBackupDate() else { return false }
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return lastBackup > twentyFourHoursAgo && !expenses.isEmpty
    }
    
    func getBackupStatus() -> BackupStatus {
        if expenses.isEmpty {
            return .noData
        }
        
        guard let lastBackup = getLastBackupDate() else {
            return .notBackedUp
        }
        
        let now = Date()
        let timeSinceBackup = now.timeIntervalSince(lastBackup)
        
        if timeSinceBackup < 60 * 60 {
            return .current
        } else if timeSinceBackup < 24 * 60 * 60 {
            return .recent
        } else {
            return .outdated
        }
    }
    
    // MARK: - First Launch Tracking
    
    private func hasLaunchedBefore() -> Bool {
        return userDefaults.bool(forKey: firstLaunchKey)
    }
    
    private func markFirstLaunchComplete() {
        userDefaults.set(true, forKey: firstLaunchKey)
    }
    
    // MARK: - Demo Data Detection
    
    static let sampleMerchants = ["Starbucks Coffee", "Shell Gas Station", "Tesco Extra", "Target", "Chipotle Mexican Grill", "Amazon.com"]
    
    func hasDemoData() -> Bool {
        return expenses.contains { expense in
            CoreDataExpenseService.sampleMerchants.contains(expense.merchant)
        }
    }
    
    func clearDemoData() {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<ExpenseEntity> = ExpenseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "merchant IN %@", CoreDataExpenseService.sampleMerchants)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            loadExpenses() // Refresh the expenses array
        } catch {
            // Failed to clear demo data
        }
    }
    
    // MARK: - Sample Data for First Launch
    
    private func addSampleExpenses() {
        let calendar = Calendar.current
        let now = Date()
        
        let sampleExpenses = [
            Expense(
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                merchant: "Starbucks Coffee",
                amount: 4.75,
                currency: "USD",
                category: "Food & Dining",
                description: "Morning coffee and pastry",
                paymentMethod: "Credit Card",
                taxAmount: 0.38,
                items: [
                    ExpenseItem(name: "Grande Latte", quantity: 1, unitPrice: 4.75, totalPrice: 4.75, category: "Beverage", description: "Oat milk"),
                    ExpenseItem(name: "Blueberry Muffin", quantity: 1, unitPrice: 2.95, totalPrice: 2.95, category: "Food", description: "Warmed")
                ],
                subtotal: 7.70,
                tip: 1.15,
                itemsTotal: 7.70
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                merchant: "Shell Gas Station",
                amount: 45.20,
                currency: "USD",
                category: "Transportation",
                description: "Fuel",
                paymentMethod: "Debit Card",
                taxAmount: 3.62,
                items: [
                    ExpenseItem(name: "Regular Gasoline", quantity: 12.5, unitPrice: 3.45, totalPrice: 43.13, category: "Fuel", description: "12.5 gallons")
                ],
                subtotal: 43.13,
                fees: 2.07,
                itemsTotal: 43.13
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                merchant: "Tesco Extra",
                amount: 28.50,
                currency: "EUR",
                category: "Shopping",
                description: "Grocery shopping",
                paymentMethod: "Credit Card",
                taxAmount: 2.85,
                items: [
                    ExpenseItem(name: "Organic Bananas", quantity: 1.2, unitPrice: 2.99, totalPrice: 3.59, category: "Food", description: "1.2 kg"),
                    ExpenseItem(name: "Whole Milk", quantity: 2, unitPrice: 1.25, totalPrice: 2.50, category: "Food", description: "1L cartons"),
                    ExpenseItem(name: "Bread Loaf", quantity: 1, unitPrice: 1.89, totalPrice: 1.89, category: "Food", description: "Whole grain")
                ],
                subtotal: 25.65,
                itemsTotal: 7.98
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                merchant: "Target",
                amount: 23.99,
                currency: "USD",
                category: "Shopping",
                description: "Household items",
                paymentMethod: "Credit Card",
                taxAmount: 1.92,
                items: [
                    ExpenseItem(name: "Tide Laundry Detergent", quantity: 1, unitPrice: 12.99, totalPrice: 12.99, category: "Household", description: "64 oz"),
                    ExpenseItem(name: "Paper Towels", quantity: 2, unitPrice: 4.50, totalPrice: 9.00, category: "Household", description: "6-pack")
                ],
                subtotal: 21.99,
                itemsTotal: 21.99
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                merchant: "Chipotle Mexican Grill",
                amount: 12.85,
                currency: "USD",
                category: "Food & Dining",
                description: "Burrito bowl and drink",
                paymentMethod: "Digital Payment",
                taxAmount: 1.03,
                items: [
                    ExpenseItem(name: "Chicken Burrito Bowl", quantity: 1, unitPrice: 9.45, totalPrice: 9.45, category: "Food", description: "Brown rice, black beans, mild salsa"),
                    ExpenseItem(name: "Fountain Drink", quantity: 1, unitPrice: 2.75, totalPrice: 2.75, category: "Beverage", description: "Large")
                ],
                subtotal: 12.20,
                itemsTotal: 12.20
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                merchant: "Amazon.com",
                amount: 89.99,
                currency: "USD",
                category: "Shopping",
                description: "Office supplies",
                paymentMethod: "Credit Card",
                taxAmount: 7.20,
                items: [
                    ExpenseItem(name: "Wireless Mouse", quantity: 1, unitPrice: 29.99, totalPrice: 29.99, category: "Electronics", description: "Logitech MX Master 3"),
                    ExpenseItem(name: "USB-C Hub", quantity: 1, unitPrice: 45.99, totalPrice: 45.99, category: "Electronics", description: "7-in-1"),
                    ExpenseItem(name: "Notebook", quantity: 3, unitPrice: 4.99, totalPrice: 14.97, category: "Office", description: "Lined, A5 size")
                ],
                subtotal: 90.95,
                discounts: -8.16,
                itemsTotal: 90.95
            )
        ]
        
        for expense in sampleExpenses {
            _ = try? addExpense(expense)
        }
        
        // Added sample expenses for first launch
    }
}

import XCTest
@testable import ExpenseManager

final class ModelTests: XCTestCase {
    
    // MARK: - Expense Model Tests
    
    func testExpenseInitialization() {
        // Given
        let id = UUID()
        let date = Date()
        let merchant = "Test Merchant"
        let amount = 25.99
        let currency = "USD"
        let category = "Food & Dining"
        
        // When
        let expense = Expense(
            id: id,
            date: date,
            merchant: merchant,
            amount: amount,
            currency: currency,
            category: category,
            description: nil,
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        // Then
        XCTAssertEqual(expense.id, id)
        XCTAssertEqual(expense.date, date)
        XCTAssertEqual(expense.merchant, merchant)
        XCTAssertEqual(expense.amount, amount, accuracy: 0.001)
        XCTAssertEqual(expense.currency, currency)
        XCTAssertEqual(expense.category, category)
        XCTAssertNil(expense.description)
        XCTAssertNil(expense.paymentMethod)
        XCTAssertNil(expense.items)
        XCTAssertNil(expense.taxAmount)
        XCTAssertNil(expense.subtotal)
        XCTAssertNil(expense.tip)
        XCTAssertNil(expense.fees)
    }
    
    func testExpenseWithAllFields() {
        // Given
        let items = [
            ExpenseItem(
                id: UUID(),
                name: "Coffee",
                quantity: 2,
                unitPrice: 4.50,
                totalPrice: 9.00,
                category: "Beverages",
                description: "Large coffee"
            )
        ]
        
        // When
        let expense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Coffee Shop",
            amount: 12.50,
            currency: "USD",
            category: "Food & Dining",
            description: "Morning coffee",
            paymentMethod: "Credit Card",
            items: items,
            taxAmount: 1.00,
            subtotal: 10.00,
            tip: 1.50,
            fees: 0.0
        )
        
        // Then
        XCTAssertNotNil(expense.description)
        XCTAssertNotNil(expense.paymentMethod)
        XCTAssertNotNil(expense.items)
        XCTAssertEqual(expense.items?.count, 1)
        XCTAssertNotNil(expense.taxAmount)
        XCTAssertNotNil(expense.subtotal)
        XCTAssertNotNil(expense.tip)
        XCTAssertNotNil(expense.fees)
    }
    
    func testExpenseFormattedAmount() {
        // Given
        let expense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Test",
            amount: 123.45,
            currency: "USD",
            category: "Test",
            description: nil,
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        // When
        let formatted = expense.formattedAmount
        
        // Then
        XCTAssertTrue(formatted.contains("123.45"))
        XCTAssertTrue(formatted.contains("USD"))
    }
    
    // MARK: - ExpenseItem Model Tests
    
    func testExpenseItemInitialization() {
        // Given
        let id = UUID()
        let name = "Test Item"
        let quantity: Double = 2.5
        let unitPrice = 10.00
        let totalPrice = 25.00
        let category = "Test Category"
        let description = "Test description"
        
        // When
        let item = ExpenseItem(
            id: id,
            name: name,
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            category: category,
            description: description
        )
        
        // Then
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.name, name)
        XCTAssertEqual(item.quantity, quantity)
        XCTAssertEqual(item.unitPrice, unitPrice, accuracy: 0.001)
        XCTAssertEqual(item.totalPrice, totalPrice, accuracy: 0.001)
        XCTAssertEqual(item.category, category)
        XCTAssertEqual(item.description, description)
    }
    
    func testExpenseItemWithNilOptionals() {
        // When
        let item = ExpenseItem(
            id: UUID(),
            name: "Test Item",
            quantity: nil,
            unitPrice: nil,
            totalPrice: 10.00,
            category: nil,
            description: nil
        )
        
        // Then
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.name, "Test Item")
        XCTAssertNil(item.quantity)
        XCTAssertNil(item.unitPrice)
        XCTAssertEqual(item.totalPrice, 10.00)
        XCTAssertNil(item.category)
        XCTAssertNil(item.description)
    }
    
    // MARK: - Codable Tests
    
    func testExpenseCodable() throws {
        // Given
        let originalExpense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Test Merchant",
            amount: 42.50,
            currency: "EUR",
            category: "Shopping",
            description: "Test purchase",
            paymentMethod: "Cash",
            items: [
                ExpenseItem(
                    id: UUID(),
                    name: "Test Item",
                    quantity: 1,
                    unitPrice: 42.50,
                    totalPrice: 42.50,
                    category: "Electronics",
                    description: "Test item description"
                )
            ],
            taxAmount: 3.40,
            subtotal: 39.10,
            tip: nil,
            fees: nil
        )
        
        // When - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalExpense)
        
        // Then - Decode
        let decoder = JSONDecoder()
        let decodedExpense = try decoder.decode(Expense.self, from: data)
        
        // Verify
        XCTAssertEqual(decodedExpense.id, originalExpense.id)
        XCTAssertEqual(decodedExpense.merchant, originalExpense.merchant)
        XCTAssertEqual(decodedExpense.amount, originalExpense.amount, accuracy: 0.001)
        XCTAssertEqual(decodedExpense.currency, originalExpense.currency)
        XCTAssertEqual(decodedExpense.category, originalExpense.category)
        XCTAssertEqual(decodedExpense.description, originalExpense.description)
        XCTAssertEqual(decodedExpense.paymentMethod, originalExpense.paymentMethod)
        XCTAssertEqual(decodedExpense.items?.count, originalExpense.items?.count)
        XCTAssertEqual(decodedExpense.taxAmount, originalExpense.taxAmount)
        XCTAssertEqual(decodedExpense.subtotal, originalExpense.subtotal)
    }
    
    func testExpenseItemCodable() throws {
        // Given
        let originalItem = ExpenseItem(
            id: UUID(),
            name: "Codable Test Item",
            quantity: 3.5,
            unitPrice: 12.99,
            totalPrice: 45.47,
            category: "Test Category",
            description: "Codable test description"
        )
        
        // When - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalItem)
        
        // Then - Decode
        let decoder = JSONDecoder()
        let decodedItem = try decoder.decode(ExpenseItem.self, from: data)
        
        // Verify
        XCTAssertEqual(decodedItem.id, originalItem.id)
        XCTAssertEqual(decodedItem.name, originalItem.name)
        XCTAssertEqual(decodedItem.quantity, originalItem.quantity)
        XCTAssertEqual(decodedItem.unitPrice, originalItem.unitPrice, accuracy: 0.001)
        XCTAssertEqual(decodedItem.totalPrice, originalItem.totalPrice, accuracy: 0.001)
        XCTAssertEqual(decodedItem.category, originalItem.category)
        XCTAssertEqual(decodedItem.description, originalItem.description)
    }
    
    func testExpenseArrayCodable() throws {
        // Given
        let expenses = [
            Expense(
                id: UUID(),
                date: Date(),
                merchant: "Merchant 1",
                amount: 10.00,
                currency: "USD",
                category: "Food",
                description: nil,
                paymentMethod: nil,
                items: nil,
                taxAmount: nil,
                subtotal: nil,
                tip: nil,
                fees: nil
            ),
            Expense(
                id: UUID(),
                date: Date(),
                merchant: "Merchant 2",
                amount: 20.00,
                currency: "EUR",
                category: "Shopping",
                description: nil,
                paymentMethod: nil,
                items: nil,
                taxAmount: nil,
                subtotal: nil,
                tip: nil,
                fees: nil
            )
        ]
        
        // When - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(expenses)
        
        // Then - Decode
        let decoder = JSONDecoder()
        let decodedExpenses = try decoder.decode([Expense].self, from: data)
        
        // Verify
        XCTAssertEqual(decodedExpenses.count, expenses.count)
        XCTAssertEqual(decodedExpenses[0].merchant, "Merchant 1")
        XCTAssertEqual(decodedExpenses[1].merchant, "Merchant 2")
        XCTAssertEqual(decodedExpenses[0].amount, 10.00, accuracy: 0.001)
        XCTAssertEqual(decodedExpenses[1].amount, 20.00, accuracy: 0.001)
    }
    
    // MARK: - Error Model Tests
    
    func testExpenseManagerErrorDescriptions() {
        // Test error descriptions
        XCTAssertEqual(
            ExpenseManagerError.invalidAmount.errorDescription,
            "Invalid expense amount"
        )
        
        XCTAssertEqual(
            ExpenseManagerError.invalidDate.errorDescription,
            "Invalid expense date"
        )
        
        XCTAssertEqual(
            ExpenseManagerError.apiKeyMissing.errorDescription,
            "OpenAI API key is missing"
        )
        
        XCTAssertEqual(
            ExpenseManagerError.imageProcessingFailed.errorDescription,
            "Failed to process receipt image"
        )
        
        XCTAssertEqual(
            ExpenseManagerError.dataCorruption.errorDescription,
            "Data corruption detected"
        )
        
        XCTAssertEqual(
            ExpenseManagerError.invalidExpenseData.errorDescription,
            "Invalid expense data"
        )
    }
    
    func testExpenseManagerErrorRecoveryDescriptions() {
        // Test recovery suggestions
        XCTAssertEqual(
            ExpenseManagerError.apiKeyMissing.recoveryDescription,
            "Please add your OpenAI API key in Settings"
        )
        
        XCTAssertEqual(
            ExpenseManagerError.invalidAmount.recoveryDescription,
            "Please check your input and try again"
        )
        
        XCTAssertEqual(
            ExpenseManagerError.imageProcessingFailed.recoveryDescription,
            "Try selecting a clearer image of your receipt"
        )
    }
    
    func testNetworkErrorWithUnderlyingError() {
        // Given
        let underlyingError = URLError(.notConnectedToInternet)
        let networkError = ExpenseManagerError.networkError(underlying: underlyingError)
        
        // When
        let description = networkError.errorDescription
        
        // Then
        XCTAssertTrue(description?.contains("Network error") == true)
        XCTAssertTrue(description?.contains("not connected") == true)
    }
    
    func testPersistenceErrorWithUnderlyingError() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test persistence error"])
        let persistenceError = ExpenseManagerError.persistenceError(underlying: underlyingError)
        
        // When
        let description = persistenceError.errorDescription
        
        // Then
        XCTAssertTrue(description?.contains("Failed to save data") == true)
        XCTAssertTrue(description?.contains("Test persistence error") == true)
    }
}
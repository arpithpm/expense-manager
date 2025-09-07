import XCTest
@testable import ExpenseManager

final class ExpenseServiceTests: XCTestCase {
    
    var sut: ExpenseService!
    var mockUserDefaults: UserDefaults!
    
    override func setUpWithError() throws {
        // Create a mock UserDefaults for testing
        mockUserDefaults = UserDefaults(suiteName: "test_suite")
        mockUserDefaults.removePersistentDomain(forName: "test_suite")
        
        // Initialize ExpenseService with mock UserDefaults
        sut = ExpenseService()
        
        // Replace the userDefaults instance using reflection or dependency injection
        // For now, we'll test with the understanding that UserDefaults operations happen
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockUserDefaults.removePersistentDomain(forName: "test_suite")
        mockUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Expense Addition Tests
    
    func testAddValidExpense() throws {
        // Given
        let validExpense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Test Merchant",
            amount: 25.50,
            currency: "USD",
            category: "Food & Dining",
            description: "Test expense",
            paymentMethod: "Credit Card",
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        let initialCount = sut.expenses.count
        
        // When
        let addedExpense = try sut.addExpense(validExpense)
        
        // Then
        XCTAssertEqual(sut.expenses.count, initialCount + 1)
        XCTAssertEqual(addedExpense.id, validExpense.id)
        XCTAssertEqual(addedExpense.merchant, "Test Merchant")
        XCTAssertEqual(addedExpense.amount, 25.50)
    }
    
    func testAddExpenseWithZeroAmount() {
        // Given
        let invalidExpense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Test Merchant",
            amount: 0.0, // Invalid amount
            currency: "USD",
            category: "Food & Dining",
            description: nil,
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        // When & Then
        XCTAssertThrowsError(try sut.addExpense(invalidExpense)) { error in
            guard let expenseError = error as? ExpenseManagerError else {
                XCTFail("Expected ExpenseManagerError")
                return
            }
            XCTAssertEqual(expenseError, ExpenseManagerError.invalidAmount)
        }
    }
    
    func testAddExpenseWithNegativeAmount() {
        // Given
        let invalidExpense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Test Merchant",
            amount: -10.0, // Invalid negative amount
            currency: "USD",
            category: "Food & Dining",
            description: nil,
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        // When & Then
        XCTAssertThrowsError(try sut.addExpense(invalidExpense)) { error in
            guard let expenseError = error as? ExpenseManagerError else {
                XCTFail("Expected ExpenseManagerError")
                return
            }
            XCTAssertEqual(expenseError, ExpenseManagerError.invalidAmount)
        }
    }
    
    func testAddExpenseWithFutureDate() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invalidExpense = Expense(
            id: UUID(),
            date: futureDate, // Future date - invalid
            merchant: "Test Merchant",
            amount: 25.50,
            currency: "USD",
            category: "Food & Dining",
            description: nil,
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        // When & Then
        XCTAssertThrowsError(try sut.addExpense(invalidExpense)) { error in
            guard let expenseError = error as? ExpenseManagerError else {
                XCTFail("Expected ExpenseManagerError")
                return
            }
            XCTAssertEqual(expenseError, ExpenseManagerError.invalidDate)
        }
    }
    
    func testAddExpenseWithEmptyMerchant() {
        // Given
        let invalidExpense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "   ", // Empty/whitespace merchant - invalid
            amount: 25.50,
            currency: "USD",
            category: "Food & Dining",
            description: nil,
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        // When & Then
        XCTAssertThrowsError(try sut.addExpense(invalidExpense)) { error in
            guard let expenseError = error as? ExpenseManagerError else {
                XCTFail("Expected ExpenseManagerError")
                return
            }
            XCTAssertEqual(expenseError, ExpenseManagerError.invalidExpenseData)
        }
    }
    
    // MARK: - Expense Deletion Tests
    
    func testDeleteExistingExpense() throws {
        // Given
        let expense = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Test Merchant",
            amount: 25.50,
            currency: "USD",
            category: "Food & Dining",
            description: nil,
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        _ = try sut.addExpense(expense)
        let countAfterAdd = sut.expenses.count
        
        // When
        try sut.deleteExpense(expense)
        
        // Then
        XCTAssertEqual(sut.expenses.count, countAfterAdd - 1)
        XCTAssertFalse(sut.expenses.contains { $0.id == expense.id })
    }
    
    // MARK: - Currency Tests
    
    func testGetPrimaryCurrency() {
        // When
        let primaryCurrency = sut.getPrimaryCurrency()
        
        // Then
        XCTAssertNotNil(primaryCurrency)
        XCTAssertFalse(primaryCurrency.isEmpty)
    }
    
    func testGetTotalInPrimaryCurrency() throws {
        // Given
        let expense1 = Expense(id: UUID(), date: Date(), merchant: "Merchant1", amount: 10.0, currency: "USD", category: "Food", description: nil, paymentMethod: nil, items: nil, taxAmount: nil, subtotal: nil, tip: nil, fees: nil)
        let expense2 = Expense(id: UUID(), date: Date(), merchant: "Merchant2", amount: 15.0, currency: "USD", category: "Food", description: nil, paymentMethod: nil, items: nil, taxAmount: nil, subtotal: nil, tip: nil, fees: nil)
        
        _ = try sut.addExpense(expense1)
        _ = try sut.addExpense(expense2)
        
        // When
        let total = sut.getTotalInPrimaryCurrency()
        
        // Then
        XCTAssertGreaterThanOrEqual(total, 25.0)
    }
    
    // MARK: - Demo Data Tests
    
    func testHasDemoData() {
        // When
        let hasDemoData = sut.hasDemoData()
        
        // Then
        // Should be false initially (no demo data)
        XCTAssertFalse(hasDemoData)
    }
    
    func testClearDemoData() {
        // Given - Add some demo data first
        sut.addDemoData()
        XCTAssertTrue(sut.hasDemoData())
        
        // When
        sut.clearDemoData()
        
        // Then
        XCTAssertFalse(sut.hasDemoData())
    }
    
    // MARK: - Performance Tests
    
    func testAddExpensePerformance() {
        let expense = Expense(id: UUID(), date: Date(), merchant: "Test", amount: 10.0, currency: "USD", category: "Food", description: nil, paymentMethod: nil, items: nil, taxAmount: nil, subtotal: nil, tip: nil, fees: nil)
        
        measure {
            do {
                _ = try sut.addExpense(expense)
                // Clean up for next iteration
                sut.expenses.removeAll()
            } catch {
                XCTFail("Should not throw error: \(error)")
            }
        }
    }
}

// MARK: - ExpenseManagerError Equatable Extension for Testing

extension ExpenseManagerError: Equatable {
    public static func == (lhs: ExpenseManagerError, rhs: ExpenseManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAmount, .invalidAmount),
             (.invalidDate, .invalidDate),
             (.dataCorruption, .dataCorruption),
             (.apiKeyMissing, .apiKeyMissing),
             (.imageProcessingFailed, .imageProcessingFailed),
             (.invalidExpenseData, .invalidExpenseData):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.persistenceError(let lhsError), .persistenceError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
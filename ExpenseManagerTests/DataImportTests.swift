import XCTest
@testable import ExpenseManager

final class DataImportTests: XCTestCase {
    
    var expenseService: ExpenseService!
    var dataExporter: DataExporter!
    var testFileURL: URL!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Reset ExpenseService state
        expenseService = ExpenseService.shared
        dataExporter = DataExporter()
        
        // Create temporary directory for test files
        tempDirectory = try createTestDirectory(name: "DataImportTests")
        testFileURL = tempDirectory.appendingPathComponent("test_import.json")
    }
    
    override func tearDownWithError() throws {
        // Clean up test data and files
        expenseService.expenses.removeAll()
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    // MARK: - JSON Generation and Validation Tests
    
    func testGenerateSampleImportFile() async throws {
        let sampleFileURL = try await dataExporter.generateSampleImportFile()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: sampleFileURL.path))
        
        let data = try Data(contentsOf: sampleFileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["expenses"] as? [[String: Any]])
        XCTAssertNotNil(json?["exportDate"] as? String)
        XCTAssertNotNil(json?["version"] as? String)
        
        let expenses = json?["expenses"] as? [[String: Any]]
        XCTAssertTrue(!expenses!.isEmpty)
        
        // Verify sample expenses have required fields
        for expense in expenses! {
            XCTAssertNotNil(expense["merchant"] as? String)
            XCTAssertNotNil(expense["amount"] as? Double)
            XCTAssertNotNil(expense["currency"] as? String)
            XCTAssertNotNil(expense["category"] as? String)
            XCTAssertNotNil(expense["date"] as? String)
        }
    }
    
    func testValidateImportFileWithValidJSON() async throws {
        // Create valid test JSON
        let validJSON = createValidTestJSON()
        try validJSON.write(to: testFileURL)
        
        let summary = try await dataExporter.validateImportFile(url: testFileURL)
        
        XCTAssertEqual(summary.totalExpenses, 2)
        XCTAssertTrue(summary.totalAmount > 0)
        XCTAssertTrue(summary.categories.contains("Food & Dining"))
        XCTAssertTrue(summary.currencies.contains("USD"))
        XCTAssertNotNil(summary.dateRange)
        XCTAssertTrue(summary.hasItems)
        XCTAssertTrue(summary.hasFinancialBreakdown)
    }
    
    func testValidateImportFileWithInvalidJSON() async throws {
        // Create invalid JSON (missing expenses array)
        let invalidJSON = """
        {
            "exportDate": "2025-01-01T00:00:00Z",
            "version": "1.0.0",
            "invalidStructure": true
        }
        """.data(using: .utf8)!
        
        try invalidJSON.write(to: testFileURL)
        
        do {
            _ = try await dataExporter.validateImportFile(url: testFileURL)
            XCTFail("Should have thrown error for invalid JSON structure")
        } catch {
            XCTAssertTrue(error is ExpenseManagerError)
        }
    }
    
    func testValidateImportFileWithMissingFields() async throws {
        // Create JSON with expenses missing required fields
        let invalidExpenseJSON = """
        {
            "expenses": [
                {
                    "merchant": "Test Store",
                    "currency": "USD",
                    "category": "Shopping"
                }
            ]
        }
        """.data(using: .utf8)!
        
        try invalidExpenseJSON.write(to: testFileURL)
        
        do {
            _ = try await dataExporter.validateImportFile(url: testFileURL)
            XCTFail("Should have thrown error for missing amount field")
        } catch {
            XCTAssertTrue(error is ExpenseManagerError)
        }
    }
    
    // MARK: - Import Process Tests
    
    func testImportExpensesSuccessfully() async throws {
        // Create valid test JSON
        let validJSON = createValidTestJSON()
        try validJSON.write(to: testFileURL)
        
        // Import the expenses
        let result = try await dataExporter.importExpenses(
            from: testFileURL,
            expenseService: expenseService
        )
        
        XCTAssertEqual(result.importedCount, 2)
        XCTAssertEqual(result.duplicateCount, 0)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertTrue(result.errors.isEmpty)
        
        // Verify expenses were added to service
        XCTAssertEqual(expenseService.expenses.count, 2)
        
        let firstExpense = expenseService.expenses.first!
        XCTAssertEqual(firstExpense.merchant, "Test Grocery Store")
        XCTAssertEqual(firstExpense.amount, 45.67)
        XCTAssertEqual(firstExpense.currency, "USD")
        XCTAssertNotNil(firstExpense.items)
        XCTAssertEqual(firstExpense.items?.count, 2)
    }
    
    func testImportExpensesWithDuplicates() async throws {
        // Add an initial expense
        let initialExpense = createStandardTestExpense(
            merchant: "Test Grocery Store",
            amount: 45.67
        )
        _ = try expenseService.addExpense(initialExpense)
        
        // Create JSON with similar expense
        let validJSON = createValidTestJSON()
        try validJSON.write(to: testFileURL)
        
        let result = try await dataExporter.importExpenses(
            from: testFileURL,
            expenseService: expenseService
        )
        
        // Should detect duplicate and skip it
        XCTAssertTrue(result.duplicateCount > 0)
        XCTAssertTrue(result.importedCount < 2)
    }
    
    func testImportExpensesWithProgress() async throws {
        let validJSON = createValidTestJSON()
        try validJSON.write(to: testFileURL)
        
        var progressValues: [Double] = []
        
        _ = try await dataExporter.importExpenses(
            from: testFileURL,
            expenseService: expenseService
        ) { progress in
            progressValues.append(progress)
        }
        
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 1.0)
        XCTAssertTrue(progressValues.first! >= 0.0)
    }
    
    func testImportExpensesWithParsingErrors() async throws {
        // Create JSON with some valid and some invalid expenses
        let mixedJSON = """
        {
            "expenses": [
                {
                    "id": "\(UUID().uuidString)",
                    "date": "2025-01-01T12:00:00Z",
                    "merchant": "Valid Store",
                    "amount": 25.99,
                    "currency": "USD",
                    "category": "Shopping",
                    "description": "Valid expense"
                },
                {
                    "id": "\(UUID().uuidString)",
                    "date": "invalid-date",
                    "merchant": "",
                    "amount": -10.0,
                    "currency": "USD",
                    "category": "Shopping",
                    "description": "Invalid expense"
                }
            ]
        }
        """.data(using: .utf8)!
        
        try mixedJSON.write(to: testFileURL)
        
        let result = try await dataExporter.importExpenses(
            from: testFileURL,
            expenseService: expenseService
        )
        
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertEqual(expenseService.expenses.count, 1)
    }
    
    // MARK: - ExpenseService Import Methods Tests
    
    func testAddImportedExpensesWithValidExpenses() throws {
        let testExpenses = [
            createStandardTestExpense(merchant: "Store A", amount: 10.0),
            createStandardTestExpense(merchant: "Store B", amount: 20.0)
        ]
        
        let result = try expenseService.addImportedExpenses(testExpenses, allowDuplicates: false)
        
        XCTAssertEqual(result.importedCount, 2)
        XCTAssertEqual(result.duplicateCount, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(expenseService.expenses.count, 2)
    }
    
    func testAddImportedExpensesWithDuplicates() throws {
        // Add initial expense
        let originalExpense = createStandardTestExpense(merchant: "Test Store", amount: 25.0)
        _ = try expenseService.addExpense(originalExpense)
        
        // Try to import duplicate
        let duplicateExpense = createStandardTestExpense(merchant: "Test Store", amount: 25.0)
        let result = try expenseService.addImportedExpenses([duplicateExpense], allowDuplicates: false)
        
        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(expenseService.expenses.count, 1)
    }
    
    func testAddImportedExpensesAllowingDuplicates() throws {
        let originalExpense = createStandardTestExpense(merchant: "Test Store", amount: 25.0)
        _ = try expenseService.addExpense(originalExpense)
        
        let duplicateExpense = createStandardTestExpense(merchant: "Test Store", amount: 25.0)
        let result = try expenseService.addImportedExpenses([duplicateExpense], allowDuplicates: true)
        
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.duplicateCount, 0)
        XCTAssertEqual(expenseService.expenses.count, 2)
    }
    
    func testValidateImportedExpenses() {
        let validExpenses = [
            createStandardTestExpense(merchant: "Valid Store", amount: 10.0)
        ]
        
        let invalidExpenses = [
            createStandardTestExpense(merchant: "", amount: -10.0), // Invalid merchant and amount
            createStandardTestExpense(merchant: "Future Store", amount: 20.0) // Will be modified to have future date
        ]
        
        // Modify second expense to have future date
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let futureExpense = Expense(
            id: invalidExpenses[1].id,
            date: futureDate,
            merchant: invalidExpenses[1].merchant,
            amount: invalidExpenses[1].amount,
            currency: invalidExpenses[1].currency,
            category: invalidExpenses[1].category,
            description: invalidExpenses[1].description,
            paymentMethod: invalidExpenses[1].paymentMethod
        )
        
        let allExpenses = validExpenses + [invalidExpenses[0], futureExpense]
        let errors = expenseService.validateImportedExpenses(allExpenses)
        
        XCTAssertEqual(errors.count, 3) // Invalid amount, empty merchant, future date
        XCTAssertTrue(errors.contains { $0.contains("Invalid amount") })
        XCTAssertTrue(errors.contains { $0.contains("Empty merchant") })
        XCTAssertTrue(errors.contains { $0.contains("Future date") })
    }
    
    func testGenerateImportSummary() {
        let testExpenses = [
            createStandardTestExpense(
                merchant: "Store A",
                amount: 25.99,
                category: "Shopping",
                includeItems: true
            ),
            createStandardTestExpense(
                merchant: "Store B",
                amount: 15.50,
                category: "Food & Dining",
                includeItems: false
            )
        ]
        
        let summary = expenseService.generateImportSummary(for: testExpenses)
        
        XCTAssertEqual(summary.totalExpenses, 2)
        XCTAssertEqual(summary.totalAmount, 41.49, accuracy: 0.01)
        XCTAssertTrue(summary.categories.contains("Shopping"))
        XCTAssertTrue(summary.categories.contains("Food & Dining"))
        XCTAssertTrue(summary.currencies.contains("USD"))
        XCTAssertNotNil(summary.dateRange)
        XCTAssertTrue(summary.hasItems)
    }
    
    func testGenerateImportSummaryWithEmptyArray() {
        let summary = expenseService.generateImportSummary(for: [])
        
        XCTAssertEqual(summary.totalExpenses, 0)
        XCTAssertEqual(summary.totalAmount, 0.0)
        XCTAssertTrue(summary.categories.isEmpty)
        XCTAssertTrue(summary.currencies.isEmpty)
        XCTAssertNil(summary.dateRange)
        XCTAssertFalse(summary.hasItems)
        XCTAssertFalse(summary.hasFinancialBreakdown)
    }
    
    // MARK: - Duplicate Detection Tests
    
    func testDuplicateDetectionByID() throws {
        let originalExpense = createStandardTestExpense(merchant: "Test Store", amount: 25.0)
        _ = try expenseService.addExpense(originalExpense)
        
        // Create expense with same ID
        let sameIDExpense = Expense(
            id: originalExpense.id, // Same ID
            date: originalExpense.date,
            merchant: "Different Store", // Different merchant
            amount: 50.0, // Different amount
            currency: originalExpense.currency,
            category: originalExpense.category,
            description: "Different description",
            paymentMethod: originalExpense.paymentMethod
        )
        
        let result = try expenseService.addImportedExpenses([sameIDExpense], allowDuplicates: false)
        
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.importedCount, 0)
    }
    
    func testDuplicateDetectionBySimilarity() throws {
        let originalExpense = createStandardTestExpense(
            merchant: "Target Store",
            amount: 99.99
        )
        _ = try expenseService.addExpense(originalExpense)
        
        // Create similar expense (same merchant, amount, similar date)
        let similarExpense = Expense(
            id: UUID(), // Different ID
            date: originalExpense.date, // Same date
            merchant: "Target Store", // Same merchant (case insensitive)
            amount: 99.99, // Same amount
            currency: originalExpense.currency,
            category: "Different Category", // Different category
            description: "Different description",
            paymentMethod: "Different Payment"
        )
        
        let result = try expenseService.addImportedExpenses([similarExpense], allowDuplicates: false)
        
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.importedCount, 0)
    }
    
    func testNonDuplicateDetection() throws {
        let originalExpense = createStandardTestExpense(
            merchant: "Store A",
            amount: 25.0
        )
        _ = try expenseService.addExpense(originalExpense)
        
        // Create genuinely different expense
        let differentExpense = createStandardTestExpense(
            merchant: "Store B", // Different merchant
            amount: 50.0 // Different amount
        )
        
        let result = try expenseService.addImportedExpenses([differentExpense], allowDuplicates: false)
        
        XCTAssertEqual(result.duplicateCount, 0)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(expenseService.expenses.count, 2)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    func testImportEmptyFile() async throws {
        let emptyJSON = "{}".data(using: .utf8)!
        try emptyJSON.write(to: testFileURL)
        
        do {
            _ = try await dataExporter.validateImportFile(url: testFileURL)
            XCTFail("Should have thrown error for empty file")
        } catch {
            XCTAssertTrue(error is ExpenseManagerError)
        }
    }
    
    func testImportNonJSONFile() async throws {
        let textData = "This is not JSON".data(using: .utf8)!
        try textData.write(to: testFileURL)
        
        do {
            _ = try await dataExporter.validateImportFile(url: testFileURL)
            XCTFail("Should have thrown error for non-JSON file")
        } catch {
            XCTAssertTrue(error is ExpenseManagerError)
        }
    }
    
    func testImportNonExistentFile() async throws {
        let nonExistentURL = tempDirectory.appendingPathComponent("does_not_exist.json")
        
        do {
            _ = try await dataExporter.validateImportFile(url: nonExistentURL)
            XCTFail("Should have thrown error for non-existent file")
        } catch {
            // Expected behavior
        }
    }
    
    func testImportLargeFile() async throws {
        // Create JSON with many expenses
        let manyExpenses = (1...100).map { index in
            """
            {
                "id": "\(UUID().uuidString)",
                "date": "2025-01-0\(index % 9 + 1)T12:00:00Z",
                "merchant": "Store \(index)",
                "amount": \(Double(index) * 1.99),
                "currency": "USD",
                "category": "Shopping",
                "description": "Expense \(index)"
            }
            """
        }.joined(separator: ",\n")
        
        let largeJSON = """
        {
            "expenses": [\(manyExpenses)]
        }
        """.data(using: .utf8)!
        
        try largeJSON.write(to: testFileURL)
        
        let summary = try await dataExporter.validateImportFile(url: testFileURL)
        XCTAssertEqual(summary.totalExpenses, 100)
        
        let result = try await dataExporter.importExpenses(
            from: testFileURL,
            expenseService: expenseService
        )
        
        XCTAssertEqual(result.importedCount, 100)
        XCTAssertEqual(expenseService.expenses.count, 100)
    }
    
    // MARK: - Helper Methods
    
    private func createValidTestJSON() -> Data {
        let jsonString = """
        {
            "exportDate": "2025-01-01T12:00:00Z",
            "version": "2.1.0",
            "totalExpenses": 2,
            "totalAmount": 68.17,
            "includeItems": true,
            "includeFinancialBreakdown": true,
            "expenses": [
                {
                    "id": "\(UUID().uuidString)",
                    "date": "2024-12-30T15:30:00Z",
                    "merchant": "Test Grocery Store",
                    "amount": 45.67,
                    "currency": "USD",
                    "category": "Food & Dining",
                    "description": "Weekly groceries",
                    "paymentMethod": "Credit Card",
                    "taxAmount": 3.20,
                    "subtotal": 42.47,
                    "tip": 0,
                    "fees": 0,
                    "items": [
                        {
                            "id": "\(UUID().uuidString)",
                            "name": "Organic Milk",
                            "quantity": 1,
                            "unitPrice": 4.99,
                            "totalPrice": 4.99,
                            "category": "Dairy",
                            "description": "1L organic whole milk"
                        },
                        {
                            "id": "\(UUID().uuidString)",
                            "name": "Whole Wheat Bread",
                            "quantity": 2,
                            "unitPrice": 3.50,
                            "totalPrice": 7.00,
                            "category": "Bakery",
                            "description": "Fresh baked bread"
                        }
                    ]
                },
                {
                    "id": "\(UUID().uuidString)",
                    "date": "2024-12-29T09:15:00Z",
                    "merchant": "Coffee Shop Downtown",
                    "amount": 22.50,
                    "currency": "USD",
                    "category": "Food & Dining",
                    "description": "Morning coffee meeting",
                    "paymentMethod": "Debit Card",
                    "taxAmount": 1.80,
                    "subtotal": 19.70,
                    "tip": 1.00,
                    "fees": 0,
                    "items": [
                        {
                            "id": "\(UUID().uuidString)",
                            "name": "Large Cappuccino",
                            "quantity": 2,
                            "unitPrice": 5.50,
                            "totalPrice": 11.00,
                            "category": "Beverages",
                            "description": "Extra shot, oat milk"
                        },
                        {
                            "id": "\(UUID().uuidString)",
                            "name": "Almond Croissant",
                            "quantity": 2,
                            "unitPrice": 4.35,
                            "totalPrice": 8.70,
                            "category": "Pastries",
                            "description": "Freshly baked"
                        }
                    ]
                }
            ]
        }
        """
        return jsonString.data(using: .utf8)!
    }
}
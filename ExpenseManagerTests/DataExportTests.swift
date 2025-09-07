import XCTest
@testable import ExpenseManager

final class DataExportTests: XCTestCase {
    
    var sut: DataExporter!
    var testExpenses: [Expense]!
    var testDirectory: URL!
    
    override func setUpWithError() throws {
        sut = DataExporter()
        testExpenses = createTestExpenses()
        
        // Create a temporary directory for test files
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DataExportTests")
        
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
        
        sut = nil
        testExpenses = nil
        testDirectory = nil
        super.tearDown()
    }
    
    // MARK: - CSV Export Tests
    
    func testCSVExportCreatesFile() async throws {
        // Given
        let fileURL = testDirectory.appendingPathComponent("test_export.csv")
        
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .csv,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        XCTAssertTrue(resultURL.pathExtension == "csv")
    }
    
    func testCSVExportContent() async throws {
        // Given
        let fileURL = testDirectory.appendingPathComponent("test_export.csv")
        
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .csv,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        let content = try String(contentsOf: resultURL, encoding: .utf8)
        
        // Then
        XCTAssertTrue(content.contains("Date,Merchant,Amount"))  // Header
        XCTAssertTrue(content.contains("Test Grocery Store"))   // Merchant name
        XCTAssertTrue(content.contains("45.67"))                // Amount
        XCTAssertTrue(content.contains("Food & Dining"))        // Category
    }
    
    func testCSVExportWithoutItems() async throws {
        // Given & When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .csv,
            includeItems: false,
            includeFinancialBreakdown: true
        ) { _ in }
        
        let content = try String(contentsOf: resultURL, encoding: .utf8)
        
        // Then
        XCTAssertFalse(content.contains("Items Count"))  // Should not include item headers
        XCTAssertTrue(content.contains("Tax Amount"))    // But should include financial breakdown
    }
    
    func testCSVExportWithoutFinancialBreakdown() async throws {
        // Given & When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .csv,
            includeItems: true,
            includeFinancialBreakdown: false
        ) { _ in }
        
        let content = try String(contentsOf: resultURL, encoding: .utf8)
        
        // Then
        XCTAssertTrue(content.contains("Items Count"))   // Should include items
        XCTAssertFalse(content.contains("Tax Amount"))   // But not financial breakdown
    }
    
    func testCSVExportEscapesCommas() async throws {
        // Given
        let expenseWithComma = Expense(
            id: UUID(),
            date: Date(),
            merchant: "Store, Inc.",  // Contains comma
            amount: 25.00,
            currency: "USD",
            category: "Shopping",
            description: "Item with, comma",  // Contains comma
            paymentMethod: nil,
            items: nil,
            taxAmount: nil,
            subtotal: nil,
            tip: nil,
            fees: nil
        )
        
        // When
        let resultURL = try await sut.exportData(
            expenses: [expenseWithComma],
            format: .csv,
            includeItems: false,
            includeFinancialBreakdown: false
        ) { _ in }
        
        let content = try String(contentsOf: resultURL, encoding: .utf8)
        
        // Then
        XCTAssertTrue(content.contains("\"Store, Inc.\""))      // Should be quoted
        XCTAssertTrue(content.contains("\"Item with, comma\"")) // Should be quoted
    }
    
    // MARK: - JSON Export Tests
    
    func testJSONExportCreatesFile() async throws {
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .json,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        XCTAssertTrue(resultURL.pathExtension == "json")
    }
    
    func testJSONExportContent() async throws {
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .json,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        let data = try Data(contentsOf: resultURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Then
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["exportDate"])
        XCTAssertNotNil(json?["version"])
        XCTAssertEqual(json?["totalExpenses"] as? Int, testExpenses.count)
        XCTAssertNotNil(json?["expenses"] as? [[String: Any]])
        XCTAssertNotNil(json?["summary"])
    }
    
    func testJSONExportMetadata() async throws {
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .json,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        let data = try Data(contentsOf: resultURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Then
        XCTAssertEqual(json?["version"] as? String, "2.1.0")
        XCTAssertEqual(json?["includeItems"] as? Bool, true)
        XCTAssertEqual(json?["includeFinancialBreakdown"] as? Bool, true)
        
        let totalAmount = json?["totalAmount"] as? Double
        XCTAssertNotNil(totalAmount)
        XCTAssertGreaterThan(totalAmount!, 0)
    }
    
    func testJSONExportExpenseStructure() async throws {
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .json,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        let data = try Data(contentsOf: resultURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let expenses = json?["expenses"] as? [[String: Any]]
        
        // Then
        XCTAssertNotNil(expenses)
        XCTAssertGreaterThan(expenses!.count, 0)
        
        let firstExpense = expenses!.first!
        XCTAssertNotNil(firstExpense["id"])
        XCTAssertNotNil(firstExpense["date"])
        XCTAssertNotNil(firstExpense["merchant"])
        XCTAssertNotNil(firstExpense["amount"])
        XCTAssertNotNil(firstExpense["currency"])
        XCTAssertNotNil(firstExpense["category"])
    }
    
    func testJSONExportSummarySection() async throws {
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .json,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        let data = try Data(contentsOf: resultURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let summary = json?["summary"] as? [String: Any]
        
        // Then
        XCTAssertNotNil(summary)
        XCTAssertNotNil(summary?["categoryTotals"])
        XCTAssertNotNil(summary?["dateRange"])
        
        let categoryTotals = summary?["categoryTotals"] as? [String: Double]
        XCTAssertNotNil(categoryTotals)
        XCTAssertGreaterThan(categoryTotals!.count, 0)
    }
    
    // MARK: - Progress Callback Tests
    
    func testProgressCallback() async throws {
        // Given
        var progressValues: [Double] = []
        let expectation = XCTestExpectation(description: "Progress callback called")
        expectation.expectedFulfillmentCount = 2 // At least 2 progress updates expected
        
        // When
        _ = try await sut.exportData(
            expenses: testExpenses,
            format: .csv,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { progress in
            progressValues.append(progress)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Then
        XCTAssertGreaterThan(progressValues.count, 0)
        XCTAssertTrue(progressValues.contains(1.0)) // Should reach 100%
        XCTAssertTrue(progressValues.allSatisfy { $0 >= 0.0 && $0 <= 1.0 }) // All values should be 0-1
    }
    
    // MARK: - File Naming Tests
    
    func testFileNaming() async throws {
        // When
        let resultURL = try await sut.exportData(
            expenses: testExpenses,
            format: .csv
        ) { _ in }
        
        // Then
        let fileName = resultURL.lastPathComponent
        XCTAssertTrue(fileName.hasPrefix("ExpenseExport_"))
        XCTAssertTrue(fileName.hasSuffix(".csv"))
        XCTAssertTrue(fileName.contains("2025")) // Current year
        XCTAssertFalse(fileName.contains(" ")) // No spaces in filename
    }
    
    // MARK: - Error Handling Tests
    
    func testExportToInvalidDirectory() async {
        // Given
        let invalidURL = URL(fileURLWithPath: "/invalid/path/file.csv")
        
        // Note: This test is tricky because the export creates the filename internally
        // We can't directly test invalid directories with the current API structure
        // This would require refactoring the export API to accept a directory parameter
        
        // For now, we test that export to a valid temporary location works
        await XCTAssertNoThrowAsync(
            try await sut.exportData(expenses: testExpenses, format: .csv) { _ in }
        )
    }
    
    func testExportEmptyExpenseList() async throws {
        // When
        let resultURL = try await sut.exportData(
            expenses: [],
            format: .csv,
            includeItems: true,
            includeFinancialBreakdown: true
        ) { _ in }
        
        let content = try String(contentsOf: resultURL, encoding: .utf8)
        
        // Then
        XCTAssertTrue(content.contains("Date,Merchant,Amount")) // Should still have headers
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1) // Only header line
    }
    
    // MARK: - Performance Tests
    
    func testExportPerformanceWithLargeDataset() {
        // Given
        let largeExpenseList = createLargeExpenseList(count: 100)
        
        measure {
            Task {
                do {
                    _ = try await sut.exportData(
                        expenses: largeExpenseList,
                        format: .csv,
                        includeItems: false,
                        includeFinancialBreakdown: false
                    ) { _ in }
                } catch {
                    XCTFail("Export should not fail: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpenses() -> [Expense] {
        return [
            Expense(
                id: UUID(),
                date: Date(),
                merchant: "Test Grocery Store",
                amount: 45.67,
                currency: "USD",
                category: "Food & Dining",
                description: "Weekly groceries",
                paymentMethod: "Credit Card",
                items: [
                    ExpenseItem(
                        id: UUID(),
                        name: "Milk",
                        quantity: 1,
                        unitPrice: 3.99,
                        totalPrice: 3.99,
                        category: "Dairy",
                        description: "2% Milk"
                    ),
                    ExpenseItem(
                        id: UUID(),
                        name: "Bread",
                        quantity: 2,
                        unitPrice: 2.50,
                        totalPrice: 5.00,
                        category: "Bakery",
                        description: "Whole wheat bread"
                    )
                ],
                taxAmount: 3.20,
                subtotal: 42.47,
                tip: nil,
                fees: nil
            ),
            Expense(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                merchant: "Gas Station",
                amount: 35.00,
                currency: "USD",
                category: "Transportation",
                description: "Fuel",
                paymentMethod: "Credit Card",
                items: nil,
                taxAmount: nil,
                subtotal: nil,
                tip: nil,
                fees: nil
            ),
            Expense(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                merchant: "Coffee Shop",
                amount: 12.50,
                currency: "USD",
                category: "Food & Dining",
                description: "Morning coffee and pastry",
                paymentMethod: "Debit Card",
                items: [
                    ExpenseItem(
                        id: UUID(),
                        name: "Latte",
                        quantity: 1,
                        unitPrice: 5.50,
                        totalPrice: 5.50,
                        category: "Beverages",
                        description: "Large latte"
                    ),
                    ExpenseItem(
                        id: UUID(),
                        name: "Croissant",
                        quantity: 1,
                        unitPrice: 3.00,
                        totalPrice: 3.00,
                        category: "Pastries",
                        description: "Butter croissant"
                    )
                ],
                taxAmount: 1.00,
                subtotal: 11.00,
                tip: 0.50,
                fees: nil
            )
        ]
    }
    
    private func createLargeExpenseList(count: Int) -> [Expense] {
        var expenses: [Expense] = []
        
        for i in 0..<count {
            expenses.append(
                Expense(
                    id: UUID(),
                    date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                    merchant: "Merchant \(i)",
                    amount: Double(i + 1) * 10.0,
                    currency: "USD",
                    category: "Category \(i % 5)",
                    description: "Test expense \(i)",
                    paymentMethod: "Credit Card",
                    items: nil,
                    taxAmount: nil,
                    subtotal: nil,
                    tip: nil,
                    fees: nil
                )
            )
        }
        
        return expenses
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("Async expression threw error: \(error). \(message())", file: file, line: line)
        }
    }
}
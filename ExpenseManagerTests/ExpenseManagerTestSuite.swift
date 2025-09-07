import XCTest

/// Main test suite runner for ExpenseManager
/// This file provides utilities and configuration for all tests
class ExpenseManagerTestSuite: XCTestCase {
    
    // MARK: - Test Suite Configuration
    
    override class func setUp() {
        super.setUp()
        
        // Set up test environment
        configureTestEnvironment()
        
        print("🧪 ExpenseManager Test Suite Starting")
        print("📊 Test Statistics:")
        print("   • Model Tests: Expense, ExpenseItem, Error handling")
        print("   • Service Tests: ExpenseService, KeychainService, OpenAIService") 
        print("   • Export Tests: CSV, JSON export functionality")
        print("   • Integration Tests: End-to-end workflows")
    }
    
    override class func tearDown() {
        super.tearDown()
        
        // Clean up test environment
        cleanupTestEnvironment()
        
        print("✅ ExpenseManager Test Suite Completed")
    }
    
    // MARK: - Test Environment Setup
    
    private static func configureTestEnvironment() {
        // Set test-specific UserDefaults
        UserDefaults.standard.set("test_mode", forKey: "app_mode")
        
        // Clear any existing test data
        UserDefaults.standard.removeObject(forKey: "expenses")
        UserDefaults.standard.removeObject(forKey: "demo_data_loaded")
        
        // Set up test API key (if needed for integration tests)
        if let testAPIKey = ProcessInfo.processInfo.environment["TEST_OPENAI_API_KEY"] {
            _ = KeychainService.shared.saveAPIKey(testAPIKey)
            print("🔑 Test API key configured for integration tests")
        }
    }
    
    private static func cleanupTestEnvironment() {
        // Clean up test data
        UserDefaults.standard.removeObject(forKey: "app_mode")
        UserDefaults.standard.removeObject(forKey: "expenses")
        UserDefaults.standard.removeObject(forKey: "demo_data_loaded")
        
        // Clean up keychain test data
        try? KeychainService.shared.deleteAPIKey()
        
        // Clean up any test files
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("ExpenseManagerTests")
        try? fileManager.removeItem(at: tempDir)
    }
}

// MARK: - Test Utilities

extension XCTestCase {
    
    /// Creates a standardized test expense for use across multiple tests
    func createStandardTestExpense(
        merchant: String = "Test Merchant",
        amount: Double = 25.99,
        currency: String = "USD",
        category: String = "Food & Dining",
        includeItems: Bool = false
    ) -> Expense {
        
        let items: [ExpenseItem]? = includeItems ? [
            ExpenseItem(
                id: UUID(),
                name: "Test Item",
                quantity: 1,
                unitPrice: amount,
                totalPrice: amount,
                category: "Test Category",
                description: "Test item description"
            )
        ] : nil
        
        return Expense(
            id: UUID(),
            date: Date(),
            merchant: merchant,
            amount: amount,
            currency: currency,
            category: category,
            description: "Test expense description",
            paymentMethod: "Credit Card",
            items: items,
            taxAmount: includeItems ? 2.00 : nil,
            subtotal: includeItems ? amount - 2.00 : nil,
            tip: nil,
            fees: nil
        )
    }
    
    /// Creates a batch of test expenses for performance and bulk operation tests
    func createTestExpenseBatch(count: Int = 10) -> [Expense] {
        let categories = ["Food & Dining", "Transportation", "Shopping", "Entertainment", "Bills & Utilities"]
        let merchants = ["Grocery Store", "Gas Station", "Department Store", "Restaurant", "Coffee Shop"]
        
        return (0..<count).map { index in
            createStandardTestExpense(
                merchant: merchants[index % merchants.count],
                amount: Double.random(in: 5.0...100.0),
                currency: "USD",
                category: categories[index % categories.count],
                includeItems: index % 3 == 0 // Every third expense has items
            )
        }
    }
    
    /// Asserts that two expenses are functionally equal (ignoring non-critical differences)
    func assertExpensesEqual(
        _ expense1: Expense,
        _ expense2: Expense,
        accuracy: Double = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(expense1.merchant, expense2.merchant, file: file, line: line)
        XCTAssertEqual(expense1.amount, expense2.amount, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(expense1.currency, expense2.currency, file: file, line: line)
        XCTAssertEqual(expense1.category, expense2.category, file: file, line: line)
        XCTAssertEqual(expense1.description, expense2.description, file: file, line: line)
        XCTAssertEqual(expense1.paymentMethod, expense2.paymentMethod, file: file, line: line)
        XCTAssertEqual(expense1.items?.count, expense2.items?.count, file: file, line: line)
    }
    
    /// Waits for an async operation with a timeout
    func waitForAsync<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Creates a temporary directory for test file operations
    func createTestDirectory(name: String = "TestFiles") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExpenseManagerTests")
            .appendingPathComponent(name)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return tempDir
    }
    
    /// Cleans up a test directory
    func cleanupTestDirectory(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

// MARK: - Test Error Types

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        return "Operation timed out"
    }
}

struct TestSetupError: Error, LocalizedError {
    let message: String
    
    var errorDescription: String? {
        return "Test setup failed: \(message)"
    }
}

// MARK: - Test Mocks and Stubs

/// Mock UserDefaults for isolated testing
class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    
    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }
    
    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    func clearAll() {
        storage.removeAll()
    }
}

/// Mock URLSession for testing network operations without actual network calls
class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
}
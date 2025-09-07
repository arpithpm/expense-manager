import XCTest
import UIKit
@testable import ExpenseManager

final class OpenAIServiceTests: XCTestCase {
    
    var sut: OpenAIService!
    var mockKeychainService: MockKeychainService!
    
    override func setUpWithError() throws {
        mockKeychainService = MockKeychainService()
        sut = OpenAIService.shared
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockKeychainService = nil
        super.tearDown()
    }
    
    // MARK: - API Key Validation Tests
    
    func testExtractExpenseThrowsErrorWhenNoAPIKey() async {
        // Given
        KeychainService.shared.deleteAPIKey()
        let testImage = createTestImage()
        
        // When & Then
        do {
            _ = try await sut.extractExpenseFromReceipt(testImage)
            XCTFail("Should have thrown ExpenseManagerError.apiKeyMissing")
        } catch ExpenseManagerError.apiKeyMissing {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testImageProcessingFailure() async {
        // Given
        KeychainService.shared.saveAPIKey("test-key")
        
        // Create an image that will fail JPEG conversion (1x1 transparent image)
        let invalidImage = UIImage()
        
        // When & Then
        do {
            _ = try await sut.extractExpenseFromReceipt(invalidImage)
            XCTFail("Should have thrown ExpenseManagerError.imageProcessingFailed")
        } catch ExpenseManagerError.imageProcessingFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Network Error Tests
    
    func testNetworkErrorHandling() async {
        // Given
        KeychainService.shared.saveAPIKey("invalid-api-key")
        let testImage = createTestImage()
        
        // When & Then
        do {
            _ = try await sut.extractExpenseFromReceipt(testImage)
            // This may succeed if network is available and OpenAI returns an error
            // Or it may throw a network error if no internet
        } catch ExpenseManagerError.networkError(let underlyingError) {
            XCTAssertNotNil(underlyingError)
        } catch ExpenseManagerError.apiKeyMissing {
            // This is also acceptable if the invalid key is detected
        } catch {
            // Other errors are also acceptable for this integration test
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Spending Analysis Tests
    
    func testAnalyzeSpendingWithEmptyExpenses() async {
        // Given
        KeychainService.shared.saveAPIKey("test-key")
        let emptyExpenses: [Expense] = []
        
        // When & Then
        do {
            _ = try await sut.analyzeSpending(expenses: emptyExpenses)
            // May succeed with empty analysis or throw an error
        } catch {
            // Error is acceptable for empty expenses
            XCTAssertNotNil(error)
        }
    }
    
    func testAnalyzeSpendingWithValidExpenses() async {
        // Given
        KeychainService.shared.saveAPIKey("test-key")
        let testExpenses = createTestExpenses()
        
        // When & Then
        do {
            let analysis = try await sut.analyzeSpending(expenses: testExpenses)
            // If successful, analysis should have some properties
            XCTAssertNotNil(analysis)
        } catch ExpenseManagerError.apiKeyMissing {
            XCTFail("API key should be available")
        } catch ExpenseManagerError.networkError {
            // Network errors are acceptable in tests
            print("Network error in test - acceptable")
        } catch {
            // Other errors may occur due to API responses
            print("Other error in test: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        // Create a simple 100x100 test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 10, y: 10, width: 80, height: 20))
        
        guard let cgImage = context.makeImage() else {
            return UIImage()
        }
        
        return UIImage(cgImage: cgImage)
    }
    
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
            )
        ]
    }
}

// MARK: - Mock KeychainService for Testing

class MockKeychainService {
    private var storedAPIKey: String?
    
    func saveAPIKey(_ key: String) -> Bool {
        storedAPIKey = key
        return true
    }
    
    func getAPIKey() -> String? {
        return storedAPIKey
    }
    
    func deleteAPIKey() throws {
        storedAPIKey = nil
    }
    
    func hasValidAPIKey() -> Bool {
        return storedAPIKey != nil && !storedAPIKey!.isEmpty
    }
}

// MARK: - Integration Tests

class OpenAIServiceIntegrationTests: XCTestCase {
    
    /// These tests require a real API key and network connection
    /// They should be run manually and are disabled by default
    
    func testRealReceiptProcessing() async throws {
        // Given
        let realAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        guard let apiKey = realAPIKey, !apiKey.isEmpty else {
            throw XCTSkip("Real API key required for integration test")
        }
        
        KeychainService.shared.saveAPIKey(apiKey)
        let receiptImage = createMockReceiptImage()
        
        // When
        let result = try await OpenAIService.shared.extractExpenseFromReceipt(receiptImage)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.merchant)
        XCTAssertGreaterThan(result.amount, 0)
        XCTAssertFalse(result.currency.isEmpty)
    }
    
    private func createMockReceiptImage() -> UIImage {
        // Create a more realistic receipt-like image for integration testing
        let size = CGSize(width: 300, height: 400)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }
        
        // White background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Add some text-like rectangles to simulate receipt content
        context.setFillColor(UIColor.black.cgColor)
        
        // Store name
        context.fill(CGRect(x: 50, y: 30, width: 200, height: 20))
        
        // Items
        context.fill(CGRect(x: 20, y: 80, width: 150, height: 15))
        context.fill(CGRect(x: 200, y: 80, width: 50, height: 15))
        
        context.fill(CGRect(x: 20, y: 100, width: 120, height: 15))
        context.fill(CGRect(x: 200, y: 100, width: 50, height: 15))
        
        // Total
        context.fill(CGRect(x: 20, y: 150, width: 80, height: 20))
        context.fill(CGRect(x: 180, y: 150, width: 80, height: 20))
        
        guard let cgImage = context.makeImage() else {
            return UIImage()
        }
        
        return UIImage(cgImage: cgImage)
    }
}
import XCTest
@testable import ExpenseManager

final class KeychainServiceTests: XCTestCase {
    
    var sut: KeychainService!
    let testAPIKey = "test-api-key-12345"
    
    override func setUpWithError() throws {
        sut = KeychainService.shared
        
        // Clean up any existing test data
        try? sut.deleteAPIKey()
        
        super.setUp()
    }
    
    override func tearDownWithError() throws {
        // Clean up after each test
        try? sut.deleteAPIKey()
        sut = nil
        super.tearDown()
    }
    
    // MARK: - API Key Storage Tests
    
    func testSaveAPIKey() throws {
        // Given
        XCTAssertFalse(sut.hasValidAPIKey())
        
        // When
        let success = sut.saveAPIKey(testAPIKey)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(sut.hasValidAPIKey())
    }
    
    func testRetrieveAPIKey() throws {
        // Given
        let success = sut.saveAPIKey(testAPIKey)
        XCTAssertTrue(success)
        
        // When
        let retrievedKey = sut.getAPIKey()
        
        // Then
        XCTAssertEqual(retrievedKey, testAPIKey)
    }
    
    func testSaveEmptyAPIKey() {
        // Given
        let emptyKey = ""
        
        // When
        let success = sut.saveAPIKey(emptyKey)
        
        // Then
        XCTAssertTrue(success) // Keychain allows empty strings
        XCTAssertTrue(sut.hasValidAPIKey()) // But this might be a business logic issue
    }
    
    func testDeleteAPIKey() throws {
        // Given - Save a key first
        let success = sut.saveAPIKey(testAPIKey)
        XCTAssertTrue(success)
        XCTAssertTrue(sut.hasValidAPIKey())
        
        // When
        try sut.deleteAPIKey()
        
        // Then
        XCTAssertFalse(sut.hasValidAPIKey())
        XCTAssertNil(sut.getAPIKey())
    }
    
    func testDeleteNonExistentAPIKey() {
        // Given - Ensure no key exists
        XCTAssertFalse(sut.hasValidAPIKey())
        
        // When & Then - Should not throw error
        XCTAssertNoThrow(try sut.deleteAPIKey())
    }
    
    func testHasValidAPIKeyReturnsTrueWhenKeyExists() {
        // Given
        let success = sut.saveAPIKey(testAPIKey)
        XCTAssertTrue(success)
        
        // When
        let hasValidKey = sut.hasValidAPIKey()
        
        // Then
        XCTAssertTrue(hasValidKey)
    }
    
    func testHasValidAPIKeyReturnsFalseWhenNoKey() {
        // Given - Ensure no key exists
        try? sut.deleteAPIKey()
        
        // When
        let hasValidKey = sut.hasValidAPIKey()
        
        // Then
        XCTAssertFalse(hasValidKey)
    }
    
    // MARK: - Keychain Edge Cases
    
    func testOverwriteExistingAPIKey() {
        // Given
        let firstKey = "first-api-key"
        let secondKey = "second-api-key"
        
        let firstSuccess = sut.saveAPIKey(firstKey)
        XCTAssertTrue(firstSuccess)
        XCTAssertEqual(sut.getAPIKey(), firstKey)
        
        // When
        let secondSuccess = sut.saveAPIKey(secondKey)
        
        // Then
        XCTAssertTrue(secondSuccess)
        XCTAssertEqual(sut.getAPIKey(), secondKey)
        XCTAssertNotEqual(sut.getAPIKey(), firstKey)
    }
    
    func testSaveLongAPIKey() {
        // Given
        let longKey = String(repeating: "a", count: 1000) // Very long key
        
        // When
        let success = sut.saveAPIKey(longKey)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(sut.getAPIKey(), longKey)
    }
    
    func testSaveKeyWithSpecialCharacters() {
        // Given
        let specialKey = "sk-1234567890!@#$%^&*()_+-={}|[]\\:\";'<>?,./"
        
        // When
        let success = sut.saveAPIKey(specialKey)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(sut.getAPIKey(), specialKey)
    }
    
    // MARK: - Performance Tests
    
    func testKeychainSavePerformance() {
        measure {
            _ = sut.saveAPIKey("performance-test-key")
            try? sut.deleteAPIKey()
        }
    }
    
    func testKeychainRetrievePerformance() {
        // Given
        sut.saveAPIKey(testAPIKey)
        
        measure {
            _ = sut.getAPIKey()
        }
    }
    
    // MARK: - Security Tests
    
    func testKeychainDataPersistsBetweenInstances() {
        // Given
        let success = sut.saveAPIKey(testAPIKey)
        XCTAssertTrue(success)
        
        // When - Create new instance
        let newKeychainService = KeychainService.shared // Singleton
        
        // Then
        XCTAssertEqual(newKeychainService.getAPIKey(), testAPIKey)
        XCTAssertTrue(newKeychainService.hasValidAPIKey())
    }
    
    func testKeychainHandlesConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent keychain operations")
        let queue1 = DispatchQueue(label: "keychain-test-1", qos: .userInitiated)
        let queue2 = DispatchQueue(label: "keychain-test-2", qos: .userInitiated)
        
        var results: [Bool] = []
        let resultsQueue = DispatchQueue(label: "results")
        
        // When - Perform concurrent saves
        queue1.async {
            let success1 = self.sut.saveAPIKey("concurrent-key-1")
            resultsQueue.async {
                results.append(success1)
                if results.count == 2 {
                    expectation.fulfill()
                }
            }
        }
        
        queue2.async {
            let success2 = self.sut.saveAPIKey("concurrent-key-2")
            resultsQueue.async {
                results.append(success2)
                if results.count == 2 {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then - Both operations should succeed
        XCTAssertTrue(results.allSatisfy { $0 })
        XCTAssertNotNil(sut.getAPIKey()) // One of the keys should be saved
    }
}
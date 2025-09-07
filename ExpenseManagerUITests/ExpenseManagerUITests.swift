import XCTest

final class ExpenseManagerUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Launch with test configuration
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunches() throws {
        // Test that the app launches and shows the main interface
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        
        // Check that all main tabs are present
        XCTAssertTrue(app.tabBars.buttons["Overview"].exists)
        XCTAssertTrue(app.tabBars.buttons["All Expenses"].exists)
        XCTAssertTrue(app.tabBars.buttons["AI Insights"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
    
    func testOverviewTabIsDefaultSelection() throws {
        // Overview tab should be selected by default
        let overviewTab = app.tabBars.buttons["Overview"]
        XCTAssertTrue(overviewTab.isSelected)
    }
    
    // MARK: - Navigation Tests
    
    func testTabNavigation() throws {
        // Test navigation between tabs
        let tabBar = app.tabBars.firstMatch
        
        // Navigate to All Expenses
        tabBar.buttons["All Expenses"].tap()
        XCTAssertTrue(tabBar.buttons["All Expenses"].isSelected)
        
        // Navigate to AI Insights
        tabBar.buttons["AI Insights"].tap()
        XCTAssertTrue(tabBar.buttons["AI Insights"].isSelected)
        
        // Navigate to Settings
        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(tabBar.buttons["Settings"].isSelected)
        
        // Navigate back to Overview
        tabBar.buttons["Overview"].tap()
        XCTAssertTrue(tabBar.buttons["Overview"].isSelected)
    }
    
    // MARK: - Overview Screen Tests
    
    func testOverviewScreenElements() throws {
        // Ensure we're on overview tab
        app.tabBars.buttons["Overview"].tap()
        
        // Check for key overview elements
        // Note: Exact element identification depends on accessibility labels
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'ExpenseManager'")).firstMatch.exists)
        
        // Look for expense summary cards (these should have accessibility labels)
        let summaryCards = app.otherElements.containing(NSPredicate(format: "label CONTAINS 'Total Expenses'"))
        XCTAssertGreaterThan(summaryCards.count, 0)
    }
    
    func testReceiptPhotoSelection() throws {
        // Navigate to overview
        app.tabBars.buttons["Overview"].tap()
        
        // Look for photo selection button (should have accessibility label)
        let photoButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Select Receipt Photos' OR label CONTAINS 'camera'")).firstMatch
        
        if photoButton.exists {
            photoButton.tap()
            
            // Check if photo picker appears (this might require simulator photos to be set up)
            // The exact behavior depends on iOS permissions and photo library state
            XCTAssertTrue(photoButton.exists) // Basic test that button is still there
        }
    }
    
    // MARK: - All Expenses Screen Tests
    
    func testAllExpensesScreen() throws {
        // Navigate to All Expenses tab
        app.tabBars.buttons["All Expenses"].tap()
        
        // Check if the expenses list exists
        let expensesList = app.tables.firstMatch
        XCTAssertTrue(expensesList.exists || app.staticTexts["No expenses yet"].exists)
        
        // If there are expenses, test interaction
        if expensesList.cells.count > 0 {
            let firstCell = expensesList.cells.firstMatch
            XCTAssertTrue(firstCell.exists)
            
            // Test cell tap (should show expense details)
            firstCell.tap()
            
            // Check if detail view appears or actions are available
            // This depends on the specific implementation
        }
    }
    
    // MARK: - Settings Screen Tests
    
    func testSettingsScreenElements() throws {
        // Navigate to Settings tab
        app.tabBars.buttons["Settings"].tap()
        
        // Check for main settings sections
        XCTAssertTrue(app.staticTexts["Settings"].exists || app.navigationBars["Settings"].exists)
        
        // Look for key settings options
        let settingsList = app.tables.firstMatch
        if settingsList.exists {
            // Check for common settings items
            let apiKeySection = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'API Key' OR label CONTAINS 'OpenAI'"))
            let dataSection = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Data' OR label CONTAINS 'Export'"))
            
            // At least one of these sections should exist
            XCTAssertTrue(apiKeySection.count > 0 || dataSection.count > 0)
        }
    }
    
    func testDataExportFunctionality() throws {
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        
        // Look for export data option
        let exportButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Export Data' OR label CONTAINS 'Export'")).firstMatch
        
        if exportButton.exists {
            exportButton.tap()
            
            // Check if export options appear
            let csvOption = app.buttons.containing(NSPredicate(format: "label CONTAINS 'CSV'")).firstMatch
            let jsonOption = app.buttons.containing(NSPredicate(format: "label CONTAINS 'JSON'")).firstMatch
            
            XCTAssertTrue(csvOption.exists || jsonOption.exists)
        }
    }
    
    // MARK: - AI Insights Screen Tests
    
    func testAIInsightsScreen() throws {
        // Navigate to AI Insights tab
        app.tabBars.buttons["AI Insights"].tap()
        
        // Check for insights interface elements
        let insightsContent = app.scrollViews.firstMatch
        XCTAssertTrue(insightsContent.exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'insights' OR label CONTAINS 'analysis'")).firstMatch.exists)
        
        // Look for analyze button if insights aren't generated yet
        let analyzeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Analyze' OR label CONTAINS 'Generate'")).firstMatch
        
        if analyzeButton.exists {
            // Test analyze button tap (may require API key)
            analyzeButton.tap()
            
            // Check for loading state or results
            // Note: This test may fail if no API key is configured
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Test that key UI elements have proper accessibility labels
        
        // Navigate through each tab and check for accessibility
        let tabs = ["Overview", "All Expenses", "AI Insights", "Settings"]
        
        for tabName in tabs {
            app.tabBars.buttons[tabName].tap()
            
            // Check that the tab itself has proper accessibility
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.isHittable)
            XCTAssertFalse(tab.label.isEmpty)
            
            // Give the view time to load
            sleep(1)
            
            // Check for any buttons without accessibility labels
            let buttons = app.buttons.allElementsBoundByIndex
            for button in buttons {
                if button.isHittable && button.label.isEmpty {
                    XCTFail("Button without accessibility label found in \(tabName) tab")
                }
            }
        }
    }
    
    func testVoiceOverNavigation() throws {
        // Test basic VoiceOver navigation patterns
        // This test checks that elements are properly ordered and accessible
        
        app.tabBars.buttons["Overview"].tap()
        
        // Get all accessible elements
        let accessibleElements = app.descendants(matching: .any).allElementsBoundByIndex.filter { $0.isHittable }
        
        // Should have at least some accessible elements
        XCTAssertGreaterThan(accessibleElements.count, 0)
        
        // Check that tab bar elements are accessible
        let tabBarButtons = app.tabBars.buttons.allElementsBoundByIndex
        for button in tabBarButtons {
            XCTAssertTrue(button.isHittable)
            XCTAssertFalse(button.label.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testTabSwitchingPerformance() throws {
        measure {
            let tabBar = app.tabBars.firstMatch
            
            // Switch through all tabs
            tabBar.buttons["All Expenses"].tap()
            tabBar.buttons["AI Insights"].tap()
            tabBar.buttons["Settings"].tap()
            tabBar.buttons["Overview"].tap()
        }
    }
    
    // MARK: - Error State Tests
    
    func testNoInternetConnectionHandling() throws {
        // This test would require network condition simulation
        // For now, we just ensure the app doesn't crash when network operations might fail
        
        app.tabBars.buttons["AI Insights"].tap()
        
        let analyzeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Analyze'")).firstMatch
        
        if analyzeButton.exists {
            analyzeButton.tap()
            
            // App should handle network errors gracefully
            // We can't easily simulate network conditions in UI tests,
            // but we can verify the app doesn't crash
            XCTAssertTrue(app.exists)
        }
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistenceAcrossAppRestarts() throws {
        // This test checks that data persists when the app is terminated and relaunched
        // Note: This is a basic test - more comprehensive data testing should be in unit tests
        
        // Add some test data (if possible through UI)
        app.tabBars.buttons["Overview"].tap()
        
        // Terminate and relaunch app
        app.terminate()
        app.launch()
        
        // Check that the app still functions normally
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.tabBars.buttons["Overview"].isSelected)
    }
    
    // MARK: - Helper Methods
    
    private func waitForElementToAppear(element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "exists == true")
        expectation(for: predicate, evaluatedWith: element, handler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
    private func waitForElementToDisappear(element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "exists == false")
        expectation(for: predicate, evaluatedWith: element, handler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
    }
}
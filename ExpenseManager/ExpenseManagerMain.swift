// Main imports file for the refactored ExpenseManager app
// All services and models have been split into separate files in the Services/ and Models/ directories

// Import all service files
import Foundation
import SwiftUI
import Combine
import PhotosUI
import UIKit
import Security

// Models
// ExpenseModels.swift contains all data models, enums, and extensions

// Services
// KeychainService.swift - Secure storage for API keys
// ConfigurationManager.swift - App configuration management
// OpenAIService.swift - OpenAI API integration
// ExpenseService.swift - Core expense management and storage
// DataResetManager.swift - Data reset and cleanup functionality
// SpendingInsightsService.swift - AI-powered spending insights
// DataExporter.swift - Data export and import functionality

// Views
// SpendingInsightsViews.swift - AI insights UI components
// Additional views in Views/ directory: ConfigurationView, OverviewView, SettingsView, etc.

// App Architecture Notes:
// - Singleton pattern used for all services with .shared instances
// - ObservableObject protocol for reactive UI updates
// - UserDefaults for local data persistence (to be migrated to Core Data)
// - Keychain for secure API key storage
// - JSON-based import/export functionality
// - Modular service architecture for better maintainability

// This refactoring splits the monolithic ExpenseManagerComplete.swift (3254 lines)
// into focused, single-responsibility service files:
// - ExpenseModels.swift: Data structures and models
// - KeychainService.swift: Secure storage
// - ConfigurationManager.swift: Configuration management
// - OpenAIService.swift: AI integration
// - ExpenseService.swift: Core business logic
// - DataResetManager.swift: Data management
// - SpendingInsightsService.swift: AI insights
// - DataExporter.swift: Import/export functionality
// - SpendingInsightsViews.swift: UI components
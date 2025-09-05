# 🧾 ReceiptRadar - AI-Powered Expense Manager

**Transform your receipts into detailed financial insights with AI-powered item-level tracking.**

[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-green.svg)](https://developer.apple.com/xcode/swiftui/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o-purple.svg)](https://openai.com/)

## ✨ Features

### 🔍 **AI-Powered Receipt Processing**
- **Advanced OCR**: GPT-4o Vision API for accurate text extraction
- **Intelligent Parsing**: Extracts both basic expense data and detailed item information
- **Multi-format Support**: Handles various receipt formats and layouts
- **Error Recovery**: Graceful handling of unclear or damaged receipts

### 📊 **Item-Level Tracking**
- **Individual Items**: Captures name, quantity, unit price, and total for each item
- **Smart Categories**: Auto-categorizes items (Food, Beverage, Electronics, etc.)
- **Detailed Analysis**: Track spending patterns at the most granular level
- **Price Monitoring**: Monitor item price changes over time

### 💰 **Multi-Currency Support**
- **Global Ready**: Supports USD, EUR, GBP, and other major currencies
- **Automatic Detection**: Recognizes currency from receipts
- **Proper Formatting**: Displays correct currency symbols (€, $, £)
- **Mixed Currency**: Handle expenses in different currencies

### 📈 **Financial Breakdown**
- **Comprehensive Tracking**: Separates subtotal, taxes, tips, fees, discounts
- **Transparency**: Clear visibility into all charges
- **Validation**: Ensures financial breakdowns are accurate
- **Business Ready**: Detailed itemization for tax purposes

### 🎨 **Enhanced User Experience**
- **Expandable Views**: Tap expense rows to see detailed item breakdowns
- **Visual Indicators**: Item count badges and category tags
- **Advanced Search**: Search by item names, categories, descriptions
- **Privacy First**: All data stored locally on device

## 🚀 Quick Start

### Prerequisites
- iOS 16.0+ device or simulator
- Xcode 15.0+
- OpenAI API key with GPT-4o access

### Installation
1. **Clone the repository**
   ```bash
   git clone https://github.com/arpithpm/expense-manager.git
   cd expense-manager
   ```

2. **Open in Xcode**
   ```bash
   open ExpenseManager.xcodeproj
   ```

3. **Configure API Key**
   - Run the app
   - Go to Settings tab
   - Enter your OpenAI API key
   - Test the connection

4. **Start Scanning**
   - Tap "Select Receipt Photos" on Overview tab
   - Choose receipt images from your photo library
   - Watch as AI extracts detailed item information

## 📱 Screenshots

### Main Interface
- **Overview Dashboard**: Monthly totals and recent expenses
- **Receipt Scanner**: AI-powered photo processing
- **Detailed Views**: Expandable item-level breakdowns

### Item-Level Details
- **Individual Items**: See every item purchased with quantities and prices
- **Category Breakdown**: Items automatically categorized for analysis
- **Financial Summary**: Clear separation of charges, taxes, tips, fees

## 🛠 Technical Architecture

### Core Technologies
- **SwiftUI**: Modern, declarative UI framework
- **OpenAI GPT-4o**: Advanced vision model for receipt processing
- **UserDefaults**: Local data persistence
- **iOS Keychain**: Secure credential storage

### Data Flow
```
Receipt Photo → AI Processing → Item Extraction → Local Storage → Enhanced UI
     ↓              ↓               ↓               ↓            ↓
PhotosPicker → GPT-4o Vision → ExpenseItem[] → UserDefaults → Currency Format
Multi-select → Error Recovery → Categories → Backup Ready → Analytics
```

### Key Components
- **ConfigurationManager**: API credential management
- **ExpenseService**: Business logic and data management
- **OpenAIService**: AI processing with error recovery
- **Currency Extensions**: Multi-currency formatting
- **Enhanced UI**: Expandable item views

## 💾 Data Models

### Expense Structure
```swift
struct Expense {
    let merchant: String
    let amount: Double
    let currency: String
    let items: [ExpenseItem]?       // Individual items
    let subtotal: Double?           // Before taxes/tips
    let taxAmount: Double?          // Tax amount
    let tip: Double?               // Tip amount
    let fees: Double?              // Service fees
    // ... more fields
}
```

### Item Structure
```swift
struct ExpenseItem {
    let name: String               // Item name
    let quantity: Double?          // Number of items
    let unitPrice: Double?         // Price per unit
    let totalPrice: Double         // Total for this item
    let category: String?          // Item category
    let description: String?       // Additional details
}
```

## 🧠 AI Processing

### Enhanced Extraction
- **Comprehensive Prompts**: Detailed instructions for item extraction
- **Financial Validation**: Ensures extracted data adds up correctly
- **Error Recovery**: Handles truncated responses and parsing failures
- **Quality Assurance**: Confidence scoring for accuracy assessment

### Supported Data
- **Basic Info**: Date, merchant, amount, currency, category
- **Items**: Individual items with quantities and prices
- **Breakdown**: Subtotal, taxes, tips, fees, discounts
- **Metadata**: Payment method, confidence scores

## 🌍 Multi-Currency Features

### Automatic Currency Handling
- **Smart Detection**: AI recognizes currency from receipt text
- **Proper Display**: Uses iOS NumberFormatter for correct symbols
- **Mixed Support**: Handle multiple currencies in one app
- **Primary Logic**: Determines main currency for summaries

### Supported Currencies
- USD ($), EUR (€), GBP (£), CAD, AUD, JPY, and more
- Automatic symbol mapping and formatting
- Locale-aware display following iOS standards

## 📊 Analytics & Insights

### Item-Level Analysis
- **Top Items**: Most frequently purchased items
- **Category Spending**: Breakdown by item categories
- **Price Tracking**: Monitor price changes over time
- **Merchant Comparison**: Compare prices across stores

### Available Methods
```swift
getTopItems(limit: 10)              // Most purchased items
getSpendingByItemCategory()         // Category breakdown
getAverageItemPrice(for: "Coffee")  // Price tracking
getItemFrequency()                  // Purchase frequency
```

## 🔐 Privacy & Security

### Data Protection
- **Local Storage**: All data stays on your device
- **No Cloud Dependency**: No external servers required
- **Keychain Security**: API credentials stored securely
- **Photo Privacy**: Images processed but not stored

### User Control
- **Data Ownership**: Complete control over your financial data
- **Easy Export**: Data stored in standard JSON format
- **Reset Option**: Clear all data when needed
- **No Tracking**: No analytics or user tracking

## 🛠 Development

### Project Structure
```
ExpenseManager/
├── ExpenseManagerApp.swift         # App entry point
├── ExpenseManagerComplete.swift    # Core business logic
├── Views/
│   ├── OverviewView.swift         # Main dashboard
│   ├── ConfigurationView.swift    # Settings
│   └── SettingsView.swift         # App settings
└── Assets.xcassets/               # App icons and images
```

### Key Features Implementation
- **Item Tracking**: Comprehensive ExpenseItem model
- **Currency Support**: NumberFormatter-based formatting
- **Error Handling**: Robust recovery mechanisms
- **UI Enhancement**: Expandable views with detailed breakdowns

## 🤝 Contributing

### Getting Started
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Guidelines
- Follow Swift coding conventions
- Maintain comprehensive documentation
- Add tests for new features
- Ensure backwards compatibility

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **OpenAI** for the powerful GPT-4o Vision API
- **Apple** for SwiftUI and iOS development tools
- **Community** for feedback and feature suggestions

## 📞 Support

### Documentation
- [Complete Documentation](DOCUMENTATION.md) - Comprehensive technical guide
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Development overview
- [Enhanced Documentation](DOCUMENTATION_ENHANCED.md) - Feature-specific guide

### Issues
- Report bugs via GitHub Issues
- Feature requests welcome
- Check existing issues before creating new ones

### API Requirements
- OpenAI API key with GPT-4o vision access
- Sufficient API credits for image processing
- Stable internet connection for processing

---

**ReceiptRadar - Transforming receipt photos into detailed financial insights since 2025**

*Built with ❤️ using SwiftUI and AI*
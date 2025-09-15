# Receipt Radar 📱

**AI-Powered Expense Management Made Simple**

Receipt Radar is a sophisticated iOS expense management app that uses cutting-edge AI technology to automatically extract expense data from receipt photos, making expense tracking effortless and accurate.

![Version](https://img.shields.io/badge/version-2.1.1-blue.svg)
![iOS](https://img.shields.io/badge/iOS-15.0%2B-green.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

## ✨ Features

### 🤖 AI-Powered Receipt Processing
- **Smart OCR Technology**: Advanced AI extracts merchant names, amounts, dates, and itemized purchases from receipt photos
- **Multi-Currency Support**: Recognizes 50+ currencies including USD, EUR, GBP, INR, JPY, and more
- **Regional Format Recognition**: Handles different date formats (DD/MM/YYYY, MM/DD/YYYY, DD.MM.YYYY)
- **Multiple Receipt Support**: Process multiple receipts simultaneously
- **Auto-categorization**: Intelligent expense categorization based on merchant and purchase patterns

### 📊 Comprehensive Expense Management
- **Global Currency Support**: Track expenses in 50+ currencies with proper locale formatting
- **Real-time Tracking**: Monitor spending across multiple categories and currencies
- **Detailed Analytics**: Visual spending insights and monthly breakdowns
- **Export Capabilities**: Export data in CSV or JSON formats
- **Intelligent Tax Recognition**: Supports regional tax labels (GST, VAT, Sales Tax)

### 🎨 Modern User Experience
- **SwiftUI Interface**: Native iOS design with smooth animations
- **Dark Mode Support**: Adaptive interface for all lighting conditions
- **Accessibility**: Full VoiceOver and accessibility feature support
- **iPad Compatibility**: Optimized for both iPhone and iPad devices

### 🔒 Privacy & Security
- **Local Data Storage**: All expense data stored securely on your device
- **Input Validation**: Comprehensive data sanitization and security measures
- **No Data Collection**: Your financial information never leaves your device
- **Secure AI Processing**: Receipt processing through encrypted OpenAI API calls

## 🚀 Getting Started

### Prerequisites
- iOS 15.0 or later
- iPhone or iPad
- OpenAI API key (for AI-powered receipt processing)

### Installation
1. Clone this repository
2. Open `ExpenseManager.xcodeproj` in Xcode
3. Build and run on your iOS device or simulator

### Configuration
1. Launch the app
2. Navigate to Settings → Configuration
3. Enter your OpenAI API key
4. Test the connection to ensure proper setup

## 📱 How to Use

### Processing Receipts
1. **Capture**: Tap the camera icon to photograph your receipts
2. **Process**: The AI automatically extracts expense details
3. **Review**: Verify the extracted information and make any necessary edits
4. **Save**: Add the expense to your tracking system

### Managing Expenses
- **View All Expenses**: Browse your complete expense history
- **Search & Filter**: Find specific expenses by merchant, category, or date
- **Edit Details**: Modify any expense information as needed
- **Delete Expenses**: Remove unwanted or duplicate entries

### Analytics & Insights
- **Spending Overview**: Visual breakdown of expenses by category
- **Monthly Trends**: Track spending patterns over time
- **Export Data**: Generate reports in CSV or JSON format
- **Budget Tracking**: Monitor spending against your financial goals

## 🛠 Technical Architecture

### Core Technologies
- **SwiftUI**: Modern declarative UI framework
- **Core Data**: Local data persistence and management
- **PhotosUI**: Native photo selection and processing
- **OpenAI GPT-4**: Advanced AI for receipt text extraction
- **Combine**: Reactive programming for data flow management

### Key Components
- **CoreDataExpenseService**: Central expense management and persistence
- **OpenAIService**: AI-powered receipt processing
- **InputValidator**: Comprehensive input validation and sanitization
- **DataExporter**: Multi-format data export capabilities
- **ConfigurationManager**: Secure API key and settings management

### Data Security
- **Input Sanitization**: All user inputs validated and sanitized
- **Secure Storage**: Keychain integration for sensitive data
- **Privacy Controls**: Full user control over data sharing and exports
- **Encryption**: Secure API communications with OpenAI services

## 📋 System Requirements

- **iOS Version**: iOS 15.0 or later
- **Device**: iPhone 8 or newer, iPad (6th generation) or newer
- **Storage**: Minimum 50 MB available space
- **Network**: Internet connection required for AI processing
- **Camera**: Device camera for receipt photo capture

## 🔧 Configuration

### OpenAI Integration
Receipt Radar uses OpenAI's GPT-4 model for intelligent receipt processing. To configure:

1. Obtain an API key from [OpenAI](https://platform.openai.com/api-keys)
2. Open Receipt Radar → Settings → Configuration
3. Enter your API key and test the connection
4. Enjoy automated expense extraction!

### Privacy Settings
- All data processing happens locally on your device
- OpenAI API calls are encrypted and temporary
- No personal data is stored on external servers
- You maintain full control over your financial information

## 🌍 Multi-Currency Support

Receipt Radar now supports 50+ currencies worldwide, making it perfect for international travelers and global businesses:

### Supported Currencies
- **Americas**: USD, CAD, MXN, BRL, ARS, CLP, COP, PEN, UYU
- **Europe**: EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, HUF, RON, BGN, HRK, RSD
- **Asia-Pacific**: INR, JPY, CNY, SGD, HKD, AUD, NZD, MYR, THB, IDR, PHP, VND, KRW, TWD
- **Middle East & Africa**: AED, SAR, QAR, KWD, BHD, OMR, ILS, TRY, EGP, ZAR, NGN, KES, GHS
- **Others**: RUB, UAH, KZT, UZS

### Currency Features
- **Smart Recognition**: Automatically detects currency symbols (₹, €, £, ¥, $, etc.)
- **Locale Formatting**: Proper currency display based on regional standards
- **Regional Tax Support**: Recognizes GST (India), VAT (Europe), Sales Tax (US)
- **Date Format Intelligence**: Handles DD/MM/YYYY, MM/DD/YYYY, DD.MM.YYYY formats

## 📊 Export Formats

### CSV Export
- Compatible with Excel and Google Sheets
- Includes all expense details, categories, and currencies
- Perfect for accounting software integration

### JSON Export
- Structured data format for developers
- Complete metadata, categorization, and currency information
- Ideal for custom analysis and integration

## 🔄 Data Migration

Receipt Radar automatically handles data migration between versions:
- **Seamless Upgrades**: Automatic migration from UserDefaults to Core Data
- **Backup Preservation**: Your data is safely preserved during updates
- **Compatibility**: Forward and backward compatibility maintained

## 🤝 Contributing

We welcome contributions to Receipt Radar! Please feel free to submit pull requests, report issues, or suggest new features.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support, feature requests, or bug reports:
- **GitHub Issues**: [Create an issue](https://github.com/yourusername/receipt-radar/issues)
- **Email**: support@receiptradar.app
- **Documentation**: Check our [Wiki](https://github.com/yourusername/receipt-radar/wiki)

## 🙏 Acknowledgments

- OpenAI for providing the GPT-4 API for receipt processing
- Apple for the excellent SwiftUI and Core Data frameworks
- The iOS development community for inspiration and support

## 🗺 Roadmap

### Upcoming Features
- **Team Collaboration**: Shared expense management for businesses
- **Receipt Templates**: Custom receipt processing for specific merchants
- **Budget Alerts**: Smart notifications for spending limits
- **Siri Integration**: Voice-controlled expense entry
- **Currency Conversion**: Real-time exchange rates for multi-currency portfolios

---

**Receipt Radar** - Making expense management intelligent, secure, and effortless.

*Built with ❤️ for iOS*
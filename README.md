# Expense Manager iOS App

An intelligent expense tracking iOS application that uses AI-powered receipt scanning with OpenAI Vision API and Supabase for data storage.

## 📚 Documentation

For complete technical documentation, API details, and implementation guides, see: **[DOCUMENTATION.md](DOCUMENTATION.md)**

## Features

### ✅ Completed Features

- **Initial Setup & Configuration**
  - First-time setup screen for API credentials
  - Secure storage of Supabase URL/key and OpenAI API key using Keychain
  - Connection testing for both APIs
  - Settings screen for credential management

- **Receipt Processing**
  - Multiple photo selection with PhotosPicker
  - AI-powered expense extraction using OpenAI Vision API
  - Comprehensive prompt engineering for accurate data extraction
  - Support for various receipt types and formats

- **Data Management**
  - Supabase database integration
  - Complete CRUD operations for expenses
  - Expense categorization and payment method tracking
  - Monthly and total expense summaries

- **User Interface**
  - Modern SwiftUI design
  - Overview screen with expense summaries
  - Recent expenses display
  - Loading states and progress indicators
  - Comprehensive error handling and user feedback

## Architecture

### Key Components

1. **ConfigurationManager**: Handles API credential storage and validation
2. **ExpenseService**: Main service layer for expense operations
3. **OpenAIService**: Integration with OpenAI Vision API for receipt processing
4. **SupabaseService**: Database operations and API communication
5. **KeychainService**: Secure credential storage

### Data Flow

1. User selects receipt photos
2. Images processed through OpenAI Vision API
3. Extracted data validated and structured
4. Expense records stored in Supabase database
5. UI updated with new expenses

## Setup Instructions

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Supabase account and project
- OpenAI API account

### Database Setup

1. Create a new Supabase project
2. Run the SQL schema from `supabase_schema.sql` in your Supabase SQL editor
3. Enable Row Level Security and configure policies as needed

### App Configuration

1. Open the project in Xcode
2. Build and run the app
3. On first launch, enter your credentials:
   - **Supabase URL**: Your project URL (e.g., `https://xxx.supabase.co`)
   - **Supabase Anon Key**: Your public anon key
   - **OpenAI API Key**: Your OpenAI API key (requires vision model access)

4. Test connections to ensure everything is working

## OpenAI Prompt Design

The app uses a carefully crafted prompt for expense extraction that:

- **Extracts Required Fields**: Date, merchant, amount, currency, category
- **Handles Optional Fields**: Description, payment method, tax amount
- **Provides Category Classification**: Maps to predefined expense categories
- **Includes Confidence Scoring**: AI confidence in extraction accuracy
- **Follows Strict JSON Format**: Ensures consistent, parseable responses
- **Handles Edge Cases**: Missing information, unclear receipts, multiple formats

### Prompt Engineering Features

- Clear field definitions and extraction rules
- Comprehensive category mapping
- Conservative confidence scoring guidelines
- Robust error handling for unparseable receipts
- Support for multiple currencies and formats

## Database Schema

### Tables

- **expenses**: Main expense records
- **expense_categories**: Reference table for categories
- **payment_methods**: Reference table for payment methods

### Views

- **expense_summary**: Category-based expense summaries
- **monthly_expense_summary**: Monthly expense breakdowns

## Error Handling

The app includes comprehensive error handling for:

- Network connectivity issues
- API authentication failures  
- Invalid API responses
- Image processing errors
- Database operation failures

## Security

- **Keychain Storage**: All API credentials stored securely in iOS Keychain
- **Row Level Security**: Supabase RLS enabled (configure policies as needed)
- **API Key Validation**: Connection testing before storing credentials
- **No Credential Logging**: Sensitive data never logged or exposed

## Future Enhancements

Potential features to implement:

- [ ] Expense editing and deletion
- [ ] Advanced filtering and search
- [ ] Export functionality (CSV, PDF)
- [ ] Expense analytics and insights
- [ ] Budget tracking and alerts
- [ ] Receipt image storage
- [ ] Multi-currency support improvements
- [ ] Offline mode with sync

## Troubleshooting

### Common Issues

1. **Connection Test Failures**
   - Verify API credentials are correct
   - Check internet connectivity
   - Ensure Supabase project is active

2. **Receipt Processing Errors**
   - Verify OpenAI API key has Vision model access
   - Ensure images are clear and readable
   - Check API usage limits

3. **Database Errors**
   - Verify Supabase schema is properly set up
   - Check Row Level Security policies
   - Ensure API key has necessary permissions

## Dependencies

- SwiftUI (iOS 17.0+)
- PhotosUI for image selection
- Foundation for networking and data handling
- Security framework for Keychain operations

## API Integration

### OpenAI Vision API
- Model: `gpt-4o`
- Purpose: Receipt text and data extraction
- Response format: Structured JSON

### Supabase REST API
- Purpose: Database operations
- Authentication: Bearer token
- Features: CRUD operations, real-time updates

---

**Note**: This app is designed for personal expense tracking. Ensure you comply with your organization's policies if using for business expenses.
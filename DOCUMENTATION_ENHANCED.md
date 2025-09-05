# ReceiptRadar - AI-Powered Expense Manager with Item-Level Tracking

## Table of Contents
1. [Overview](#overview)
2. [Enhanced Features](#enhanced-features)
3. [Architecture](#architecture)
4. [Data Models](#data-models)
5. [AI Processing](#ai-processing)
6. [Item-Level Tracking](#item-level-tracking)
7. [API Integration](#api-integration)
8. [User Interface](#user-interface)
9. [Setup Instructions](#setup-instructions)

## Overview

The Expense Manager is an iOS application that uses AI-powered receipt scanning to automatically extract **comprehensive expense information with item-level tracking** and store it locally on the device. The app combines OpenAI's Vision API for detailed receipt processing with local UserDefaults storage, featuring advanced item-level tracking for detailed spending analysis.

### Core Capabilities
- **AI Receipt Processing**: Automatically extracts detailed expense data from receipt photos
- **Item-Level Tracking**: Captures individual items, quantities, prices, and categories
- **Financial Breakdown**: Tracks subtotals, taxes, tips, fees, and discounts separately
- **Smart Categorization**: Auto-categorizes both expenses and individual items
- **Local Storage**: Data stored securely on device using UserDefaults
- **Enhanced Analytics**: Deep insights into spending patterns at item level
- **Privacy-First**: No cloud storage of personal financial data
- **Expandable UI**: Collapsible item details for clean interface

## Enhanced Features

### Item-Level Tracking Features
- **Individual Item Extraction**: Names, quantities, prices for each item
- **Item Categories**: Separate categorization for each item (Food, Beverage, Electronics, etc.)
- **Quantity Tracking**: Number of items purchased with unit pricing
- **Item Descriptions**: Additional details like size, flavor, modifications
- **Financial Breakdown**: Separates subtotals, taxes, tips, fees, discounts

### Advanced Analytics Potential
- **Item-Level Spending**: Track spending on specific items over time
- **Category Insights**: Detailed breakdown by item categories
- **Price Tracking**: Monitor price changes for frequently purchased items
- **Merchant Analysis**: Compare item prices across different stores
- **Budget Optimization**: Identify specific items to reduce spending on

### User Experience Enhancements
- **Expandable Expense Rows**: Tap to see detailed item breakdown
- **Visual Item Indicators**: Shows item count in expense summary
- **Category Tags**: Visual indicators for item categories
- **Financial Summary**: Clear breakdown of charges, taxes, tips, and totals

## Architecture

### Enhanced Data Flow
```
Receipt Photo → AI Processing → Item Extraction → Local Storage → Analytics
     ↓              ↓               ↓               ↓            ↓
PhotosPicker → GPT-4o Vision → Items Array → UserDefaults → Insights
Asset ID     → JSON Response → ExpenseItem → Expense Model → UI Views
```

### Core Components
1. **ConfigurationManager**: OpenAI API credentials and connection testing
2. **ExpenseService**: Enhanced photo processing with item extraction
3. **OpenAIService**: Advanced receipt processing via Vision API
4. **Enhanced Models**: Expense + ExpenseItem structures
5. **Enhanced UI**: Expandable item views and financial breakdowns

## Data Models

### Enhanced Expense Model
```swift
struct Expense: Identifiable, Codable {
    let id: UUID
    let date: Date
    let merchant: String
    let amount: Double              // Final total paid
    let currency: String
    let category: String            // Overall expense category
    let description: String?
    let paymentMethod: String?
    let taxAmount: Double?
    let receiptImageUrl: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Enhanced item-level tracking
    let items: [ExpenseItem]?       // Array of individual items
    let subtotal: Double?           // Amount before taxes/tips/fees
    let discounts: Double?          // Any discounts applied
    let fees: Double?              // Service fees, delivery fees, etc.
    let tip: Double?               // Tip amount
    let itemsTotal: Double?        // Sum of all item prices
}
```

### New ExpenseItem Model
```swift
struct ExpenseItem: Identifiable, Codable {
    let id: UUID
    let name: String               // Item name/description
    let quantity: Double?          // Number of items (if specified)
    let unitPrice: Double?         // Price per unit (if calculable)
    let totalPrice: Double         // Total price for this item
    let category: String?          // Item-specific category
    let description: String?       // Additional details (size, flavor, etc.)
}
```

### Sample Data Structure
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "date": "2025-09-05T10:30:00Z",
  "merchant": "Starbucks Coffee",
  "amount": 9.85,
  "currency": "USD",
  "category": "Food & Dining",
  "description": "Morning coffee and pastry",
  "paymentMethod": "Credit Card",
  "taxAmount": 0.78,
  "items": [
    {
      "id": "item-1",
      "name": "Grande Latte",
      "quantity": 1,
      "unitPrice": 4.75,
      "totalPrice": 4.75,
      "category": "Beverage",
      "description": "Oat milk"
    },
    {
      "id": "item-2",
      "name": "Blueberry Muffin",
      "quantity": 1,
      "unitPrice": 2.95,
      "totalPrice": 2.95,
      "category": "Food",
      "description": "Warmed"
    }
  ],
  "subtotal": 7.70,
  "tip": 1.37,
  "itemsTotal": 7.70
}
```

## AI Processing

### Enhanced OpenAI Prompt
The AI prompt has been significantly enhanced to extract item-level details:

#### Required Fields (unchanged)
1. **Date**: Transaction date (YYYY-MM-DD format)
2. **Merchant**: Business/store name
3. **Amount**: Final total amount paid
4. **Currency**: Currency code (USD, EUR, etc.)
5. **Category**: Overall expense category

#### Enhanced Optional Fields
6. **Description**: Brief overall purchase description
7. **Payment Method**: Type of payment used
8. **Tax Amount**: Tax amount if visible
9. **Confidence**: AI confidence level (0.0-1.0)

#### New Item-Level Extraction
10. **Items Array**: Individual items with:
    - **name**: Item name/description
    - **quantity**: Number of items
    - **unitPrice**: Price per unit
    - **totalPrice**: Total price for item
    - **category**: Item-specific category
    - **description**: Additional details

#### New Financial Breakdown
11. **Subtotal**: Amount before taxes/tips/fees
12. **Discounts**: Discounts or coupons applied
13. **Fees**: Service fees, delivery fees, etc.
14. **Tip**: Tip amount if specified
15. **ItemsTotal**: Sum of all item prices

### AI Extraction Rules
- **Extract items only if clearly itemized on receipt**
- **For restaurants**: Extract dishes, drinks, appetizers separately
- **For grocery stores**: Extract products with quantities if visible
- **For retail**: Extract individual products purchased
- **Item categories should be specific** (Food, Beverage, Electronics, etc.)
- **Be conservative with item extraction** - only include clearly readable items
- **Financial breakdown must add up** to final total

### Example AI Response
```json
{
  "date": "2025-09-05",
  "merchant": "Chipotle Mexican Grill",
  "amount": 12.85,
  "currency": "USD",
  "category": "Food & Dining",
  "description": "Burrito bowl and drink",
  "paymentMethod": "Digital Payment",
  "taxAmount": 1.03,
  "confidence": 0.92,
  "items": [
    {
      "name": "Chicken Burrito Bowl",
      "quantity": 1,
      "unitPrice": 9.45,
      "totalPrice": 9.45,
      "category": "Food",
      "description": "Brown rice, black beans, mild salsa"
    },
    {
      "name": "Fountain Drink",
      "quantity": 1,
      "unitPrice": 2.75,
      "totalPrice": 2.75,
      "category": "Beverage",
      "description": "Large"
    }
  ],
  "subtotal": 12.20,
  "discounts": null,
  "fees": null,
  "tip": null,
  "itemsTotal": 12.20
}
```

## Item-Level Tracking

### Benefits for Users

#### Detailed Financial Insights
- **Item-Specific Spending**: "I spent $47 on coffee this month"
- **Category Analysis**: Breakdown by Food vs. Beverage vs. Service
- **Price Tracking**: Monitor item price changes over time
- **Merchant Comparison**: Compare prices across different stores

#### Practical Use Cases
- **Grocery Analysis**: Track healthy vs. unhealthy food purchases
- **Restaurant Insights**: See dining patterns and favorite dishes
- **Business Expenses**: Detailed itemization for tax deductions
- **Budget Optimization**: Identify specific high-cost items

### Data Processing Workflow

#### 1. Photo Selection
- User selects receipt photos via PhotosPicker
- Photos processed with asset identifiers tracked

#### 2. AI Processing
- Image compressed to JPEG (80% quality)
- Base64 encoded for API transmission
- Sent to GPT-4o with enhanced prompt

#### 3. Item Extraction
- AI extracts individual items from receipt
- Creates ExpenseItem objects for each item
- Validates financial breakdown adds up

#### 4. Data Storage
- Expense created with items array
- Stored locally via UserDefaults
- ProcessedPhoto tracking maintained

#### 5. UI Display
- Expense summary shows item count
- Expandable rows reveal item details
- Financial breakdown clearly displayed

### Item Categories
Items are automatically categorized into specific types:
- **Food**: Meals, snacks, groceries
- **Beverage**: Drinks, coffee, alcohol
- **Electronics**: Tech products, accessories
- **Household**: Cleaning supplies, home goods
- **Personal Care**: Health and beauty items
- **Clothing**: Apparel and accessories
- **Service**: Service charges, tips
- **Fuel**: Gasoline, charging
- **Other**: Miscellaneous items

## API Integration

### Enhanced OpenAI Request
```json
{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "[ENHANCED_PROMPT_WITH_ITEM_TRACKING]"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,[BASE64_IMAGE]"
          }
        }
      ]
    }
  ],
  "max_tokens": 800,  // Increased for item details
  "temperature": 0.1
}
```

### Processing Performance
- **Token Usage**: Increased due to item details (~300-800 tokens)
- **Processing Time**: Slightly longer due to detailed extraction
- **Accuracy**: Higher accuracy with detailed validation rules
- **Cost**: Moderate increase due to longer responses

## User Interface

### Enhanced Expense Row View
- **Summary View**: Shows merchant, total, category, item count
- **Expandable Details**: Tap to reveal item breakdown
- **Item List**: Individual items with quantities and prices
- **Financial Breakdown**: Subtotal, taxes, tips, fees clearly separated
- **Category Tags**: Visual indicators for item categories

### Item Display Features
- **Quantity Indicators**: Shows "2x" for multiple items
- **Unit Pricing**: Displays per-unit costs when applicable
- **Category Badges**: Color-coded item categories
- **Description Details**: Size, flavor, modifications shown
- **Price Hierarchy**: Unit price → total price clearly distinguished

### Visual Enhancements
- **Chevron Indicators**: Show expandable state
- **Color Coding**: Different colors for item categories
- **Dividers**: Clear separation between sections
- **Typography**: Hierarchical text sizing for clarity

## Setup Instructions

### Prerequisites
- iOS 16.0+
- Xcode 15.0+
- OpenAI API key with GPT-4o access
- Sufficient API credits for image processing

### Installation
1. Clone the repository
2. Open `ExpenseManager.xcodeproj` in Xcode
3. Build and run on device/simulator
4. Configure OpenAI API key in app settings
5. Test connection and start scanning receipts

### Configuration
- **API Key**: Enter OpenAI API key in settings
- **Test Connection**: Verify API access before use
- **Photo Permissions**: Grant access to photo library
- **Sample Data**: App includes sample expenses with items

### Usage Tips
- **Clear Receipts**: Use well-lit, clear receipt photos
- **Multiple Items**: Works best with itemized receipts
- **Review Extraction**: Check extracted items for accuracy
- **Edit if Needed**: Manual corrections can be added to data

---

**Enhanced with Item-Level Tracking - September 2025**

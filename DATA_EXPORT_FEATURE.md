# Data Export Feature - Complete User Guide

## 📤 **Overview**

The Data Export feature allows users to export their expense data in multiple formats for backup, analysis, or sharing purposes. The feature is accessible from the Settings screen and provides comprehensive options for customizing exports.

## 🎯 **Access Points**

### Settings → Data Management → Export Data
- **Location**: Settings tab → Data Management section → "Export Data" button
- **Visual Indicator**: Shows current expense count and available formats (CSV, JSON, PDF)
- **Requirements**: At least 1 expense in the database

## 📋 **Export Options**

### **1. Export Formats**
The feature supports three distinct export formats:

#### **📊 CSV (Comma-Separated Values)**
- **Purpose**: Spreadsheet-compatible format for data analysis
- **Best For**: Excel, Google Sheets, data analysis, accounting software
- **Features**: 
  - Clean tabular format with proper CSV escaping
  - Header row with column names
  - Optional item details in structured format
  - Financial breakdown fields when enabled

#### **🔧 JSON (JavaScript Object Notation)**
- **Purpose**: Structured data format for technical users and data import
- **Best For**: Developers, data migration, API integration, backup
- **Features**:
  - Complete data structure with metadata
  - Nested objects for complex data (items, financial breakdown)
  - Export metadata (date, version, totals)
  - Summary statistics included

#### **📄 PDF (Portable Document Format)**
- **Purpose**: Human-readable report format
- **Best For**: Printing, sharing with accountants, official records
- **Features**:
  - Professional report layout
  - Expense list with formatting
  - Item details (up to 3 per expense for space)
  - Multi-page support for large datasets

### **2. Date Range Filtering**
Users can filter exports by specific time periods:

- **All Time**: Export complete expense history
- **Last Month**: Expenses from the past 30 days
- **Last 3 Months**: Expenses from the past 90 days
- **Last Year**: Expenses from the past 365 days
- **Custom Range**: User-selected start and end dates

**Dynamic Filtering**: Expense counts update in real-time as date ranges change

### **3. Export Options**

#### **Include Item Details**
- **Default**: Enabled
- **Purpose**: Export individual items from receipts
- **Impact**: Adds item-level data including names, quantities, prices, categories
- **File Size**: Significantly increases export size for receipts with many items

#### **Include Financial Breakdown**
- **Default**: Enabled
- **Purpose**: Export detailed financial information
- **Includes**: Tax amounts, subtotals, tips, fees, discounts
- **Impact**: Provides complete financial picture for accounting purposes

## 🎨 **User Interface**

### **Export Screen Layout**
1. **Header Section**: Welcome message and feature overview
2. **Format Selection**: Visual cards for choosing export format
3. **Date Range**: Interactive selection with expense counts
4. **Export Options**: Toggle switches for additional data
5. **Preview Section**: Summary of export configuration
6. **Export Button**: Prominent call-to-action with progress indication

### **Visual Design Elements**
- **Format Cards**: Interactive cards with icons and descriptions
- **Progress Indicators**: Real-time export progress with percentages
- **Dynamic Previews**: Live updates of export configuration
- **Professional Styling**: Clean, modern interface with proper spacing

### **Interactive Features**
- **Real-time Updates**: Expense counts update as options change
- **File Size Estimation**: Approximate file size based on selections
- **Custom Date Picker**: Intuitive date range selection
- **Progress Overlay**: Full-screen progress indication during export

## ⚙️ **Technical Implementation**

### **DataExporter Class**
Handles the core export functionality with support for:
- **Asynchronous Processing**: Non-blocking export operations
- **Progress Callbacks**: Real-time progress updates
- **Error Handling**: Comprehensive error management
- **File Management**: Automatic file naming and storage

### **Export Process Flow**
1. **User Selection**: Format, date range, and options
2. **Data Filtering**: Filter expenses based on criteria
3. **Progress Initialization**: Setup progress tracking
4. **Format Processing**: Generate export in selected format
5. **File Creation**: Save to device storage
6. **Share Sheet**: Present sharing options to user

### **File Naming Convention**
```
ExpenseExport_[Date].[extension]
Examples:
- ExpenseExport_Sep 7, 2025.csv
- ExpenseExport_Sep 7, 2025.json
- ExpenseExport_Sep 7, 2025.pdf
```

### **Storage Location**
- **Primary**: App's Documents directory
- **Temporary**: Files created for sharing
- **Cleanup**: Automatic cleanup of temporary files

## 📱 **User Experience Flow**

### **Standard Export Flow**
1. **Access**: User taps "Export Data" from Settings
2. **Configuration**: User selects format, date range, and options
3. **Preview**: User reviews export configuration
4. **Export**: User taps export button
5. **Progress**: User sees real-time progress indication
6. **Share**: User presented with sharing options
7. **Action**: User saves to files or shares via email/messaging

### **Edge Cases Handled**
- **No Expenses**: Export button disabled with appropriate messaging
- **Large Exports**: Progress indication and memory-efficient processing
- **Network Issues**: Local processing, no network requirements
- **Storage Issues**: Error handling for insufficient storage
- **Format Errors**: Graceful fallback and error reporting

## 📊 **Export Content Details**

### **CSV Export Structure**
```csv
Date,Merchant,Amount,Currency,Category,Description,Payment Method,Tax Amount,Subtotal,Tip,Fees,Discount,Items Count,Items Detail
Sep 6, 2025,LIDL,45.67,EUR,Food & Dining,Groceries,Credit Card,3.45,42.22,0,0,0,12,"Milk: 1x@2.99; Bread: 2x@1.50; ..."
```

### **JSON Export Structure**
```json
{
  "exportDate": "2025-09-07T12:30:45Z",
  "version": "2.1.0",
  "totalExpenses": 150,
  "totalAmount": 2456.78,
  "includeItems": true,
  "includeFinancialBreakdown": true,
  "expenses": [
    {
      "id": "uuid-here",
      "date": "2025-09-06T19:22:16Z",
      "merchant": "LIDL",
      "amount": 45.67,
      "currency": "EUR",
      "category": "Food & Dining",
      "description": "Groceries",
      "paymentMethod": "Credit Card",
      "taxAmount": 3.45,
      "items": [
        {
          "name": "Milk",
          "quantity": 1,
          "unitPrice": 2.99,
          "totalPrice": 2.99,
          "category": "Food",
          "description": "Whole milk 1L"
        }
      ]
    }
  ],
  "summary": {
    "categoryTotals": {
      "Food & Dining": 1234.56,
      "Transportation": 567.89
    },
    "dateRange": {
      "start": 1694025600,
      "end": 1725561600
    }
  }
}
```

### **PDF Export Layout**
- **Title**: "Expense Report"
- **Metadata**: Generation date, total expenses, total amount
- **Table Format**: Date, Merchant, Amount, Category
- **Item Details**: Indented under each expense (limited to 3 items)
- **Multi-page**: Automatic page breaks for large datasets

## 🔧 **Advanced Features**

### **Progress Tracking**
- **Linear Progress**: Visual progress bar from 0-100%
- **Percentage Display**: Numerical progress indication
- **Status Messages**: Context-aware status text
- **Cancellation**: Export process can be interrupted

### **Memory Efficiency**
- **Streaming Processing**: Large exports processed in chunks
- **Memory Management**: Efficient handling of large datasets
- **Background Processing**: Non-blocking user interface
- **Resource Cleanup**: Automatic cleanup of temporary resources

### **Error Handling**
- **User-Friendly Messages**: Clear, actionable error descriptions
- **Retry Mechanisms**: Automatic retry for temporary failures
- **Fallback Options**: Alternative formats if primary export fails
- **Debug Information**: Detailed logging for troubleshooting

## 📈 **Performance Characteristics**

### **Export Speed**
- **Small Datasets** (< 100 expenses): < 1 second
- **Medium Datasets** (100-1000 expenses): 1-5 seconds  
- **Large Datasets** (1000+ expenses): 5-30 seconds
- **PDF Generation**: Slower due to formatting complexity

### **File Size Estimates**
- **CSV**: ~200 bytes per expense (base) + 100 bytes per item
- **JSON**: ~800 bytes per expense (base) + 100 bytes per item  
- **PDF**: ~2KB per expense (base) + 500 bytes per item

### **Memory Usage**
- **Efficient Processing**: Minimal memory overhead
- **Streaming**: Large exports don't load entirely into memory
- **Cleanup**: Automatic memory cleanup after export

## 🔒 **Privacy & Security**

### **Data Handling**
- **Local Processing**: All exports processed locally on device
- **No Cloud Transfer**: Export data never leaves the device
- **User Control**: Users choose sharing/saving destinations
- **Temporary Files**: Automatic cleanup of temporary export files

### **Permissions**
- **File System Access**: Required for saving exports
- **Share Sheet**: Standard iOS sharing capabilities
- **No Network**: No network permissions required for export

This comprehensive data export feature provides users with complete control over their expense data, supporting various use cases from simple backups to detailed financial analysis, all while maintaining the highest standards of privacy and user experience.
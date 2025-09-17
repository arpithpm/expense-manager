# Error Tracking and Debugging Guide

This comprehensive guide explains how to track, analyze, and resolve receipt processing failures in Receipt Radar.

## Overview

The app now includes sophisticated error tracking and logging systems that help you understand exactly what's happening when receipt processing fails, instead of just showing generic "check API credentials" messages.

## New Components

### 🔍 LoggingService
**Location**: `ExpenseManager/Services/LoggingService.swift`

Provides comprehensive logging with multiple levels:
- **Debug** 🔍: Detailed technical information
- **Info** ℹ️: General operational messages
- **Warning** ⚠️: Potential issues that don't cause failures
- **Error** ❌: Failures that affect functionality
- **Critical** 🚨: Severe errors requiring immediate attention

**Features**:
- Automatic log file management (keeps 7 days)
- System logger integration
- Context-aware logging with metadata
- Performance tracking
- Log export for troubleshooting

### 📊 ErrorTrackingService
**Location**: `ExpenseManager/Services/ErrorTrackingService.swift`

Tracks and analyzes errors to provide:
- **User-friendly error messages** with specific suggestions
- **Error categorization** (API key, network, OpenAI, etc.)
- **Statistics tracking** (consecutive failures, most common errors)
- **Health scoring** based on recent error patterns
- **Context-aware suggestions** based on error history

### 🛠️ DebugView
**Location**: `ExpenseManager/Views/DebugView.swift`

Provides a comprehensive debugging interface showing:
- System health status
- Error statistics and analysis
- Recent error summaries
- Log file management
- Export capabilities
- Development information

## How It Works

### 1. Error Detection and Logging

When a receipt processing error occurs:

```swift
// In OpenAIService.swift
let context = ReceiptProcessingContext(
    imageCount: 1,
    hasAPIKey: KeychainService.shared.hasValidAPIKey(),
    attemptNumber: 1
)

// Track the error with full context
errorTracker.trackError(error, context: context)

// Log detailed information
logger.error("Receipt processing failed",
             category: .openai,
             context: ["statusCode": 401, "responseBody": "..."],
             error: error)
```

### 2. Error Analysis

The system automatically categorizes errors:

- **API_KEY**: Missing, invalid, or expired OpenAI API keys
- **NETWORK**: Connection issues, timeouts, DNS problems
- **OPENAI**: OpenAI API errors (rate limits, server issues)
- **IMAGE_PROCESSING**: Image format, size, or quality issues
- **DATA_STORAGE**: Local storage or keychain access problems

### 3. User-Friendly Messages

Instead of generic errors, users see specific guidance:

**Before**: "Failed to process receipts. Please check your API credentials and try again."

**After**:
```
Configuration Issue
Authentication failed. Please check your API key.

Suggestions:
• Update your OpenAI API key in Settings
• Verify your API key is active and has credits
```

## Using the System

### For Users

Users will now see much more helpful error messages when processing fails. The messages include:

1. **Clear problem identification** - What specifically went wrong
2. **Actionable suggestions** - Specific steps to resolve the issue
3. **Context awareness** - Different suggestions based on error history

### For Developers/Support

#### Accessing Debug Information

1. **Add DebugView to your app** (for development builds):
   ```swift
   // In your main tab view or settings
   NavigationLink("Debug & Diagnostics", destination: DebugView())
   ```

2. **Review system health**:
   - Health score (0-100%)
   - API key status
   - Recent error patterns

3. **Analyze error statistics**:
   - Total errors by category
   - Consecutive failure count
   - Most common error types
   - Timeline of recent issues

#### Exporting Logs for Analysis

The debug view provides an "Export Logs" button that creates a comprehensive support file including:

- Recent logs (last 24 hours)
- App version and device information
- Error statistics and patterns
- System configuration details

### Common Error Scenarios and Solutions

#### 1. API Key Issues
**Symptoms**: "Configuration Issue" messages, authentication failures

**What to check**:
```swift
// In DebugView or manual checking
let hasKey = KeychainService.shared.hasValidAPIKey()
let stats = ErrorTrackingService.shared.getErrorStatistics()
print("API Key configured: \(hasKey)")
print("API key errors: \(stats.apiKeyErrors)")
```

**Solutions**:
- Verify API key is correctly entered
- Check OpenAI account has sufficient credits
- Ensure API key has proper permissions

#### 2. Network Problems
**Symptoms**: "Connection Problem" messages, timeouts

**What to check**:
- Error stats show high network error count
- Recent error analysis shows NETWORK category

**Solutions**:
- Check internet connectivity
- Try different network (WiFi vs cellular)
- Verify no corporate firewall blocking OpenAI

#### 3. OpenAI API Issues
**Symptoms**: Rate limit messages, server error responses

**What to check**:
```swift
let errorSummary = LoggingService.shared.getErrorSummary(hours: 24)
print("OpenAI errors: \(errorSummary["OPENAI"] ?? 0)")
```

**Solutions**:
- Wait for rate limits to reset
- Upgrade OpenAI plan for higher limits
- Check OpenAI status page

#### 4. Image Processing Problems
**Symptoms**: "Image couldn't be processed" messages

**What to check**:
- Error logs show IMAGE_PROCESSING category
- Large file sizes in log context

**Solutions**:
- Use clearer, better-lit photos
- Ensure receipt text is readable
- Try smaller image files

## Log File Analysis

### Finding Log Files

Log files are stored in the app's Documents/Logs directory:
- Format: `receiptradar-YYYY-MM-DD.log`
- Retention: 7 days
- Size: Automatically managed

### Log Entry Format

```
❌ ERROR [OPENAI] 2025-01-15T10:30:45Z - Receipt processing failed | Context: {"statusCode":"401","responseBody":"Invalid API key","timestamp":"1705316445"}
```

- **Level**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Category**: API_KEY, NETWORK, OPENAI, etc.
- **Timestamp**: ISO 8601 format
- **Message**: Human-readable description
- **Context**: Structured metadata for analysis

### Analyzing Patterns

Look for:
1. **Repeated error categories** - Indicates systematic issues
2. **Time-based patterns** - Network issues during specific hours
3. **Consecutive failures** - May indicate configuration problems
4. **Response codes** - Specific OpenAI API issues

## Integration with External Services

For production apps, you can integrate with crash reporting services:

```swift
// In LoggingService.handleCriticalError()
private func handleCriticalError(_ message: String, category: ErrorCategory, context: [String: Any]?) {
    // Send to Crashlytics, Sentry, or other service
    Crashlytics.crashlytics().log("Critical error: \(message)")
    Crashlytics.crashlytics().setCustomValue(category.rawValue, forKey: "errorCategory")

    // Include context data
    context?.forEach { key, value in
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
```

## Performance Impact

The logging system is designed to be lightweight:
- **Minimal overhead**: Async logging, efficient file I/O
- **Smart retention**: Automatic cleanup of old logs
- **Debug-only features**: Console logging disabled in release builds
- **Batched operations**: File writes are optimized

## Best Practices

### For Development
1. **Monitor health scores** regularly in debug builds
2. **Review error patterns** during testing
3. **Export logs** when investigating user reports
4. **Test error scenarios** systematically

### For Production
1. **Include DebugView** in development/beta builds only
2. **Monitor error statistics** through analytics
3. **Set up alerts** for critical error thresholds
4. **Regularly review** user-facing error messages

## Troubleshooting Checklist

When a user reports processing failures:

1. **Check recent error category** in debug view
2. **Review error statistics** for patterns
3. **Export logs** for detailed analysis
4. **Verify system health** score and API key status
5. **Test with known good receipt** to isolate issue

## Future Enhancements

Planned improvements to the error tracking system:

- **Remote logging** - Send anonymized error data to analytics
- **Predictive analysis** - Warn users before likely failures
- **Automated suggestions** - Dynamic help based on error patterns
- **Integration with support** - Automated ticket creation with context
- **Machine learning** - Pattern recognition for complex issues

This comprehensive error tracking system transforms debugging from guesswork into data-driven problem solving, significantly improving the user experience and reducing support burden.
# OpenAI API Cost Information

This document contains information about OpenAI model costs for receipt processing in the ExpenseManager app.

## 📊 **OpenAI Pricing Analysis (2025)**

### **Standard Tier Pricing (Per 1M Tokens)**

| Model | Input Cost | Output Cost | Best For | Context Window |
|-------|------------|-------------|----------|----------------|
| **GPT-4o** | $2.50 | $10.00 | Multimodal tasks | 128K tokens |
| **GPT-4o mini** | $0.15 | $0.60 | Multimodal on budget | 128K tokens |
| **GPT-4.1** | $2.00 | $8.00 | Complex tasks | 1M+ tokens |
| **GPT-4.1 mini** | $0.40 | $1.60 | Balanced performance | 1M+ tokens |
| **GPT-4.1 nano** | $0.10 | $0.40 | Speed & price optimization | 1M+ tokens |

## 💡 **Current Implementation**

The app uses **GPT-4o mini** for optimal balance of cost and accuracy:
- **Per Receipt Cost**: ~$0.0003 (extremely low)
- **Quality**: Excellent for receipt text and image processing  
- **Speed**: Fast processing with 128K context window

## 🔧 **User Requirements**

Users need to provide their own OpenAI API key:
- Keys are stored securely in device Keychain
- Direct billing relationship with OpenAI
- No usage limits imposed by the app
- Full control over API costs

## 📋 **Estimated Usage**

Typical receipt processing:
- **Input tokens**: ~1,000 tokens (image + prompt)

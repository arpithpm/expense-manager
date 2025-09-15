import Foundation
import UIKit

class OpenAIService {
    static let shared = OpenAIService()
    private init() {}
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func extractExpenseFromReceipt(_ image: UIImage) async throws -> OpenAIExpenseExtraction {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ExpenseManagerError.imageProcessingFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        let prompt = createExpenseExtractionPrompt()
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]],
            "max_tokens": 1000,  // Increased from 500 to handle item-level details
            "temperature": 0.1
        ]
        
        // Use the keychain stored API key
        guard let apiKey = KeychainService.shared.retrieve(for: .openaiKey) else {
            throw ExpenseManagerError.apiKeyMissing
        }
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.requestEncodingFailed
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ExpenseManagerError.networkError(underlying: error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw OpenAIError.invalidAPIKey
        } else if httpResponse.statusCode != 200 {
            // Log the response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("OpenAI API Error (\(httpResponse.statusCode)): \(responseString)")
            }
            throw OpenAIError.apiError(httpResponse.statusCode)
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = openAIResponse.choices.first?.message.content else {
                throw OpenAIError.noResponseContent
            }
            
            // Check if the response was truncated due to token limit
            if let finishReason = openAIResponse.choices.first?.finishReason, finishReason == "length" {
                print("Warning: OpenAI response was truncated due to token limit")
                // Continue processing but with awareness that it might be incomplete
            }
            
            print("OpenAI Response Content: \(content)")
            return try parseExpenseExtraction(from: content)
        } catch {
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw OpenAI Response: \(responseString)")
            }
            if error is OpenAIError { throw error }
            print("JSON Parsing Error: \(error)")
            throw OpenAIError.responseParsingFailed
        }
    }
    
    private func createExpenseExtractionPrompt() -> String {
        return """
        Extract detailed expense information from this receipt image. Return ONLY valid JSON (no markdown, no text).

        REQUIRED: date (YYYY-MM-DD), merchant, amount (final total), currency, category from: Food & Dining, Transportation, Shopping, Entertainment, Bills & Utilities, Healthcare, Travel, Education, Business, Other

        OPTIONAL: description, paymentMethod, taxAmount, confidence (0.0-1.0)

        ITEMS (if clearly visible): Extract individual items with: name, quantity, unitPrice, totalPrice, category (Food/Beverage/Product/Service/etc), description

        FINANCIAL: subtotal, discounts, fees, tip, itemsTotal

        CURRENCY RECOGNITION:
        - USD: $, Dollar, United States Dollar
        - EUR: €, Euro, European Euro
        - GBP: £, Pound, British Pound Sterling
        - INR: ₹, Rs, Rupee, Indian Rupee
        - JPY: ¥, Yen, Japanese Yen
        - CNY: ¥, Yuan, Chinese Yuan, RMB
        - CAD: C$, Canadian Dollar
        - AUD: A$, Australian Dollar
        - CHF: CHF, Swiss Franc
        - SEK: kr, Swedish Krona
        - NOK: kr, Norwegian Krone
        - DKK: kr, Danish Krone
        - PLN: zł, Polish Złoty
        - CZK: Kč, Czech Koruna
        - HUF: Ft, Hungarian Forint
        - RON: lei, Romanian Leu
        - BGN: лв, Bulgarian Lev
        - HRK: kn, Croatian Kuna
        - RSD: дин, Serbian Dinar
        - TRY: ₺, Turkish Lira
        - ILS: ₪, Israeli Shekel
        - AED: د.إ, UAE Dirham
        - SAR: ر.س, Saudi Riyal
        - QAR: ر.ق, Qatari Riyal
        - KWD: د.ك, Kuwaiti Dinar
        - BHD: .د.ب, Bahraini Dinar
        - OMR: ر.ع, Omani Rial
        - EGP: ج.م, Egyptian Pound
        - ZAR: R, South African Rand
        - NGN: ₦, Nigerian Naira
        - KES: KSh, Kenyan Shilling
        - GHS: ₵, Ghanaian Cedi
        - MXN: MX$, Mexican Peso
        - BRL: R$, Brazilian Real
        - ARS: AR$, Argentine Peso
        - CLP: CLP$, Chilean Peso
        - COP: COL$, Colombian Peso
        - PEN: S/, Peruvian Sol
        - UYU: $U, Uruguayan Peso
        - SGD: S$, Singapore Dollar
        - MYR: RM, Malaysian Ringgit
        - THB: ฿, Thai Baht
        - IDR: Rp, Indonesian Rupiah
        - PHP: ₱, Philippine Peso
        - VND: ₫, Vietnamese Dong
        - KRW: ₩, South Korean Won
        - TWD: NT$, Taiwan Dollar
        - HKD: HK$, Hong Kong Dollar
        - NZD: NZ$, New Zealand Dollar
        - RUB: ₽, Russian Ruble
        - UAH: ₴, Ukrainian Hryvnia
        - KZT: ₸, Kazakhstani Tenge
        - UZS: soʻm, Uzbekistani Som
        - Default to USD if currency cannot be determined

        DATE FORMAT HANDLING:
        - CRITICAL: For German date format DD.MM.YY, interpret YY as 20YY (e.g., "25" means "2025")
        - CRITICAL: For Indian date format DD/MM/YY or DD-MM-YY, interpret YY as 20YY
        - CRITICAL: For US date format MM/DD/YY, interpret YY as 20YY
        - CRITICAL: For European date format DD.MM.YYYY or DD/MM/YYYY, use as-is
        - Always prioritize full ISO timestamps when available (e.g., "2025-09-06T19:22:16.000Z")
        - If both short format and full timestamp are present, use the full timestamp
        - Common Indian formats: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY

        REGIONAL CONSIDERATIONS:
        - Indian receipts: Look for GST, CGST, SGST, IGST tax labels
        - European receipts: Look for VAT, MwSt, TVA tax labels
        - US receipts: Look for Sales Tax, State Tax labels
        - UK receipts: Look for VAT tax labels
        - Common Indian merchants: Reliance, Big Bazaar, Spencer's, More, etc.
        - Decimal separators: Use . for amount (convert , to . if needed)

        RULES:
        - Extract items ONLY if clearly itemized
        - Use final total for "amount"
        - Item categories: Food, Beverage, Product, Service, Electronics, Household, etc.
        - If unclear, set items to null
        - Ensure financial breakdown adds up
        - Always extract currency symbol/code and convert to standard 3-letter code
        - For amounts with comma as decimal separator (European style), convert to dot format

        JSON FORMAT:
        {
            "date": "YYYY-MM-DD",
            "merchant": "Store Name",
            "amount": 99.99,
            "currency": "USD",
            "category": "Shopping",
            "description": "Brief description",
            "paymentMethod": "Credit Card",
            "taxAmount": 8.25,
            "confidence": 0.85,
            "items": [
                {
                    "name": "Item Name",
                    "quantity": 1,
                    "unitPrice": 10.00,
                    "totalPrice": 10.00,
                    "category": "Product",
                    "description": "Additional details"
                }
            ],
            "subtotal": 91.74,
            "discounts": null,
            "fees": null,
            "tip": null,
            "itemsTotal": 91.74
        }

        For unclear receipts, set items/breakdown to null and extract basic expense info only.
        """
    }
    
    private func parseExpenseExtraction(from content: String) throws -> OpenAIExpenseExtraction {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        var cleanedContent = trimmedContent
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Cleaned content for parsing: \(cleanedContent)")
        
        // Check if the JSON might be truncated (common issue with token limits)
        if !cleanedContent.hasSuffix("}") {
            print("Warning: JSON appears to be truncated. Attempting to fix...")
            
            // Try to fix common truncation issues
            var fixedContent = cleanedContent
            
            // If it ends with a quote and comma, likely truncated in the middle of an item
            if fixedContent.hasSuffix("\",") || fixedContent.hasSuffix("\"") {
                // Find the last complete item and close the array properly
                if let lastCompleteItemIndex = fixedContent.lastIndex(of: "}") {
                    let truncationPoint = fixedContent.index(after: lastCompleteItemIndex)
                    fixedContent = String(fixedContent[..<truncationPoint])
                    
                    // Close the items array and main object
                    if fixedContent.contains("\"items\": [") && !fixedContent.contains("]") {
                        fixedContent += "\n    ],\n    \"subtotal\": null,\n    \"discounts\": null,\n    \"fees\": null,\n    \"tip\": null,\n    \"itemsTotal\": null\n}"
                    } else {
                        fixedContent += "\n}"
                    }
                    
                    print("Attempted to fix truncated JSON: \(fixedContent)")
                }
            }
            
            cleanedContent = fixedContent
        }
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            print("Failed to convert to data")
            throw OpenAIError.responseParsingFailed
        }
        
        do {
            let decoder = JSONDecoder()
            // Handle potential null values gracefully
            return try decoder.decode(OpenAIExpenseExtraction.self, from: jsonData)
        } catch {
            print("JSON Decoding Error: \(error)")
            
            // If we still have parsing issues, try to extract basic expense info without items
            if let basicExpense = tryParseBasicExpense(from: cleanedContent) {
                print("Falling back to basic expense extraction without items")
                return basicExpense
            }
            
            throw OpenAIError.responseParsingFailed
        }
    }
    
    // Fallback method to extract basic expense info if item parsing fails
    private func tryParseBasicExpense(from content: String) -> OpenAIExpenseExtraction? {
        // Try to extract just the basic fields without items using regex or simple parsing
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Extract required fields
        guard let date = json["date"] as? String,
              let merchant = json["merchant"] as? String,
              let amount = json["amount"] as? Double,
              let currency = json["currency"] as? String,
              let category = json["category"] as? String else {
            return nil
        }
        
        // Create basic expense without items
        return OpenAIExpenseExtraction(
            date: date,
            merchant: merchant,
            amount: amount,
            currency: currency,
            category: category,
            description: json["description"] as? String,
            paymentMethod: json["paymentMethod"] as? String,
            taxAmount: json["taxAmount"] as? Double,
            confidence: json["confidence"] as? Double ?? 0.7,
            items: nil, // No items due to parsing failure
            subtotal: json["subtotal"] as? Double,
            discounts: json["discounts"] as? Double,
            fees: json["fees"] as? Double,
            tip: json["tip"] as? Double,
            itemsTotal: json["itemsTotal"] as? Double
        )
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey, invalidURL, requestEncodingFailed, invalidResponse
    case invalidAPIKey, apiError(Int), noResponseContent, responseParsingFailed, imageProcessingFailed
    case responseTruncated
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI API key not found"
        case .invalidURL: return "Invalid OpenAI API URL"
        case .requestEncodingFailed: return "Failed to encode request"
        case .invalidResponse: return "Invalid response from OpenAI"
        case .invalidAPIKey: return "Invalid OpenAI API key"
        case .apiError(let code): return "OpenAI API error (Status: \(code))"
        case .noResponseContent: return "No content in OpenAI response"
        case .responseParsingFailed: return "Failed to parse OpenAI response"
        case .imageProcessingFailed: return "Failed to process image"
        case .responseTruncated: return "Response was truncated - try with a simpler receipt"
        }
    }
}
import Foundation

class CurrencyIntelligenceService {
    static let shared = CurrencyIntelligenceService()
    
    private init() {}
    
    // MARK: - Merchant to Currency Mappings
    
    private let merchantCurrencyMappings: [String: String] = [
        // UK Merchants
        "tesco": "GBP",
        "asda": "GBP",
        "sainsbury": "GBP",
        "sainsburys": "GBP",
        "morrisons": "GBP",
        "waitrose": "GBP",
        "marks & spencer": "GBP",
        "m&s": "GBP",
        "boots": "GBP",
        "argos": "GBP",
        "currys": "GBP",
        "john lewis": "GBP",
        "next": "GBP",
        "primark": "GBP",
        "costa coffee": "GBP",
        "greggs": "GBP",
        "pret a manger": "GBP",
        "nandos": "GBP",
        "subway uk": "GBP",
        
        // German Merchants
        "rewe": "EUR",
        "edeka": "EUR",
        "aldi": "EUR",
        "lidl": "EUR",
        "kaufland": "EUR",
        "real": "EUR",
        "dm": "EUR",
        "rossmann": "EUR",
        "media markt": "EUR",
        "saturn": "EUR",
        "otto": "EUR",
        "zalando": "EUR",
        "h&m": "EUR",
        "c&a": "EUR",
        "douglas": "EUR",
        
        // US Merchants
        "walmart": "USD",
        "target": "USD",
        "amazon": "USD",
        "costco": "USD",
        "sams club": "USD",
        "kroger": "USD",
        "safeway": "USD",
        "cvs": "USD",
        "walgreens": "USD",
        "home depot": "USD",
        "lowes": "USD",
        "best buy": "USD",
        "macys": "USD",
        "starbucks": "USD",
        "mcdonalds": "USD",
        "burger king": "USD",
        "subway": "USD",
        "chipotle": "USD",
        "shell": "USD",
        "exxon": "USD",
        "chevron": "USD",
        
        // Indian Merchants
        "reliance": "INR",
        "big bazaar": "INR",
        "spencers": "INR",
        "more": "INR",
        "dmart": "INR",
        "flipkart": "INR",
        "amazon india": "INR",
        "swiggy": "INR",
        "zomato": "INR",
        "ola": "INR",
        "uber india": "INR",
        "paytm": "INR",
        "jio": "INR",
        "airtel": "INR",
        "bsnl": "INR",
        
        // Canadian Merchants
        "loblaws": "CAD",
        "metro": "CAD",
        "sobeys": "CAD",
        "shoppers drug mart": "CAD",
        "canadian tire": "CAD",
        "tim hortons": "CAD",
        "tim horton": "CAD",
        "a&w canada": "CAD",
        "harvey": "CAD",
        
        // Australian Merchants
        "woolworths": "AUD",
        "coles": "AUD",
        "iga": "AUD",
        "bunnings": "AUD",
        "jb hi-fi": "AUD",
        "big w": "AUD",
        "kmart australia": "AUD",
        "myer": "AUD",
        "david jones": "AUD",
        
        // French Merchants
        "carrefour": "EUR",
        "leclerc": "EUR",
        "auchan": "EUR",
        "intermarche": "EUR",
        "monoprix": "EUR",
        "franprix": "EUR",
        "casino": "EUR",
        
        // Spanish Merchants
        "mercadona": "EUR",
        "corte ingles": "EUR",
        "carrefour spain": "EUR",
        "dia": "EUR",
        "alcampo": "EUR",
        
        // Italian Merchants
        "conad": "EUR",
        "coop italia": "EUR",
        "esselunga": "EUR",
        "eurospin": "EUR",
        "bennet": "EUR",
        
        // Japanese Merchants
        "7-eleven japan": "JPY",
        "lawson": "JPY",
        "familymart": "JPY",
        "uniqlo": "JPY",
        "muji": "JPY",
        "don quijote": "JPY",
        "bic camera": "JPY",
        "yodobashi": "JPY"
    ]
    
    // MARK: - Location/Address Pattern Detection
    
    private let locationCurrencyPatterns: [(pattern: String, currency: String)] = [
        // UK Patterns
        ("\\b[A-Z]{1,2}\\d{1,2}[A-Z]?\\s?\\d[A-Z]{2}\\b", "GBP"), // UK Postcodes
        ("\\.co\\.uk", "GBP"),
        ("\\bUK\\b", "GBP"),
        ("\\bUnited Kingdom\\b", "GBP"),
        ("\\bEngland\\b", "GBP"),
        ("\\bScotland\\b", "GBP"),
        ("\\bWales\\b", "GBP"),
        ("\\bLondon\\b", "GBP"),
        ("\\bManchester\\b", "GBP"),
        ("\\bBirmingham\\b", "GBP"),
        ("\\bEdinburgh\\b", "GBP"),
        ("\\bGlasgow\\b", "GBP"),
        
        // German Patterns
        ("\\b\\d{5}\\s", "EUR"), // German Postcodes (5 digits)
        ("\\.de\\b", "EUR"),
        ("\\bDeutschland\\b", "EUR"),
        ("\\bGermany\\b", "EUR"),
        ("\\bBerlin\\b", "EUR"),
        ("\\bMunich\\b", "EUR"),
        ("\\bMünchen\\b", "EUR"),
        ("\\bHamburg\\b", "EUR"),
        ("\\bFrankfurt\\b", "EUR"),
        ("\\bKöln\\b", "EUR"),
        ("\\bCologne\\b", "EUR"),
        
        // US Patterns
        ("\\b\\d{5}(-\\d{4})?\\b", "USD"), // US ZIP codes
        ("\\bUSA\\b", "USD"),
        ("\\bUnited States\\b", "USD"),
        ("\\bNew York\\b", "USD"),
        ("\\bLos Angeles\\b", "USD"),
        ("\\bChicago\\b", "USD"),
        ("\\bHouston\\b", "USD"),
        ("\\bPhoenix\\b", "USD"),
        ("\\bPhiladelphia\\b", "USD"),
        ("\\bSan Antonio\\b", "USD"),
        ("\\bSan Diego\\b", "USD"),
        ("\\bDallas\\b", "USD"),
        ("\\bSan Jose\\b", "USD"),
        
        // Indian Patterns
        ("\\b\\d{6}\\b", "INR"), // Indian PIN codes
        ("\\bIndia\\b", "INR"),
        ("\\bMumbai\\b", "INR"),
        ("\\bDelhi\\b", "INR"),
        ("\\bBangalore\\b", "INR"),
        ("\\bBengaluru\\b", "INR"),
        ("\\bHyderabad\\b", "INR"),
        ("\\bChennai\\b", "INR"),
        ("\\bKolkata\\b", "INR"),
        ("\\bPune\\b", "INR"),
        ("\\bAhmedabad\\b", "INR"),
        ("\\bJaipur\\b", "INR"),
        
        // Canadian Patterns
        ("\\b[A-Z]\\d[A-Z]\\s?\\d[A-Z]\\d\\b", "CAD"), // Canadian Postal Codes
        ("\\bCanada\\b", "CAD"),
        ("\\bToronto\\b", "CAD"),
        ("\\bVancouver\\b", "CAD"),
        ("\\bMontreal\\b", "CAD"),
        ("\\bCalgary\\b", "CAD"),
        ("\\bOttawa\\b", "CAD"),
        
        // Australian Patterns
        ("\\bAustralia\\b", "AUD"),
        ("\\bSydney\\b", "AUD"),
        ("\\bMelbourne\\b", "AUD"),
        ("\\bBrisbane\\b", "AUD"),
        ("\\bPerth\\b", "AUD"),
        ("\\bAdelaide\\b", "AUD"),
        
        // European Patterns
        ("\\bFrance\\b", "EUR"),
        ("\\bParis\\b", "EUR"),
        ("\\bSpain\\b", "EUR"),
        ("\\bMadrid\\b", "EUR"),
        ("\\bBarcelona\\b", "EUR"),
        ("\\bItaly\\b", "EUR"),
        ("\\bRome\\b", "EUR"),
        ("\\bMilan\\b", "EUR"),
        ("\\bNetherlands\\b", "EUR"),
        ("\\bAmsterdam\\b", "EUR"),
        ("\\bBelgium\\b", "EUR"),
        ("\\bBrussels\\b", "EUR"),
        ("\\bAustria\\b", "EUR"),
        ("\\bVienna\\b", "EUR"),
        
        // Japanese Patterns
        ("\\bJapan\\b", "JPY"),
        ("\\bTokyo\\b", "JPY"),
        ("\\bOsaka\\b", "JPY"),
        ("\\bKyoto\\b", "JPY"),
        ("\\bYokohama\\b", "JPY")
    ]
    
    // MARK: - Main Currency Intelligence Function
    
    func intelligentCurrencyDetection(merchant: String, description: String? = nil, extractedText: String? = nil) -> String {
        let merchantLower = merchant.lowercased()
        let fullText = "\(merchant) \(description ?? "") \(extractedText ?? "")".lowercased()
        
        // Step 1: Direct merchant mapping
        for (merchantKey, currency) in merchantCurrencyMappings {
            if merchantLower.contains(merchantKey) {
                print("Currency detected via merchant mapping: \(merchantKey) -> \(currency)")
                return currency
            }
        }
        
        // Step 2: Location/Address pattern analysis
        for (pattern, currency) in locationCurrencyPatterns {
            if fullText.range(of: pattern, options: .regularExpression) != nil {
                print("Currency detected via location pattern: \(pattern) -> \(currency)")
                return currency
            }
        }
        
        // Step 3: Device locale fallback
        let deviceCurrency = getDeviceLocaleCurrency()
        if CurrencyHelper.isSupported(deviceCurrency) {
            print("Currency detected via device locale: \(deviceCurrency)")
            return deviceCurrency
        }
        
        // Step 4: Final fallback to USD
        print("Currency detection failed, defaulting to USD")
        return "USD"
    }
    
    // MARK: - Helper Functions
    
    private func getDeviceLocaleCurrency() -> String {
        let locale = Locale.current
        if #available(iOS 16.0, *) {
            return locale.currency?.identifier ?? "USD"
        } else {
            return locale.currencyCode ?? "USD"
        }
    }
    
    // MARK: - Enhanced Currency Analysis with Confidence Score
    
    func analyzeCurrencyWithConfidence(merchant: String, description: String? = nil, extractedText: String? = nil) -> (currency: String, confidence: Double) {
        let merchantLower = merchant.lowercased()
        let fullText = "\(merchant) \(description ?? "") \(extractedText ?? "")".lowercased()
        
        // High confidence: Direct merchant mapping
        for (merchantKey, currency) in merchantCurrencyMappings {
            if merchantLower.contains(merchantKey) {
                return (currency, 0.9)
            }
        }
        
        // Medium confidence: Location pattern
        for (pattern, currency) in locationCurrencyPatterns {
            if fullText.range(of: pattern, options: .regularExpression) != nil {
                return (currency, 0.7)
            }
        }
        
        // Low confidence: Device locale
        let deviceCurrency = getDeviceLocaleCurrency()
        if CurrencyHelper.isSupported(deviceCurrency) {
            return (deviceCurrency, 0.3)
        }
        
        // No confidence: Default fallback
        return ("USD", 0.1)
    }
    
    // MARK: - Merchant Chain Analysis
    
    func isKnownInternationalChain(_ merchantName: String) -> Bool {
        let merchantLower = merchantName.lowercased()
        let internationalChains = ["mcdonald", "subway", "starbucks", "kfc", "burger king", "pizza hut", "domino", "coca cola", "pepsi", "shell", "bp", "exxon", "chevron", "7-eleven", "amazon", "google", "apple", "microsoft", "netflix", "uber", "booking.com", "airbnb"]
        
        return internationalChains.contains { merchantLower.contains($0) }
    }
    
    func suggestAlternateCurrencies(for merchantName: String) -> [String] {
        let merchantLower = merchantName.lowercased()
        
        // Return possible currencies for ambiguous merchants
        if merchantLower.contains("subway") {
            return ["USD", "GBP", "EUR", "CAD", "AUD"]
        } else if merchantLower.contains("mcdonald") {
            return ["USD", "GBP", "EUR", "CAD", "AUD", "JPY"]
        } else if merchantLower.contains("starbucks") {
            return ["USD", "GBP", "EUR", "CAD", "JPY", "CNY"]
        }
        
        return []
    }
}

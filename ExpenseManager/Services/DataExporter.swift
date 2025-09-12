import Foundation

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .json: return "doc.text"
        }
    }
}

class DataExporter {
    func exportData(
        expenses: [Expense],
        format: ExportFormat,
        includeItems: Bool = true,
        includeFinancialBreakdown: Bool = true,
        progressCallback: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        
        // Create a safe filename without spaces or special characters
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "ExpenseExport_\(dateString).\(format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        switch format {
        case .csv:
            try await exportCSV(expenses: expenses, to: fileURL, includeItems: includeItems, includeFinancialBreakdown: includeFinancialBreakdown, progressCallback: progressCallback)
        case .json:
            try await exportJSON(expenses: expenses, to: fileURL, includeItems: includeItems, includeFinancialBreakdown: includeFinancialBreakdown, progressCallback: progressCallback)
        }
        
        return fileURL
    }
    
    // MARK: - CSV Export
    private func exportCSV(expenses: [Expense], to url: URL, includeItems: Bool, includeFinancialBreakdown: Bool, progressCallback: @escaping (Double) -> Void) async throws {
        var csvContent = ""
        
        // Create header
        var headers = ["Date", "Merchant", "Amount", "Currency", "Category", "Description", "Payment Method"]
        
        if includeFinancialBreakdown {
            headers.append(contentsOf: ["Tax Amount", "Subtotal", "Tip", "Fees", "Discount"])
        }
        
        if includeItems {
            headers.append(contentsOf: ["Items Count", "Items Detail"])
        }
        
        csvContent += headers.joined(separator: ",") + "\n"
        
        // Process expenses
        for (index, expense) in expenses.enumerated() {
            await MainActor.run {
                progressCallback(Double(index) / Double(expenses.count))
            }
            
            var row = [
                expense.date.formatted(date: .abbreviated, time: .omitted),
                escapeCSV(expense.merchant),
                String(expense.amount),
                expense.currency,
                escapeCSV(expense.category),
                escapeCSV(expense.description ?? ""),
                escapeCSV(expense.paymentMethod ?? "")
            ]
            
            if includeFinancialBreakdown {
                row.append(contentsOf: [
                    String(expense.taxAmount ?? 0),
                    String(expense.subtotal ?? 0),
                    String(expense.tip ?? 0),
                    String(expense.fees ?? 0),
                    "0" // Discount not currently in Expense model
                ])
            }
            
            if includeItems {
                let itemsCount = expense.items?.count ?? 0
                let itemsDetail = expense.items?.map { "\($0.name): \($0.quantity ?? 0)x@\(String($0.unitPrice ?? 0))" }.joined(separator: "; ") ?? ""
                row.append(contentsOf: [String(itemsCount), escapeCSV(itemsDetail)])
            }
            
            csvContent += row.joined(separator: ",") + "\n"
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - JSON Export
    private func exportJSON(expenses: [Expense], to url: URL, includeItems: Bool, includeFinancialBreakdown: Bool, progressCallback: @escaping (Double) -> Void) async throws {
        var exportData: [String: Any] = [:]
        
        // Metadata
        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportData["version"] = "2.1.1"
        exportData["totalExpenses"] = expenses.count
        exportData["totalAmount"] = expenses.reduce(0) { $0 + $1.amount }
        exportData["includeItems"] = includeItems
        exportData["includeFinancialBreakdown"] = includeFinancialBreakdown
        
        // Process expenses
        var expensesData: [[String: Any]] = []
        
        for (index, expense) in expenses.enumerated() {
            await MainActor.run {
                progressCallback(Double(index) / Double(expenses.count))
            }
            
            var expenseDict: [String: Any] = [
                "id": expense.id.uuidString,
                "date": ISO8601DateFormatter().string(from: expense.date),
                "merchant": expense.merchant,
                "amount": expense.amount,
                "currency": expense.currency,
                "category": expense.category
            ]
            
            if let description = expense.description {
                expenseDict["description"] = description
            }
            
            if let paymentMethod = expense.paymentMethod {
                expenseDict["paymentMethod"] = paymentMethod
            }
            
            if includeFinancialBreakdown {
                if let taxAmount = expense.taxAmount {
                    expenseDict["taxAmount"] = taxAmount
                }
                if let subtotal = expense.subtotal {
                    expenseDict["subtotal"] = subtotal
                }
                if let tip = expense.tip {
                    expenseDict["tip"] = tip
                }
                if let fees = expense.fees {
                    expenseDict["fees"] = fees
                }
                // Note: Discount field not currently available in Expense model
                expenseDict["discount"] = 0
            }
            
            if includeItems, let items = expense.items {
                let itemsData = items.map { item in
                    [
                        "name": item.name,
                        "quantity": item.quantity ?? 0,
                        "unitPrice": item.unitPrice ?? 0,
                        "totalPrice": item.totalPrice,
                        "category": item.category ?? "",
                        "description": item.description ?? ""
                    ] as [String: Any]
                }
                expenseDict["items"] = itemsData
            }
            
            expensesData.append(expenseDict)
        }
        
        exportData["expenses"] = expensesData
        
        // Summary statistics
        let categoryTotals = Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        
        exportData["summary"] = [
            "categoryTotals": categoryTotals,
            "dateRange": [
                "start": expenses.map { $0.date }.min()?.timeIntervalSince1970 ?? 0,
                "end": expenses.map { $0.date }.max()?.timeIntervalSince1970 ?? 0
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: url)
    }
    
    
    
    // MARK: - Helper Methods
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }
}
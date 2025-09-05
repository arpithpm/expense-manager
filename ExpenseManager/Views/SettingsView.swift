import SwiftUI
import Foundation
import MessageUI

struct SettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @ObservedObject private var expenseService = ExpenseService.shared
    @State private var showingConfigurationSheet = false
    @State private var showingClearAlert = false
    @State private var showingSuccessAlert = false
    @State private var showingMailComposer = false
    @State private var showingMailAlert = false
    @State private var showingEmailOptions = false
    @State private var showingSampleDataAlert = false
    @State private var showingDataResetView = false
    @State private var showingPricingView = false
    
    var body: some View {
        NavigationView {
            List {
                connectionStatusSection
                subscriptionSection
                configurationSection
                backupStatusSection
                dataManagementSection
                feedbackSection
                developmentSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingConfigurationSheet) {
            ReconfigurationView()
                .environmentObject(configurationManager)
        }
        .alert("Clear Configuration", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                configurationManager.clearConfiguration()
                showingSuccessAlert = true
            }
        } message: {
            Text("This will remove your stored OpenAI API key. You'll need to reconfigure it to use the app.")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Configuration cleared successfully.")
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(
                recipient: "arpithpmuddi@gmail.com",
                subject: "ReceiptRadar App Feedback",
                body: "Hi there,\n\nI have some feedback about the ReceiptRadar app:\n\n"
            )
        }
        .alert("Email Not Available", isPresented: $showingMailAlert) {
            Button("OK") { }
        } message: {
            Text("Please make sure you have configured Mail app on your device to send feedback.")
        }
        .confirmationDialog("Choose Email App", isPresented: $showingEmailOptions, titleVisibility: .visible) {
            Button("Mail App") {
                openMailApp()
            }
            Button("Gmail") {
                openGmail()
            }
            Button("Outlook") {
                openOutlook()
            }
            Button("Yahoo Mail") {
                openYahooMail()
            }
            Button("Copy Email Address") {
                copyEmailAddress()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Select your preferred email app to send feedback")
        }
        .alert("Add Sample Data", isPresented: $showingSampleDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Add Sample Data") {
                addSampleData()
            }
        } message: {
            Text("This will add 5 sample expenses to help you explore the app. Your existing data will be preserved.")
        }
        .sheet(isPresented: $showingDataResetView) {
            DataResetView()
        }
        .sheet(isPresented: $showingPricingView) {
            PricingView()
        }
    }
    
    private var connectionStatusSection: some View {
        Section("OpenAI Connection Status") {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.accentColor)
                Text("OpenAI API")
                Spacer()
                connectionStatusIndicator
            }
            
            if case .failure(let error) = configurationManager.connectionStatus {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
            
            Button("Test Connection") {
                Task {
                    await configurationManager.testConnections()
                }
            }
            .disabled(configurationManager.isTestingConnection)
        }
    }
    
    private var connectionStatusIndicator: some View {
        Group {
            switch configurationManager.connectionStatus {
            case .notTested:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
            case .testing:
                ProgressView()
                    .scaleEffect(0.8)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var subscriptionSection: some View {
        Section("Subscription & Usage") {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.headline)
                    Text(SubscriptionManager.shared.currentTier.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if SubscriptionManager.shared.currentTier == .free {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(SubscriptionManager.shared.scansRemainingToday)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text("scans left today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "infinity")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
            
            Button(action: {
                showingPricingView = true
            }) {
                HStack {
                    Image(systemName: "creditcard")
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Subscription")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("View plans, upgrade, or change settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    private var configurationSection: some View {
        Section("Configuration") {
            Button(action: {
                showingConfigurationSheet = true
            }) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.accentColor)
                    Text("Configure OpenAI API")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: {
                showingClearAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Clear Configuration")
                }
            }
            .foregroundColor(.red)
        }
    }
    
    private var backupStatusSection: some View {
        Section("Data Backup") {
            HStack {
                Image(systemName: backupStatus.icon)
                    .foregroundColor(backupStatus.color)
                Text("Backup Status")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(backupStatus.displayText)
                        .foregroundColor(backupStatus.color)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let lastBackup = expenseService.getLastBackupDate() {
                        Text(formatBackupDate(lastBackup))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.accentColor)
                Text("Expenses Count")
                Spacer()
                Text("\(expenseService.expenses.count)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var backupStatus: BackupStatus {
        expenseService.getBackupStatus()
    }
    
    private func formatBackupDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
    
    private var feedbackSection: some View {
        Section("Feedback") {
            Button(action: {
                sendFeedback()
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.accentColor)
                    Text("Send Feedback")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    private func sendFeedback() {
        showingEmailOptions = true
    }
    
    private func openMailApp() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            showingMailAlert = true
        }
    }
    
    private func openGmail() {
        let subject = "ReceiptRadar App Feedback"
        let body = "Hi there,\n\nI have some feedback about the ReceiptRadar app:\n\n"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Gmail URL scheme format
        if let gmailURL = URL(string: "googlegmail://co?to=arpithpmuddi@gmail.com&subject=\(encodedSubject)&body=\(encodedBody)"),
           UIApplication.shared.canOpenURL(gmailURL) {
            UIApplication.shared.open(gmailURL)
        } else {
            // Fallback to web Gmail
            if let webGmailURL = URL(string: "https://mail.google.com/mail/?view=cm&fs=1&to=arpithpmuddi@gmail.com&subject=\(encodedSubject)&body=\(encodedBody)") {
                UIApplication.shared.open(webGmailURL)
            }
        }
    }
    
    private func openOutlook() {
        let subject = "ReceiptRadar App Feedback"
        let body = "Hi there,\n\nI have some feedback about the ReceiptRadar app:\n\n"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let outlookURL = URL(string: "ms-outlook://compose?to=arpithpmuddi@gmail.com&subject=\(encodedSubject)&body=\(encodedBody)"),
           UIApplication.shared.canOpenURL(outlookURL) {
            UIApplication.shared.open(outlookURL)
        } else if let webOutlookURL = URL(string: "https://outlook.live.com/mail/0/deeplink/compose?to=arpithpmuddi@gmail.com&subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(webOutlookURL)
        }
    }
    
    private func openYahooMail() {
        let subject = "ReceiptRadar App Feedback"
        let body = "Hi there,\n\nI have some feedback about the ReceiptRadar app:\n\n"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let yahooURL = URL(string: "ymail://mail/compose?to=arpithpmuddi@gmail.com&subject=\(encodedSubject)&body=\(encodedBody)"),
           UIApplication.shared.canOpenURL(yahooURL) {
            UIApplication.shared.open(yahooURL)
        } else if let webYahooURL = URL(string: "https://compose.mail.yahoo.com/?to=arpithpmuddi@gmail.com&subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(webYahooURL)
        }
    }
    
    private func copyEmailAddress() {
        UIPasteboard.general.string = "arpithpmuddi@gmail.com"
        // Show a brief feedback that email was copied
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private var dataManagementSection: some View {
        Section("Data Management") {
            Button(action: {
                showingDataResetView = true
            }) {
                HStack {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                    Text("Reset App Data")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    private var developmentSection: some View {
        #if DEBUG
        Section("Development") {
            Button(action: {
                showingSampleDataAlert = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.orange)
                    Text("Add Sample Data")
                    Spacer()
                    Text("\(expenseService.expenses.count) expenses")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        }
        #else
        EmptyView()
        #endif
    }
    
    private func addSampleData() {
        let calendar = Calendar.current
        let now = Date()
        
        let sampleExpenses = [
            Expense(
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                merchant: "Starbucks Coffee",
                amount: 4.75,
                currency: "USD",
                category: "Food & Dining",
                description: "Morning coffee and pastry",
                paymentMethod: "Credit Card",
                taxAmount: 0.38
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                merchant: "Shell Gas Station",
                amount: 45.20,
                currency: "USD",
                category: "Transportation",
                description: "Fuel",
                paymentMethod: "Debit Card",
                taxAmount: 3.62
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                merchant: "Target",
                amount: 23.99,
                currency: "USD",
                category: "Shopping",
                description: "Household items",
                paymentMethod: "Credit Card",
                taxAmount: 1.92
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                merchant: "Chipotle Mexican Grill",
                amount: 12.85,
                currency: "USD",
                category: "Food & Dining",
                description: "Burrito bowl and drink",
                paymentMethod: "Digital Payment",
                taxAmount: 1.03
            ),
            Expense(
                date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                merchant: "Amazon.com",
                amount: 89.99,
                currency: "USD",
                category: "Shopping",
                description: "Office supplies",
                paymentMethod: "Credit Card",
                taxAmount: 7.20
            )
        ]
        
        for expense in sampleExpenses {
            let _ = expenseService.addExpense(expense)
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "icloud")
                    .foregroundColor(.accentColor)
                Text("Storage")
                Spacer()
                Text("Local + iCloud")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.accentColor)
                Text("AI Service")
                Spacer()
                Text("OpenAI Vision")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ReconfigurationView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @Environment(\.dismiss) private var dismiss
    @State private var openaiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    configurationForm
                    testConnectionSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Configure OpenAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveConfiguration()
                        }
                    }
                    .disabled(isFieldsEmpty || isProcessing || !isConnectionSuccessful)
                }
            }
        }
        .onAppear {
            loadCurrentConfiguration()
        }
        .alert("Configuration", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var configurationForm: some View {
        VStack(spacing: 20) {
            GroupBox("OpenAI Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    SecureField("sk-proj-...", text: $openaiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    Text("Required for AI-powered receipt processing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Button("Test Connection") {
                Task {
                    await testConnections()
                }
            }
            .buttonStyle(.bordered)
            .disabled(isFieldsEmpty || isProcessing)
        }
    }
    
    private var testConnectionSection: some View {
        Group {
            if configurationManager.isTestingConnection {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing connections...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                switch configurationManager.connectionStatus {
                case .notTested:
                    EmptyView()
                case .testing:
                    EmptyView()
                case .success:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("OpenAI connection successful!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding()
                case .failure(let error):
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                }
            }
        }
    }
    
    private var isFieldsEmpty: Bool {
        openaiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isConnectionSuccessful: Bool {
        if case .success = configurationManager.connectionStatus {
            return true
        }
        return false
    }
    
    private func loadCurrentConfiguration() {
        openaiKey = configurationManager.getOpenAIKey() ?? ""
    }
    
    private func testConnections() async {
        isProcessing = true
        
        let success = await configurationManager.saveConfiguration(
            openaiKey: openaiKey
        )
        
        if success {
            await configurationManager.testConnections()
        } else {
            alertMessage = "Failed to save configuration temporarily for testing"
            showingAlert = true
        }
        
        isProcessing = false
    }
    
    private func saveConfiguration() async {
        isProcessing = true
        
        let success = await configurationManager.saveConfiguration(
            openaiKey: openaiKey
        )
        
        if success {
            alertMessage = "Configuration updated successfully!"
        } else {
            alertMessage = "Failed to update configuration. Please try again."
        }
        
        showingAlert = true
        isProcessing = false
    }
}

struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients([recipient])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ConfigurationManager())
}

// MARK: - Data Reset View
struct DataResetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var resetManager = DataResetManager.shared
    @State private var selectedCategories: Set<DataResetManager.ResetCategory> = []
    @State private var showingConfirmation = false
    @State private var showingProgress = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var resetProgress = 0.0
    @State private var categoryItemCounts: [DataResetManager.ResetCategory: Int] = [:]
    @State private var resetSummary = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    categoriesSection
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Reset App Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Confirm Data Reset", isPresented: $showingConfirmation) {
            Button("Yes, Delete Selected Data", role: .destructive) {
                performReset()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You are about to delete:\n\n\(resetSummary)\n\nThis action cannot be undone.")
        }
        .alert("Reset Complete", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Selected data has been successfully reset. Consider restarting the app to see all changes.")
        }
        .alert("Reset Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if showingProgress {
                resetProgressOverlay
            }
        }
        .onAppear {
            loadItemCounts()
        }
        .onChange(of: selectedCategories) {
            updateResetSummary()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.circle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Select Data to Reset")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose which data you want to remove from the app. Be careful - most actions cannot be undone.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    private var categoriesSection: some View {
        VStack(spacing: 16) {
            // Expense Data Group
            categoryGroup(
                title: "💰 Expense Data",
                categories: [.allExpenses, .sampleExpenses, .analyticsCache]
            )
            
            // OpenAI Configuration Group
            categoryGroup(
                title: "🤖 OpenAI Configuration", 
                categories: [.openAIKey, .openAIHistory]
            )
            
            // App Settings Group
            categoryGroup(
                title: "⚙️ App Settings",
                categories: [.userPreferences, .firstLaunchFlag, .backupData]
            )
            
            // Complete Reset Group
            categoryGroup(
                title: "🧹 Complete Reset",
                categories: [.completeReset]
            )
        }
    }
    
    private func categoryGroup(title: String, categories: [DataResetManager.ResetCategory]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    categoryRow(category: category)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
    }
    
    private func categoryRow(category: DataResetManager.ResetCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundColor(category.isDestructive ? .red : .blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(category.isDestructive ? .red : .primary)
                    
                    if let itemCount = categoryItemCounts[category], itemCount > 0 {
                        Text("(\(itemCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Text(category.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { selectedCategories.contains(category) },
                set: { isSelected in
                    if isSelected {
                        selectedCategories.insert(category)
                        // If complete reset is selected, deselect others
                        if category == .completeReset {
                            selectedCategories = [.completeReset]
                        }
                    } else {
                        selectedCategories.remove(category)
                    }
                    
                    // If any other category is selected, deselect complete reset
                    if category != .completeReset && isSelected {
                        selectedCategories.remove(.completeReset)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: category.isDestructive ? .red : .accentColor))
        }
        .padding(.vertical, 4)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset Selected Data")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCategories.isEmpty ? Color.gray : Color.red)
                .cornerRadius(12)
            }
            .disabled(selectedCategories.isEmpty)
            
            if !selectedCategories.isEmpty {
                Text("Selected: \(selectedCategories.count) item\(selectedCategories.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var resetProgressOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Resetting Data...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
            }
    }
    
    private func performReset() {
        showingProgress = true
        
        Task {
            do {
                try await resetManager.resetData(categories: selectedCategories)
                
                await MainActor.run {
                    showingProgress = false
                    showingSuccess = true
                    selectedCategories.removeAll()
                }
            } catch {
                await MainActor.run {
                    showingProgress = false
                    errorMessage = "Failed to reset data: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    @MainActor
    private func loadItemCounts() {
        for category in DataResetManager.ResetCategory.allCases {
            categoryItemCounts[category] = resetManager.getItemCount(for: category)
        }
    }
    
    @MainActor
    private func updateResetSummary() {
        resetSummary = resetManager.getResetSummary(for: selectedCategories)
    }
}

#Preview("DataResetView") {
    DataResetView()
}


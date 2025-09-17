import SwiftUI

struct DebugView: View {
    @State private var showingLogExport = false
    @State private var logExportURL: URL?
    @State private var errorStats = ErrorTrackingService.shared.getErrorStatistics()

    private let logger = LoggingService.shared
    private let errorTracker = ErrorTrackingService.shared

    var body: some View {
        NavigationView {
            List {
                // System Health Section
                Section("System Health") {
                    HStack {
                        Image(systemName: healthIcon)
                            .foregroundColor(healthColor)
                        Text("Health Score")
                        Spacer()
                        Text("\(Int(errorTracker.getHealthScore() * 100))%")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(KeychainService.shared.hasValidAPIKey() ? .green : .red)
                        Text("API Key Status")
                        Spacer()
                        Text(KeychainService.shared.hasValidAPIKey() ? "Configured" : "Missing")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text("Recent Errors")
                        Spacer()
                        Text(errorTracker.hasRecentErrors() ? "Yes" : "None")
                            .fontWeight(.medium)
                            .foregroundColor(errorTracker.hasRecentErrors() ? .orange : .green)
                    }
                }

                // Error Statistics Section
                Section("Error Statistics") {
                    StatRow(title: "Total Errors", value: "\(errorStats.totalErrors)", icon: "exclamationmark.triangle")
                    StatRow(title: "API Key Errors", value: "\(errorStats.apiKeyErrors)", icon: "key")
                    StatRow(title: "Network Errors", value: "\(errorStats.networkErrors)", icon: "wifi.exclamationmark")
                    StatRow(title: "OpenAI Errors", value: "\(errorStats.openaiErrors)", icon: "brain")
                    StatRow(title: "Image Processing Errors", value: "\(errorStats.imageProcessingErrors)", icon: "photo")
                    StatRow(title: "Consecutive Failures", value: "\(errorStats.consecutiveFailures)", icon: "arrow.counterclockwise")

                    if let lastError = errorStats.lastErrorDate {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.gray)
                            Text("Last Error")
                            Spacer()
                            Text(RelativeDateTimeFormatter().localizedString(for: lastError, relativeTo: Date()))
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Recent Error Summary
                Section("Recent Error Analysis") {
                    let errorSummary = logger.getErrorSummary(hours: 24)
                    if errorSummary.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No errors in the last 24 hours")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(errorSummary.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                            HStack {
                                Image(systemName: iconFor(category: category))
                                    .foregroundColor(.red)
                                Text(category.replacingOccurrences(of: "_", with: " "))
                                Spacer()
                                Text("\(count)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                // Actions Section
                Section("Debug Actions") {
                    Button(action: exportLogs) {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }

                    Button(action: clearErrorStats) {
                        Label("Reset Error Statistics", systemImage: "arrow.counterclockwise")
                    }
                    .foregroundColor(.orange)

                    Button(action: testLogging) {
                        Label("Test Logging System", systemImage: "hammer.fill")
                    }
                    .foregroundColor(.blue)
                }

                // Log Files Section
                Section("Log Files") {
                    let logFiles = logger.getAllLogFiles()
                    if logFiles.isEmpty {
                        Text("No log files available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(logFiles, id: \.path) { logFile in
                            LogFileRow(logFile: logFile)
                        }
                    }
                }

                // Development Info
                Section("Development Info") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build Number")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Device")
                        Spacer()
                        Text("\(UIDevice.current.model)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("iOS Version")
                        Spacer()
                        Text(UIDevice.current.systemVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Debug & Diagnostics")
            .refreshable {
                refreshStats()
            }
        }
        .sheet(isPresented: $showingLogExport) {
            if let url = logExportURL {
                ActivityView(activityItems: [url])
            }
        }
        .onAppear {
            refreshStats()
        }
    }

    private var healthIcon: String {
        let score = errorTracker.getHealthScore()
        if score > 0.8 { return "checkmark.circle.fill" }
        if score > 0.5 { return "exclamationmark.triangle.fill" }
        return "xmark.circle.fill"
    }

    private var healthColor: Color {
        let score = errorTracker.getHealthScore()
        if score > 0.8 { return .green }
        if score > 0.5 { return .orange }
        return .red
    }

    private func iconFor(category: String) -> String {
        switch category {
        case "API_KEY": return "key"
        case "NETWORK": return "wifi.exclamationmark"
        case "OPENAI": return "brain"
        case "IMAGE_PROCESSING": return "photo"
        case "DATA_STORAGE": return "externaldrive"
        case "PERFORMANCE": return "speedometer"
        default: return "exclamationmark.triangle"
        }
    }

    private func refreshStats() {
        errorStats = errorTracker.getErrorStatistics()
    }

    private func exportLogs() {
        if let exportURL = logger.exportLogsForSupport() {
            logExportURL = exportURL
            showingLogExport = true
        }
    }

    private func clearErrorStats() {
        errorTracker.resetStatistics()
        refreshStats()
    }

    private func testLogging() {
        logger.debug("Debug log test", category: .unknown)
        logger.info("Info log test", category: .configuration)
        logger.warning("Warning log test", category: .performance)
        logger.error("Error log test", category: .unknown)

        refreshStats()
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct LogFileRow: View {
    let logFile: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(logFile.lastPathComponent)
                .fontWeight(.medium)

            if let attributes = try? FileManager.default.attributesOfItem(atPath: logFile.path),
               let size = attributes[.size] as? Int64,
               let date = attributes[.modificationDate] as? Date {
                HStack {
                    Text("\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DebugView()
}
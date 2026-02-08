import SwiftData
import SwiftUI

@main
struct SubsKunApp: App {
    @StateObject private var authStore = AuthenticationStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var exchangeRates = ExchangeRateStore()
    private let modelContainer: ModelContainer = Self.makeContainer()

    init() {
        AppLogger.lifecycle.info("app.launch")
    }

    var body: some Scene {
        WindowGroup {
            AppFlowView()
                .environmentObject(authStore)
                .environmentObject(settings)
                .environmentObject(exchangeRates)
                .preferredColorScheme(preferredColorScheme(for: settings.themeMode))
                .tint(settings.themeColor.color)
                .task {
                    await authStore.restoreSessionIfNeeded()
                    await exchangeRates.refreshIfNeeded()
                }
                .onOpenURL { url in
                    authStore.handleOpenURL(url)
                }
        }
        .modelContainer(modelContainer)
    }

    private func preferredColorScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Subscription.self,
            BillingEvent.self
        ])
        let storeURL = persistentStoreURL()

        do {
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let message = String(describing: error)
            AppLogger.error.error("model_container.init primary failed: \(message, privacy: .public)")

            
            do {
                try backupAndResetStoreFiles(at: storeURL)
                let configuration = ModelConfiguration(schema: schema, url: storeURL)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                AppLogger.error.error("model_container.recovered by resetting persistent store")
                return container
            } catch {
                let retryMessage = String(describing: error)
                fatalError("ModelContainer initialization failed after reset: \(retryMessage)")
            }
        }
    }

    private static func persistentStoreURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let appDirectory = baseDirectory.appendingPathComponent("SubsKun", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appendingPathComponent("SubsKun.store")
    }

    private static func backupAndResetStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let backupDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("CorruptedStores", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let candidates: [URL] = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]

        for fileURL in candidates where fileManager.fileExists(atPath: fileURL.path) {
            let backupURL = backupDirectory.appendingPathComponent("\(fileURL.lastPathComponent).\(timestamp).bak")
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.moveItem(at: fileURL, to: backupURL)
        }
    }
}

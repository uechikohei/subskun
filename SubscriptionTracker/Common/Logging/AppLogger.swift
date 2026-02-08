import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = "com.uechikohei.subskun"

    static let lifecycle = Logger(subsystem: subsystem, category: "app.lifecycle")
    static let subscription = Logger(subsystem: subsystem, category: "subscription.crud")
    static let export = Logger(subsystem: subsystem, category: "export")
    static let error = Logger(subsystem: subsystem, category: "error")
}

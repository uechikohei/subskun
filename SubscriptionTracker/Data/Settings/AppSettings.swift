import Foundation

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return String(localized: "settings.theme_mode.system")
        case .light:
            return String(localized: "settings.theme_mode.light")
        case .dark:
            return String(localized: "settings.theme_mode.dark")
        }
    }
}

enum ThemeColorOption: String, CaseIterable, Identifiable {
    case blue
    case indigo
    case purple
    case teal
    case mint
    case cyan
    case green
    case yellow
    case orange
    case red
    case pink
    case brown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blue:
            return String(localized: "settings.theme_color.blue")
        case .indigo:
            return String(localized: "settings.theme_color.indigo")
        case .purple:
            return String(localized: "settings.theme_color.purple")
        case .teal:
            return String(localized: "settings.theme_color.teal")
        case .mint:
            return String(localized: "settings.theme_color.mint")
        case .cyan:
            return String(localized: "settings.theme_color.cyan")
        case .green:
            return String(localized: "settings.theme_color.green")
        case .yellow:
            return String(localized: "settings.theme_color.yellow")
        case .orange:
            return String(localized: "settings.theme_color.orange")
        case .red:
            return String(localized: "settings.theme_color.red")
        case .pink:
            return String(localized: "settings.theme_color.pink")
        case .brown:
            return String(localized: "settings.theme_color.brown")
        }
    }
}

final class AppSettings: ObservableObject {
    private enum Keys {
        static let defaultCurrency = "settings.defaultCurrency"
        static let pastMonths = "settings.historyPastMonths"
        static let futureMonths = "settings.historyFutureMonths"
        static let includePausedInSummary = "settings.includePausedInSummary"
        static let themeMode = "settings.themeMode"
        static let themeColor = "settings.themeColor"
        static let notifyBeforeBilling = "settings.notifyBeforeBilling"
    }

    @Published var defaultCurrency: String {
        didSet {
            let normalized = Self.normalizeCurrency(defaultCurrency)
            if normalized != defaultCurrency {
                defaultCurrency = normalized
                return
            }
            defaults.set(normalized, forKey: Keys.defaultCurrency)
        }
    }

    @Published var pastMonths: Int {
        didSet {
            let clamped = max(1, min(24, pastMonths))
            if clamped != pastMonths {
                pastMonths = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.pastMonths)
        }
    }

    @Published var futureMonths: Int {
        didSet {
            let clamped = max(1, min(36, futureMonths))
            if clamped != futureMonths {
                futureMonths = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.futureMonths)
        }
    }

    @Published var includePausedInSummary: Bool {
        didSet {
            defaults.set(includePausedInSummary, forKey: Keys.includePausedInSummary)
        }
    }

    @Published var themeModeRaw: String {
        didSet {
            let normalized = Self.normalizeThemeMode(themeModeRaw)
            if normalized != themeModeRaw {
                themeModeRaw = normalized
                return
            }
            defaults.set(normalized, forKey: Keys.themeMode)
        }
    }

    @Published var themeColorRaw: String {
        didSet {
            let normalized = Self.normalizeThemeColor(themeColorRaw)
            if normalized != themeColorRaw {
                themeColorRaw = normalized
                return
            }
            defaults.set(normalized, forKey: Keys.themeColor)
        }
    }

    @Published var notifyBeforeBilling: Bool {
        didSet {
            defaults.set(notifyBeforeBilling, forKey: Keys.notifyBeforeBilling)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let currency = defaults.string(forKey: Keys.defaultCurrency) ?? "JPY"
        self.defaultCurrency = Self.normalizeCurrency(currency)

        let rawPast = defaults.object(forKey: Keys.pastMonths) as? Int ?? 6
        self.pastMonths = max(1, min(24, rawPast))

        let rawFuture = defaults.object(forKey: Keys.futureMonths) as? Int ?? 12
        self.futureMonths = max(1, min(36, rawFuture))

        self.includePausedInSummary = defaults.object(forKey: Keys.includePausedInSummary) as? Bool ?? false

        let rawThemeMode = defaults.string(forKey: Keys.themeMode) ?? ThemeMode.system.rawValue
        self.themeModeRaw = Self.normalizeThemeMode(rawThemeMode)

        let rawThemeColor = defaults.string(forKey: Keys.themeColor) ?? ThemeColorOption.blue.rawValue
        self.themeColorRaw = Self.normalizeThemeColor(rawThemeColor)

        self.notifyBeforeBilling = defaults.object(forKey: Keys.notifyBeforeBilling) as? Bool ?? true
    }

    var generationSignature: String {
        "\(pastMonths)-\(futureMonths)-\(defaultCurrency)"
    }

    var snapshot: SettingsSnapshot {
        SettingsSnapshot(
            defaultCurrency: defaultCurrency,
            pastMonths: pastMonths,
            futureMonths: futureMonths,
            includePausedInSummary: includePausedInSummary
        )
    }

    var themeMode: ThemeMode {
        get { ThemeMode(rawValue: themeModeRaw) ?? .system }
        set { themeModeRaw = newValue.rawValue }
    }

    var themeColor: ThemeColorOption {
        get { ThemeColorOption(rawValue: themeColorRaw) ?? .blue }
        set { themeColorRaw = newValue.rawValue }
    }

    private static func normalizeCurrency(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = String(trimmed.prefix(3)).uppercased()
        return upper.isEmpty ? "JPY" : upper
    }

    private static func normalizeThemeMode(_ value: String) -> String {
        ThemeMode(rawValue: value) == nil ? ThemeMode.system.rawValue : value
    }

    private static func normalizeThemeColor(_ value: String) -> String {
        ThemeColorOption(rawValue: value) == nil ? ThemeColorOption.blue.rawValue : value
    }
}

struct SettingsSnapshot {
    let defaultCurrency: String
    let pastMonths: Int
    let futureMonths: Int
    let includePausedInSummary: Bool
}

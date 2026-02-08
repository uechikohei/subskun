import Foundation

struct CurrencyItem: Identifiable, Hashable {
    let code: String
    let localizedName: String

    var id: String { code }

    var label: String {
        "\(code) - \(localizedName)"
    }
}

enum CurrencyCatalog {
    static let preferredCodes: [String] = ["JPY", "USD", "EUR"]

    static let all: [CurrencyItem] = {
        let localeJP = Locale(identifier: "ja_JP")
        let localeCurrent = Locale.current

        let codes = Set(Locale.commonISOCurrencyCodes.map { $0.uppercased() })
            .union(Locale.Currency.isoCurrencies.map { $0.identifier.uppercased() })

        return codes
            .sorted()
            .map { code in
                let name = localeJP.localizedString(forCurrencyCode: code)
                    ?? localeCurrent.localizedString(forCurrencyCode: code)
                    ?? code
                return CurrencyItem(code: code, localizedName: name)
            }
    }()

    static func item(for code: String) -> CurrencyItem {
        let normalized = code.uppercased()
        if let matched = all.first(where: { $0.code == normalized }) {
            return matched
        }

        let localeJP = Locale(identifier: "ja_JP")
        let localeCurrent = Locale.current
        let name = localeJP.localizedString(forCurrencyCode: normalized)
            ?? localeCurrent.localizedString(forCurrencyCode: normalized)
            ?? normalized

        return CurrencyItem(code: normalized, localizedName: name)
    }
}

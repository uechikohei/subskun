import Foundation

struct ServiceCatalogPlan: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let localizedName: String?

    var displayName: String {
        let trimmed = localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return name
    }
}

struct ServiceCatalogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let localizedName: String?
    let aliases: [String]
    let categories: [String]
    let plans: [ServiceCatalogPlan]?

    var displayName: String {
        let trimmed = localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return name
    }

    var primaryCategory: String? {
        categories.first { !$0.isEmpty }
    }

    var primaryCategoryLocalized: String? {
        primaryCategory.map(Self.localizedCategoryName(for:))
    }

    var categoryLabel: String {
        if categories.isEmpty {
            return "-"
        }
        return categories.joined(separator: " / ")
    }

    var localizedCategoryLabel: String {
        if categories.isEmpty {
            return "-"
        }
        return categories
            .map(Self.localizedCategoryName(for:))
            .joined(separator: " / ")
    }

    var availablePlans: [ServiceCatalogPlan] {
        plans ?? []
    }

    static func localizedCategoryName(for category: String) -> String {
        switch category {
        case "Shopping":
            return String(localized: "category.shopping")
        case "Video":
            return String(localized: "category.video")
        case "Gaming":
            return String(localized: "category.gaming")
        case "Music":
            return String(localized: "category.music")
        case "Books":
            return String(localized: "category.books")
        case "Audio":
            return String(localized: "category.audio")
        case "AI":
            return String(localized: "category.ai")
        case "IT":
            return String(localized: "category.it")
        case "Productivity":
            return String(localized: "category.productivity")
        case "Design":
            return String(localized: "category.design")
        case "Entertainment":
            return String(localized: "category.entertainment")
        case "Cloud":
            return String(localized: "category.cloud")
        case "Developer":
            return String(localized: "category.developer")
        case "Creator":
            return String(localized: "category.creator")
        case "Community":
            return String(localized: "category.community")
        case "Learning":
            return String(localized: "category.learning")
        case "Social":
            return String(localized: "category.social")
        case "Business":
            return String(localized: "category.business")
        case "Communication":
            return String(localized: "category.communication")
        default:
            return category
        }
    }
}

struct ServiceCatalogPayload: Codable, Sendable {
    let version: Int
    let updatedAt: Date?
    let services: [ServiceCatalogEntry]
}

struct ServiceCatalogGenreGroup: Identifiable, Hashable, Sendable {
    let genre: String
    let services: [ServiceCatalogEntry]

    var id: String { genre }
}

enum ServiceCatalogSource: String, Sendable {
    case bundled
    case cache
    case remote

    var label: String {
        switch self {
        case .bundled:
            return String(localized: "service_catalog.source.bundled")
        case .cache:
            return String(localized: "service_catalog.source.cache")
        case .remote:
            return String(localized: "service_catalog.source.remote")
        }
    }
}

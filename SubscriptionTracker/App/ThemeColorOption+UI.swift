import Foundation
import SwiftUI

extension ThemeColorOption {
    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .indigo:
            return .indigo
        case .purple:
            return .purple
        case .teal:
            return .teal
        case .mint:
            return .mint
        case .cyan:
            return .cyan
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .orange:
            return .orange
        case .red:
            return .red
        case .pink:
            return .pink
        case .brown:
            return .brown
        }
    }

    var accessibilityLabel: String {
        let format = String(localized: "settings.theme_color.voiceover_format")
        return String(format: format, locale: Locale.autoupdatingCurrent, label)
    }
}

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authStore: AuthenticationStore
    @EnvironmentObject private var settings: AppSettings

    @State private var isShowingAccount = false
    @State private var isShowingExport = false
    @State private var isShowingAppShare = false
    @State private var isThemeDialogPresented = false
    @State private var infoAlert: InfoAlert?

    private let selectableCurrencies = CurrencyCatalog.preferredCodes

    private var languageDisplayName: String {
        let code = Bundle.main.preferredLocalizations.first
            ?? Locale.autoupdatingCurrent.language.languageCode?.identifier
            ?? "en"
        return Locale.autoupdatingCurrent.localizedString(forLanguageCode: code)
            ?? code.uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionTitle(String(localized: "settings.section.settings"))
                SettingsCard {
                    SettingsActionRow(
                        icon: "person.crop.circle",
                        title: String(localized: "settings.account"),
                        action: { isShowingAccount = true }
                    ) {
                        HStack(spacing: 8) {
                            Text(accountDisplayName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    SettingsActionRow(
                        icon: "circle.lefthalf.filled",
                        title: String(localized: "settings.theme.mode"),
                        action: { isThemeDialogPresented = true }
                    ) {
                        HStack(spacing: 8) {
                            Text(settings.themeMode.label)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    SettingsValueRow(
                        icon: "paintpalette",
                        title: String(localized: "settings.theme.color")
                    ) {
                        ThemeColorSwatchSelector(
                            selection: Binding(
                                get: { settings.themeColor },
                                set: { settings.themeColor = $0 }
                            )
                        )
                    }

                    Divider()

                    SettingsValueRow(icon: "dollarsign.circle", title: String(localized: "settings.default_currency")) {
                        Menu {
                            ForEach(selectableCurrencies, id: \.self) { code in
                                Button(code) {
                                    settings.defaultCurrency = code
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(settings.defaultCurrency)
                                    .font(.subheadline.weight(.semibold))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    SettingsActionRow(
                        icon: "globe",
                        title: String(localized: "settings.language"),
                        action: openAppSettings
                    ) {
                        HStack(spacing: 8) {
                            Text(languageDisplayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    SettingsActionRow(
                        icon: "doc.text",
                        title: String(localized: "settings.export.csv"),
                        action: { isShowingExport = true }
                    )

                    Divider()

                    SettingsValueRow(icon: "bell", title: String(localized: "settings.notification.before_billing")) {
                        Toggle("", isOn: $settings.notifyBeforeBilling)
                            .labelsHidden()
                            .tint(.accentColor)
                    }
                }

                sectionTitle(String(localized: "settings.section.app"))
                SettingsCard {
                    SettingsActionRow(
                        icon: "star",
                        title: String(localized: "settings.support"),
                        action: {
                            infoAlert = InfoAlert(
                                title: String(localized: "settings.thanks"),
                                message: String(localized: "settings.support.pending")
                            )
                        }
                    )

                    Divider()

                    SettingsActionRow(
                        icon: "square.and.arrow.up",
                        title: String(localized: "settings.share"),
                        action: { isShowingAppShare = true }
                    )

                    Divider()

                    SettingsActionRow(
                        icon: "paperplane",
                        title: String(localized: "settings.feedback"),
                        action: {
                            infoAlert = InfoAlert(
                                title: String(localized: "settings.feedback.title"),
                                message: String(localized: "settings.feedback.pending")
                            )
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle(String(localized: "settings.navigation_title"))
        .sheet(isPresented: $isShowingExport) {
            NavigationStack {
                ExportView(initialScope: .both)
            }
        }
        .sheet(isPresented: $isShowingAccount) {
            NavigationStack {
                AccountView()
            }
        }
        .sheet(isPresented: $isShowingAppShare) {
            ShareSheet(items: [String(localized: "settings.share.message")])
        }
        .confirmationDialog(
            String(localized: "settings.theme.select_title"),
            isPresented: $isThemeDialogPresented,
            titleVisibility: .visible
        ) {
            ForEach(ThemeMode.allCases) { mode in
                Button(mode.label) {
                    settings.themeMode = mode
                }
            }
        }
        .alert(item: $infoAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(String(localized: "common.ok")))
            )
        }
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
    }

    private var accountDisplayName: String {
        guard let user = authStore.currentUser else {
            return String(localized: "settings.account.not_signed_in")
        }
        return user.displayName
    }
}

private struct ThemeColorSwatchSelector: View {
    @Binding var selection: ThemeColorOption

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ThemeColorOption.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        ZStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 24, height: 24)

                            Circle()
                                .strokeBorder(
                                    selection == option ? Color.primary : Color.clear,
                                    lineWidth: 2
                                )
                                .frame(width: 28, height: 28)

                            if selection == option {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(option.accessibilityLabel))
                    .accessibilityAddTraits(selection == option ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct SettingsActionRow<Trailing: View>: View {
    let icon: String
    let title: String
    let action: () -> Void
    private let trailing: Trailing

    init(
        icon: String,
        title: String,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.action = action
        self.trailing = trailing()
    }

    init(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) where Trailing == AnyView {
        self.init(icon: icon, title: title, action: action) {
            AnyView(
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            )
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 24)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()
                trailing
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsValueRow<Trailing: View>: View {
    let icon: String
    let title: String
    private let trailing: Trailing

    init(
        icon: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(.primary)

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()
            trailing
        }
        .padding(.vertical, 12)
    }
}

private struct InfoAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

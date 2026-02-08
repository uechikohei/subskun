import SwiftData
import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @Query(sort: [SortDescriptor(\Subscription.createdAt, order: .forward)])
    private var subscriptions: [Subscription]

    @Query(sort: [SortDescriptor(\BillingEvent.billedAt, order: .forward)])
    private var events: [BillingEvent]

    @State private var format: ExportFormat = .json
    @State private var scope: ExportScope
    @State private var exportedURL: URL?
    @State private var isShowingShareSheet = false
    @State private var errorMessage: String?

    init(initialScope: ExportScope) {
        _scope = State(initialValue: initialScope)
    }

    var body: some View {
        Form {
            Section(String(localized: "export.section.format")) {
                Picker(String(localized: "export.file_format"), selection: $format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "export.section.scope")) {
                Picker(String(localized: "export.target"), selection: $scope) {
                    ForEach(ExportScope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Button {
                    export()
                } label: {
                    Label(String(localized: "export.button.share"), systemImage: "square.and.arrow.up")
                }
            }

            if let exportedURL {
                Section(String(localized: "export.section.latest")) {
                    Text(exportedURL.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "export.navigation_title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.close")) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let exportedURL {
                ShareSheet(items: [exportedURL])
            }
        }
        .alert(String(localized: "export.error.alert_title"), isPresented: errorAlertBinding) {
            Button(String(localized: "common.ok"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? String(localized: "common.unknown_error"))
        }
        .onDisappear {
            removeTemporaryFileIfNeeded()
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )
    }

    private func export() {
        let service = ExportService()

        do {
            removeTemporaryFileIfNeeded()
            let fileURL = try service.writeExport(
                format: format,
                scope: scope,
                subscriptions: Array(subscriptions),
                events: Array(events),
                settings: settings.snapshot
            )
            exportedURL = fileURL
            isShowingShareSheet = true
        } catch {
            errorMessage = String(localized: "export.error.failed")
            AppLogger.error.error("export.failed")
        }
    }

    private func removeTemporaryFileIfNeeded() {
        guard let exportedURL else { return }
        try? FileManager.default.removeItem(at: exportedURL)
        self.exportedURL = nil
    }
}

import CryptoKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct SubscriptionEditView: View {
    let subscription: Subscription?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Query(sort: \Subscription.updatedAt, order: .reverse) private var existingSubscriptions: [Subscription]

    @State private var name: String
    @State private var serviceCatalogID: String
    @State private var planName: String
    @State private var amount: Int
    @State private var currency: String
    @State private var status: SubscriptionStatus
    @State private var category: String
    @State private var categoryTags: [String]
    @State private var firstBillingDate: Date
    @State private var cancellationDate: Date
    @State private var hasCancellationDate: Bool
    @State private var billingCycleType: BillingCycleType
    @State private var billingInterval: Int
    @State private var customDaysInterval: Int
    @State private var selectedBillingMonths: Set<Int>
    @State private var selectedBillingYearMonths: Set<String>
    @State private var calendarSelectionYear: Int
    @State private var historicalBillingYearMonths: Set<String>
    @State private var historicalSelectionYear: Int
    @State private var memo: String
    @State private var paymentMethod: String
    @State private var referenceURL: String
    @State private var attachmentImageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPlanField: Bool
    @State private var showPaymentMethodField: Bool
    @State private var showURLField: Bool
    @State private var showMemoField: Bool
    @State private var showImageField: Bool
    @State private var isCategoryInputPresented = false
    @State private var pendingCategoryInput = ""
    @State private var isAdvancedSettingsExpanded = false
    @State private var errorMessage: String?
    @State private var isCurrencyPickerPresented = false
    @State private var hasAppliedDefaultCurrency = false

    init(subscription: Subscription?) {
        self.subscription = subscription

        let initialFirstBillingDate = subscription?.firstBillingDate ?? Date()

        _name = State(initialValue: subscription?.name ?? "")
        let initialServiceCatalogID = subscription?.serviceCatalogID ?? ""
        _serviceCatalogID = State(initialValue: initialServiceCatalogID)
        _planName = State(initialValue: subscription?.planName ?? "")
        _amount = State(initialValue: subscription?.amount ?? 0)
        _currency = State(initialValue: subscription?.currency ?? "JPY")
        _status = State(initialValue: subscription?.status ?? .active)
        _category = State(initialValue: subscription?.category ?? "")
        _categoryTags = State(initialValue: Self.initialCategoryTags(subscription: subscription))
        _firstBillingDate = State(initialValue: initialFirstBillingDate)

        let cancellationDate = subscription?.cancellationDate ?? Date()
        _cancellationDate = State(initialValue: cancellationDate)
        _hasCancellationDate = State(initialValue: subscription?.cancellationDate != nil)

        let initialBillingCycle = subscription?.billingCycleType ?? .monthly
        let normalizedBillingCycle: BillingCycleType = initialBillingCycle == .yearly ? .yearly : .monthly
        _billingCycleType = State(initialValue: normalizedBillingCycle)
        _billingInterval = State(initialValue: 1)
        _customDaysInterval = State(initialValue: max(1, subscription?.customDaysInterval ?? 30))
        _selectedBillingMonths = State(initialValue: Self.initialSelectedMonths(subscription: subscription))
        _selectedBillingYearMonths = State(initialValue: Self.initialSelectedYearMonths(subscription: subscription))
        _calendarSelectionYear = State(initialValue: Self.initialCalendarSelectionYear(
            subscription: subscription,
            fallbackDate: initialFirstBillingDate
        ))
        _historicalBillingYearMonths = State(initialValue: Self.initialHistoricalBillingYearMonths(subscription: subscription))
        _historicalSelectionYear = State(initialValue: Self.initialHistoricalSelectionYear(
            subscription: subscription,
            fallbackDate: initialFirstBillingDate
        ))
        _memo = State(initialValue: subscription?.memo ?? "")
        _paymentMethod = State(initialValue: subscription?.paymentMethod ?? "")
        _referenceURL = State(initialValue: subscription?.referenceURL ?? "")
        _attachmentImageData = State(initialValue: subscription?.attachmentImageData)
        _selectedPhotoItem = State(initialValue: nil)
        _showPlanField = State(initialValue: !(subscription?.planName ?? "").isEmpty)
        _showPaymentMethodField = State(initialValue: !(subscription?.paymentMethod ?? "").isEmpty)
        _showURLField = State(initialValue: !(subscription?.referenceURL ?? "").isEmpty)
        _showMemoField = State(initialValue: !(subscription?.memo ?? "").isEmpty)
        _showImageField = State(initialValue: subscription?.attachmentImageData != nil)
    }

    var body: some View {
        Form {
            Section("登録内容") {
                VStack(alignment: .leading, spacing: 20) {
                    inputBlock("サービス名") {
                        TextField("例: Apple Music", text: $name)
                            .textInputAutocapitalization(.words)
                            .font(.title3.weight(.semibold))
                    }

                    inputBlock("カテゴリー") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                if categoryTags.isEmpty {
                                    Text("未設定")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(categoryTags, id: \.self) { tag in
                                                Button {
                                                    removeCategoryTag(tag)
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Text(tag)
                                                        Image(systemName: "xmark")
                                                            .font(.caption2.weight(.bold))
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule().fill(Color.blue.opacity(0.14))
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }

                                Spacer()

                                Button {
                                    pendingCategoryInput = ""
                                    isCategoryInputPresented = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.blue))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    inputBlock("支払い周期") {
                        Menu {
                            Button("1ヶ月に1回") {
                                billingCycleType = .monthly
                            }
                            Button("1年に1回") {
                                billingCycleType = .yearly
                            }
                        } label: {
                            HStack {
                                Text(billingCycleType == .yearly ? "1年に1回" : "1ヶ月に1回")
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    inputBlock(billingCycleType == .yearly ? "年額料金" : "月額料金") {
                        HStack(spacing: 12) {
                            Button {
                                isCurrencyPickerPresented = true
                            } label: {
                                Text(CurrencyCatalog.item(for: currency).code)
                                    .font(.body.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(Color.secondary.opacity(0.14))
                                    )
                            }
                            .buttonStyle(.plain)

                            TextField("0", value: $amount, format: .number)
                                .keyboardType(.numberPad)
                                .font(.title3.weight(.semibold))
                        }
                    }

                    inputBlock("初回支払い日") {
                        DatePicker("初回支払い日", selection: $firstBillingDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("追加項目")
                            .font(.subheadline.weight(.semibold))

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            extraToggleButton(
                                title: "プラン",
                                systemName: "tag",
                                isOn: showPlanField
                            ) { showPlanField.toggle() }

                            extraToggleButton(
                                title: "支払い方法",
                                systemName: "wallet.pass",
                                isOn: showPaymentMethodField
                            ) { showPaymentMethodField.toggle() }

                            extraToggleButton(
                                title: "URL",
                                systemName: "link",
                                isOn: showURLField
                            ) { showURLField.toggle() }

                            extraToggleButton(
                                title: "メモ",
                                systemName: "note.text",
                                isOn: showMemoField
                            ) { showMemoField.toggle() }

                            extraToggleButton(
                                title: "画像",
                                systemName: "photo",
                                isOn: showImageField
                            ) { showImageField.toggle() }
                        }
                    }

                    if showPlanField {
                        inputBlock("プラン名") {
                            TextField("例: Free / Plus / Pro", text: $planName)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    if showPaymentMethodField {
                        inputBlock("支払い方法") {
                            TextField("例: クレジットカード / デビットカード", text: $paymentMethod)
                        }
                    }

                    if showURLField {
                        inputBlock("URL") {
                            TextField("https://...", text: $referenceURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                        }
                    }

                    if showMemoField {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("メモ")
                                .font(.subheadline.weight(.semibold))
                            TextEditor(text: $memo)
                                .frame(minHeight: 96)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                        }
                    }

                    if showImageField {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("画像")
                                .font(.subheadline.weight(.semibold))
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("画像を選択", systemImage: "photo")
                            }
                            .buttonStyle(.bordered)

                            if let attachmentImageData,
                               let image = UIImage(data: attachmentImageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Button("画像を削除", role: .destructive) {
                                    self.attachmentImageData = nil
                                    selectedPhotoItem = nil
                                }
                                .font(.caption)
                            }
                        }
                    }

                    if normalizedCurrency != "JPY" {
                        if let exchangeRateToJPY, let convertedYen {
                            Text(String(
                                format: String(localized: "subscription.edit.jpy_reference.format"),
                                locale: Locale.autoupdatingCurrent,
                                amount.currencyString(currencyCode: normalizedCurrency),
                                convertedYen.yenString(),
                                normalizedCurrency,
                                formatExchangeRate(exchangeRateToJPY)
                            ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(localized: "subscription.edit.jpy_reference.pending"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("詳細設定 (任意)") {
                DisclosureGroup(isExpanded: $isAdvancedSettingsExpanded) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("利用状況")
                                .font(.subheadline.weight(.semibold))
                            ForEach(SubscriptionStatus.allCases) { candidate in
                                Button {
                                    status = candidate
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: status == candidate ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(status == candidate ? Color.accentColor : Color.secondary)
                                        Text(candidate.label)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if status == .cancelled {
                            DatePicker("解約日", selection: $cancellationDate, displayedComponents: .date)
                        }

                        Divider()

                        Text("過去課金履歴を編集")
                            .font(.subheadline.weight(.semibold))
                        Text("過去に支払った月をチェックすると、集計・可視化に反映されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if status == .cancelled {
                            Text("解約日の翌月以降は、非課金として × 表示されます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if status == .paused {
                            Text("一時停止中は、現在月の翌月以降を非課金として × 表示します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button {
                                historicalSelectionYear -= 1
                            } label: {
                                Image(systemName: "chevron.left")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text(String(
                                format: String(localized: "common.year_number_format"),
                                locale: Locale.autoupdatingCurrent,
                                historicalSelectionYear
                            ))
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            Button {
                                if historicalSelectionYear < currentYearMonth.year {
                                    historicalSelectionYear += 1
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(historicalSelectionYear < currentYearMonth.year ? .secondary : .tertiary)
                            }
                            .buttonStyle(.plain)
                            .disabled(historicalSelectionYear >= currentYearMonth.year)
                        }

                        LazyVGrid(columns: monthGridColumns, spacing: 8) {
                            ForEach(1 ... 12, id: \.self) { month in
                                let key = yearMonthKey(year: historicalSelectionYear, month: month)
                                let blockedByStatus = statusBlockedHistoricalYearMonths.contains(key)
                                let selectable = isPastOrCurrentMonth(year: historicalSelectionYear, month: month) && !blockedByStatus
                                Button {
                                    toggleHistoricalBillingYearMonth(key)
                                } label: {
                                    Text(String(
                                        format: String(localized: "common.month_number_short"),
                                        locale: Locale.autoupdatingCurrent,
                                        month
                                    ))
                                        .font(.subheadline.weight(.medium))
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    blockedByStatus
                                                        ? Color.red.opacity(0.14)
                                                        : historicalBillingYearMonths.contains(key)
                                                        ? Color.green.opacity(0.18)
                                                        : Color.gray.opacity(0.12)
                                                )
                                        )
                                        .foregroundStyle(
                                            selectable
                                                ? (historicalBillingYearMonths.contains(key) ? Color.green : Color.primary)
                                                : (blockedByStatus ? Color.red : Color.secondary)
                                        )
                                        .overlay(alignment: .topTrailing) {
                                            if blockedByStatus {
                                                Image(systemName: "xmark")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.red)
                                                    .padding(6)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .disabled(!selectable)
                            }
                        }

                        HStack {
                            Button("この年を全選択") {
                                selectAllHistoricalMonthsForCurrentYear()
                            }
                            .font(.caption)

                            Spacer()

                            Button("この年をクリア", role: .destructive) {
                                clearHistoricalMonthsForCurrentYear()
                            }
                            .font(.caption)
                        }

                        if !historicalBillingYearMonths.isEmpty {
                            Text(String(
                                format: String(localized: "subscription.edit.history.recorded_format"),
                                locale: Locale.autoupdatingCurrent,
                                historicalBillingYearMonthsText
                            ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                } label: {
                    Text("利用状況 / 過去課金履歴")
                }
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(
            subscription == nil
                ? String(localized: "subscription.edit.navigation_title.add")
                : String(localized: "subscription.edit.navigation_title.edit")
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    save()
                }
                .disabled(validationMessage != nil)
            }
        }
        .alert(String(localized: "common.error"), isPresented: errorAlertBinding) {
            Button(String(localized: "common.ok"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? String(localized: "subscription.edit.error.save_failed"))
        }
        .sheet(isPresented: $isCurrencyPickerPresented) {
            NavigationStack {
                CurrencyPickerView(selection: $currency)
            }
        }
        .alert(String(localized: "subscription.edit.category.add_title"), isPresented: $isCategoryInputPresented) {
            TextField(String(localized: "subscription.edit.category.name_placeholder"), text: $pendingCategoryInput)
            Button(String(localized: "common.add")) {
                addCategoryTag(pendingCategoryInput)
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                pendingCategoryInput = ""
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        attachmentImageData = data
                    }
                }
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus == .cancelled {
                hasCancellationDate = true
            } else {
                hasCancellationDate = false
            }
            pruneHistoricalMonthsByStatus()
        }
        .onChange(of: cancellationDate) { _, _ in
            if status == .cancelled {
                pruneHistoricalMonthsByStatus()
            }
        }
        .onChange(of: billingCycleType) { _, newType in
            if newType != .monthly, newType != .yearly {
                billingCycleType = .monthly
            }
        }
        .task {
            if subscription == nil, !hasAppliedDefaultCurrency {
                let preferred = settings.defaultCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if !preferred.isEmpty {
                    currency = preferred
                }
                hasAppliedDefaultCurrency = true
            }
            await exchangeRates.refreshIfNeeded()
            pruneHistoricalMonthsByStatus()
            if billingCycleType != .monthly, billingCycleType != .yearly {
                billingCycleType = .monthly
            }
        }
    }

    @ViewBuilder
    private func inputBlock<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            content()
            Divider()
        }
    }

    @ViewBuilder
    private func extraToggleButton(
        title: String,
        systemName: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isOn ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func addCategoryTag(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !categoryTags.contains(trimmed) {
            categoryTags.append(trimmed)
        }
        category = categoryTags.first ?? ""
    }

    private func removeCategoryTag(_ tag: String) {
        categoryTags.removeAll { $0 == tag }
        category = categoryTags.first ?? ""
    }

    private var normalizedCurrency: String {
        let trimmed = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = String(trimmed.prefix(3)).uppercased()
        return upper.isEmpty ? settings.defaultCurrency : upper
    }

    private var exchangeRateToJPY: Double? {
        exchangeRates.rate(from: normalizedCurrency, to: "JPY")
    }

    private var convertedYen: Int? {
        guard let rate = exchangeRateToJPY else {
            return nil
        }
        let converted = Double(amount) * rate
        return Int(converted.rounded())
    }

    private var monthGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 56), spacing: 8), count: 4)
    }

    private var currentYearMonth: (year: Int, month: Int) {
        let now = Date()
        let calendar = Calendar.current
        return (
            year: calendar.component(.year, from: now),
            month: calendar.component(.month, from: now)
        )
    }

    private var historicalBillingYearMonthsText: String {
        let labels = historicalBillingYearMonths
            .sorted(by: Self.yearMonthKeyLessThan)
            .map(formatYearMonthKey)

        if labels.count <= 6 {
            return labels.joined(separator: ", ")
        }

        let head = labels.prefix(6).joined(separator: ", ")
        let format = String(localized: "subscription.edit.history.more_format")
        return String(format: format, locale: Locale.autoupdatingCurrent, head, labels.count - 6)
    }

    private var statusBlockedHistoricalYearMonths: Set<String> {
        guard let cutoff = statusNonBillingCutoffYearMonth else {
            return []
        }

        let current = currentYearMonth
        if cutoff.year > current.year || (cutoff.year == current.year && cutoff.month > current.month) {
            return []
        }

        var result: Set<String> = []
        var year = cutoff.year
        var month = cutoff.month
        var safety = 0

        while safety < 600 {
            result.insert(yearMonthKey(year: year, month: month))
            if year == current.year && month == current.month {
                break
            }
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
            safety += 1
        }

        return result
    }

    private var statusNonBillingCutoffYearMonth: (year: Int, month: Int)? {
        switch status {
        case .active:
            return nil
        case .cancelled:
            guard hasCancellationDate else { return nil }
            let year = Calendar.current.component(.year, from: cancellationDate)
            let month = Calendar.current.component(.month, from: cancellationDate)
            return nextYearMonth(year: year, month: month)
        case .paused:
            let current = currentYearMonth
            return nextYearMonth(year: current.year, month: current.month)
        }
    }


    private var currentServiceIdentityKey: String? {
        serviceIdentityKey(catalogID: "", serviceName: name)
    }

    private var hasDuplicateServiceAndPlan: Bool {
        guard let serviceKey = currentServiceIdentityKey else {
            return false
        }
        let currentPlanKey = normalizedPlanKey(planName)

        return existingSubscriptions.contains { existing in
            if let subscription, existing.id == subscription.id {
                return false
            }
            guard serviceIdentityKey(catalogID: existing.serviceCatalogID, serviceName: existing.name) == serviceKey else {
                return false
            }
            return normalizedPlanKey(existing.planName) == currentPlanKey
        }
    }

    private var resolvedBillingInterval: Int {
        switch billingCycleType {
        case .monthly, .yearly:
            return 1
        case .selectedMonths, .calendarMonths, .oneTime, .customDays:
            return 1
        }
    }

    private var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "subscription.edit.validation.service_required")
        }
        if amount < 0 {
            return String(localized: "subscription.edit.validation.amount_min")
        }
        if amount > 1_000_000 {
            return String(localized: "subscription.edit.validation.amount_max")
        }
        if normalizedCurrency.isEmpty {
            return String(localized: "subscription.edit.validation.currency_required")
        }
        if billingCycleType == .selectedMonths && selectedBillingMonths.isEmpty {
            return String(localized: "subscription.edit.validation.selected_months_required")
        }
        if billingCycleType == .calendarMonths && selectedBillingYearMonths.isEmpty {
            return String(localized: "subscription.edit.validation.calendar_months_required")
        }
        if historicalBillingYearMonths.contains(where: { !isPastOrCurrentMonth(key: $0) }) {
            return String(localized: "subscription.edit.validation.no_future_history")
        }
        if status == .cancelled && !hasCancellationDate {
            return String(localized: "subscription.edit.validation.cancellation_date_required")
        }
        if hasDuplicateServiceAndPlan {
            return String(localized: "subscription.edit.validation.duplicate_service_plan")
        }
        return nil
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

    private func pruneHistoricalMonthsByStatus() {
        let blocked = statusBlockedHistoricalYearMonths
        guard !blocked.isEmpty else {
            return
        }
        historicalBillingYearMonths.subtract(blocked)
    }

    private func toggleHistoricalBillingYearMonth(_ key: String) {
        guard let parsed = Self.parseYearMonthKey(key),
              isPastOrCurrentMonth(year: parsed.year, month: parsed.month),
              !statusBlockedHistoricalYearMonths.contains(key) else {
            return
        }

        if historicalBillingYearMonths.contains(key) {
            historicalBillingYearMonths.remove(key)
        } else {
            historicalBillingYearMonths.insert(key)
        }
    }

    private func selectAllHistoricalMonthsForCurrentYear() {
        for month in 1 ... 12 where isPastOrCurrentMonth(year: historicalSelectionYear, month: month) {
            let key = yearMonthKey(year: historicalSelectionYear, month: month)
            guard !statusBlockedHistoricalYearMonths.contains(key) else {
                continue
            }
            historicalBillingYearMonths.insert(key)
        }
    }

    private func clearHistoricalMonthsForCurrentYear() {
        for month in 1 ... 12 {
            historicalBillingYearMonths.remove(yearMonthKey(year: historicalSelectionYear, month: month))
        }
    }

    private func formatYearMonthKey(_ key: String) -> String {
        guard let parsed = Self.parseYearMonthKey(key) else {
            return key
        }
        let format = String(localized: "common.year_month_format")
        return String(format: format, locale: Locale.autoupdatingCurrent, parsed.year, parsed.month)
    }

    private func isPastOrCurrentMonth(key: String) -> Bool {
        guard let parsed = Self.parseYearMonthKey(key) else {
            return false
        }
        return isPastOrCurrentMonth(year: parsed.year, month: parsed.month)
    }

    private func isPastOrCurrentMonth(year: Int, month: Int) -> Bool {
        let current = currentYearMonth
        if year < current.year {
            return true
        }
        if year > current.year {
            return false
        }
        return month <= current.month
    }

    private func yearMonthKey(year: Int, month: Int) -> String {
        Self.makeYearMonthKey(year: year, month: month)
    }

    private func nextYearMonth(year: Int, month: Int) -> (year: Int, month: Int) {
        if month >= 12 {
            return (year + 1, 1)
        }
        return (year, month + 1)
    }

    private func formatExchangeRate(_ rate: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: rate)) ?? String(format: "%.4f", rate)
    }

    private func normalizedComparisonKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }
        let folded = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let collapsed = folded
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return collapsed
    }

    private func normalizedPlanKey(_ value: String) -> String {
        normalizedComparisonKey(value)
    }

    private func serviceIdentityKey(catalogID: String, serviceName: String) -> String? {
        let normalizedName = normalizedComparisonKey(serviceName)
        guard !normalizedName.isEmpty else {
            return nil
        }
        return "name:\(normalizedName)"
    }

    private func save() {
        guard validationMessage == nil else { return }

        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPlanName = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedServiceCatalogID = serviceCatalogID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategoryTags = categoryTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let primaryCategory = normalizedCategoryTags.first ?? category.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let blockedHistoricalMonths = statusBlockedHistoricalYearMonths
        let normalizedHistoricalYearMonths = historicalBillingYearMonths
            .filter { isPastOrCurrentMonth(key: $0) && !blockedHistoricalMonths.contains($0) }
            .sorted(by: Self.yearMonthKeyLessThan)

        let target: Subscription
        if let subscription {
            target = subscription
        } else {
            let created = Subscription(
                name: sanitizedName,
                serviceCatalogID: resolvedServiceCatalogID,
                planName: sanitizedPlanName,
                amount: amount,
                currency: normalizedCurrency,
                status: status,
                category: primaryCategory,
                categoryTags: normalizedCategoryTags,
                firstBillingDate: firstBillingDate,
                cancellationDate: status == .cancelled ? cancellationDate : nil,
                billingCycleType: billingCycleType,
                billingInterval: resolvedBillingInterval,
                customDaysInterval: billingCycleType == .customDays ? max(1, customDaysInterval) : nil,
                selectedMonths: billingCycleType == .selectedMonths ? selectedBillingMonths.sorted() : [],
                selectedYearMonths: billingCycleType == .calendarMonths ? selectedBillingYearMonths.sorted(by: Self.yearMonthKeyLessThan) : [],
                historicalBilledYearMonths: normalizedHistoricalYearMonths,
                memo: memo,
                paymentMethod: paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines),
                referenceURL: referenceURL.trimmingCharacters(in: .whitespacesAndNewlines),
                attachmentImageData: attachmentImageData,
                createdAt: now,
                updatedAt: now
            )
            target = created
            modelContext.insert(created)
        }

        let previousHistoricalYearMonths = Set(target.historicalBilledYearMonths)

        target.name = sanitizedName
        target.serviceCatalogID = resolvedServiceCatalogID
        target.planName = sanitizedPlanName
        target.amount = amount
        target.currency = normalizedCurrency
        target.status = status
        target.category = primaryCategory
        target.categoryTags = normalizedCategoryTags
        target.firstBillingDate = firstBillingDate
        target.cancellationDate = status == .cancelled ? cancellationDate : nil
        target.billingCycleType = billingCycleType
        target.billingInterval = resolvedBillingInterval
        target.customDaysInterval = billingCycleType == .customDays ? max(1, customDaysInterval) : nil
        target.selectedMonths = billingCycleType == .selectedMonths ? selectedBillingMonths.sorted() : []
        target.selectedYearMonths = billingCycleType == .calendarMonths ? selectedBillingYearMonths.sorted(by: Self.yearMonthKeyLessThan) : []
        target.historicalBilledYearMonths = normalizedHistoricalYearMonths
        target.memo = memo
        target.paymentMethod = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        target.referenceURL = referenceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        target.attachmentImageData = attachmentImageData
        target.updatedAt = now

        syncHistoricalBillingEvents(
            for: target,
            previousYearMonths: previousHistoricalYearMonths,
            currentYearMonths: Set(normalizedHistoricalYearMonths),
            now: now
        )

        let projectionService = BillingProjectionService()
        projectionService.regenerate(for: target, in: modelContext, settings: settings.snapshot, now: now)

        do {
            try modelContext.save()
            AppLogger.subscription.info("subscription.save success")
            dismiss()
        } catch {
            errorMessage = String(localized: "subscription.edit.error.save_failed")
            AppLogger.error.error("subscription.save failed")
        }
    }

    private func syncHistoricalBillingEvents(
        for subscription: Subscription,
        previousYearMonths: Set<String>,
        currentYearMonths: Set<String>,
        now: Date
    ) {
        let removed = previousYearMonths.subtracting(currentYearMonths)
        for key in removed {
            let eventID = historicalEventID(for: key, subscriptionID: subscription.id)
            if let event = subscription.events.first(where: { $0.id == eventID }) {
                modelContext.delete(event)
            }
        }

        let anchorDay = Calendar.current.component(.day, from: subscription.firstBillingDate)
        let sortedCurrent = currentYearMonths.sorted(by: Self.yearMonthKeyLessThan)
        for key in sortedCurrent {
            guard let parsed = Self.parseYearMonthKey(key),
                  let billedAt = clampedDate(year: parsed.year, month: parsed.month, day: anchorDay) else {
                continue
            }

            let eventID = historicalEventID(for: key, subscriptionID: subscription.id)
            if let existing = subscription.events.first(where: { $0.id == eventID }) {
                existing.billedAt = billedAt
                existing.eventType = .confirmed
                if !existing.isAmountOverridden {
                    existing.amount = subscription.amount
                    existing.currency = subscription.currency
                }
                existing.updatedAt = now
                continue
            }

            let hasOtherConfirmedInSameMonth = subscription.events.contains { event in
                guard event.eventType == .confirmed else { return false }
                let components = Calendar.current.dateComponents([.year, .month], from: event.billedAt)
                return components.year == parsed.year && components.month == parsed.month
            }
            if hasOtherConfirmedInSameMonth {
                continue
            }

            let event = BillingEvent(
                id: eventID,
                subscription: subscription,
                billedAt: billedAt,
                amount: subscription.amount,
                currency: subscription.currency,
                eventType: .confirmed,
                isAmountOverridden: false,
                memo: "",
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(event)
        }
    }

    private func historicalEventID(for yearMonthKey: String, subscriptionID: UUID) -> UUID {
        let seed = "historical:\(subscriptionID.uuidString.lowercased()):\(yearMonthKey)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(digest.prefix(16))
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }

    private func clampedDate(year: Int, month: Int, day: Int) -> Date? {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }
        let clampedDay = min(day, dayRange.count)
        return calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
    }

    private static func initialCategoryTags(subscription: Subscription?) -> [String] {
        guard let subscription else { return [] }
        if !subscription.categoryTags.isEmpty {
            return subscription.categoryTags
        }
        let fallback = subscription.category.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? [] : [fallback]
    }

    private static func initialSelectedMonths(subscription: Subscription?) -> Set<Int> {
        if let subscription, !subscription.selectedMonths.isEmpty {
            return Set(subscription.selectedMonths)
        }

        let date = subscription?.firstBillingDate ?? Date()
        let month = Calendar.current.component(.month, from: date)
        return [month]
    }

    private static func initialSelectedYearMonths(subscription: Subscription?) -> Set<String> {
        if let subscription, !subscription.selectedYearMonths.isEmpty {
            return Set(subscription.selectedYearMonths)
        }

        let date = subscription?.firstBillingDate ?? Date()
        let year = Calendar.current.component(.year, from: date)
        let month = Calendar.current.component(.month, from: date)
        return [makeYearMonthKey(year: year, month: month)]
    }

    private static func initialCalendarSelectionYear(subscription: Subscription?, fallbackDate: Date) -> Int {
        if let subscription {
            let years = subscription.selectedYearMonths
                .compactMap { parseYearMonthKey($0)?.year }
                .sorted()
            if let first = years.first {
                return first
            }
            return Calendar.current.component(.year, from: subscription.firstBillingDate)
        }
        return Calendar.current.component(.year, from: fallbackDate)
    }

    private static func initialHistoricalBillingYearMonths(subscription: Subscription?) -> Set<String> {
        guard let subscription else {
            return []
        }

        var result = Set(subscription.historicalBilledYearMonths)
        let calendar = Calendar.current
        let current = Date()
        let currentComponents = calendar.dateComponents([.year, .month], from: current)

        for event in subscription.events where event.eventType == .confirmed {
            let components = calendar.dateComponents([.year, .month], from: event.billedAt)
            guard let year = components.year, let month = components.month else {
                continue
            }

            guard let currentYear = currentComponents.year, let currentMonth = currentComponents.month else {
                continue
            }

            if year < currentYear || (year == currentYear && month <= currentMonth) {
                result.insert(makeYearMonthKey(year: year, month: month))
            }
        }

        return result
    }

    private static func initialHistoricalSelectionYear(subscription: Subscription?, fallbackDate: Date) -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        if let subscription {
            let years = initialHistoricalBillingYearMonths(subscription: subscription)
                .compactMap { parseYearMonthKey($0)?.year }
                .sorted()
            if let latest = years.last {
                return min(latest, currentYear)
            }
            let subscriptionYear = Calendar.current.component(.year, from: subscription.firstBillingDate)
            return min(subscriptionYear, currentYear)
        }
        return min(Calendar.current.component(.year, from: fallbackDate), currentYear)
    }

    private static func parseYearMonthKey(_ raw: String) -> (year: Int, month: Int)? {
        let components = raw.split(separator: "-", omittingEmptySubsequences: true)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              (1 ... 12).contains(month),
              (1900 ... 3000).contains(year) else {
            return nil
        }
        return (year, month)
    }

    private static func makeYearMonthKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    private static func yearMonthKeyLessThan(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = parseYearMonthKey(lhs), let right = parseYearMonthKey(rhs) else {
            return lhs < rhs
        }
        if left.year != right.year {
            return left.year < right.year
        }
        return left.month < right.month
    }
}

private struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String

    @State private var searchText = ""

    private var filteredItems: [CurrencyItem] {
        if searchText.isEmpty {
            return CurrencyCatalog.all
        }

        let lowered = searchText.lowercased()
        return CurrencyCatalog.all.filter { item in
            item.code.lowercased().contains(lowered)
                || item.localizedName.lowercased().contains(lowered)
        }
    }

    var body: some View {
        List {
            Section(String(localized: "currency_picker.section.preferred")) {
                ForEach(CurrencyCatalog.preferredCodes, id: \.self) { code in
                    row(for: CurrencyCatalog.item(for: code))
                }
            }

            Section(String(localized: "currency_picker.section.all")) {
                ForEach(filteredItems) { item in
                    row(for: item)
                }
            }
        }
        .navigationTitle(String(localized: "currency_picker.navigation_title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: String(localized: "currency_picker.search_prompt"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.close")) {
                    dismiss()
                }
            }
        }
    }

    private func row(for item: CurrencyItem) -> some View {
        Button {
            selection = item.code
            dismiss()
        } label: {
            HStack {
                Text(item.label)
                Spacer()
                if selection.uppercased() == item.code {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

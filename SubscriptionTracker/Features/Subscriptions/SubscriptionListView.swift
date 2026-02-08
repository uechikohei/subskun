import SwiftData
import SwiftUI

struct SubscriptionListView: View {
    private static let allCategoryToken = "__all__"

    private enum ActiveSheet: String, Identifiable {
        case create

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var exchangeRates: ExchangeRateStore

    @Query(sort: [SortDescriptor(\Subscription.updatedAt, order: .reverse)])
    private var subscriptions: [Subscription]

    @State private var searchText = ""
    @State private var statusFilter: SubscriptionStatusFilter = .all
    @State private var categoryFilter = Self.allCategoryToken
    @State private var activeSheet: ActiveSheet?
    @State private var deleteTarget: Subscription?
    @State private var errorMessage: String?
    @State private var hasAppeared = false

    private let billingEngine = BillingEngine()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if filteredSubscriptions.isEmpty {
                    ContentUnavailableView(
                        String(localized: "subscription.list.empty.title"),
                        systemImage: "tray",
                        description: Text(String(localized: "subscription.list.empty.description"))
                    )
                } else {
                    List {
                        ForEach(filteredSubscriptions) { subscription in
                            NavigationLink {
                                SubscriptionDetailView(subscription: subscription)
                            } label: {
                                SubscriptionRowView(
                                    subscription: subscription,
                                    nextBillingDate: billingEngine.nextBillingDate(for: subscription),
                                    convertedYenAmount: exchangeRates.convertToJPY(
                                        amount: subscription.amount,
                                        currency: subscription.currency
                                    )
                                )
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTarget = subscription
                                } label: {
                                    Label(String(localized: "common.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }

            Button {
                activeSheet = .create
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 4)
                    )
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityLabel(String(localized: "subscription.list.add"))
        }
        .navigationTitle(String(localized: "subscription.list.navigation_title"))
        .searchable(text: $searchText, prompt: String(localized: "subscription.list.search_prompt"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker(String(localized: "subscription.list.filter.status"), selection: $statusFilter) {
                        ForEach(SubscriptionStatusFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }

                    Picker(String(localized: "subscription.list.filter.category"), selection: $categoryFilter) {
                        Text(String(localized: "common.all")).tag(Self.allCategoryToken)
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                } label: {
                    Label(String(localized: "subscription.list.filter"), systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:
                NavigationStack {
                    SubscriptionEditView(subscription: nil)
                }
            }
        }
        .alert(String(localized: "subscription.list.delete.alert.title"), isPresented: deleteAlertBinding) {
            Button(String(localized: "common.delete"), role: .destructive) {
                if let deleteTarget {
                    deleteSubscription(deleteTarget)
                }
                deleteTarget = nil
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text(String(localized: "subscription.list.delete.alert.message"))
        }
        .alert(String(localized: "common.error"), isPresented: errorAlertBinding) {
            Button(String(localized: "common.ok"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? String(localized: "common.unknown_error"))
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                regenerateProjectedEvents()
                Task {
                    await exchangeRates.refreshIfNeeded()
                }
            }
        }
        .onChange(of: settings.generationSignature) { _, _ in
            regenerateProjectedEvents()
        }
    }

    private var filteredSubscriptions: [Subscription] {
        subscriptions
            .filter { statusFilter.matches(status: $0.status) }
            .filter {
                if categoryFilter == Self.allCategoryToken {
                    return true
                }
                return $0.category == categoryFilter
            }
            .filter {
                if searchText.isEmpty { return true }
                return $0.name.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var availableCategories: [String] {
        let categories = subscriptions
            .map(\.category)
            .filter { !$0.isEmpty }
        return Array(Set(categories)).sorted()
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { newValue in
                if !newValue {
                    deleteTarget = nil
                }
            }
        )
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

    private func deleteSubscription(_ subscription: Subscription) {
        modelContext.delete(subscription)
        do {
            try modelContext.save()
            AppLogger.subscription.info("subscription.delete success")
        } catch {
            errorMessage = String(localized: "subscription.list.error.delete_failed")
            AppLogger.error.error("subscription.delete failed")
        }
    }

    private func regenerateProjectedEvents() {
        let projectionService = BillingProjectionService()
        projectionService.regenerateAll(
            subscriptions: Array(subscriptions),
            in: modelContext,
            settings: settings.snapshot
        )

        do {
            try modelContext.save()
        } catch {
            errorMessage = String(localized: "subscription.list.error.regenerate_failed")
            AppLogger.error.error("projection.regenerate_all failed")
        }
    }
}

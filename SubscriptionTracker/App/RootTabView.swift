import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                SummaryView()
            }
            .tabItem {
                Label(String(localized: "tab.ratio"), systemImage: "chart.pie")
            }

            NavigationStack {
                PaymentHistoryView()
            }
            .tabItem {
                Label(String(localized: "tab.history"), systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                SubscriptionListView()
            }
            .tabItem {
                Label(String(localized: "tab.list"), systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(String(localized: "tab.settings"), systemImage: "gearshape")
            }
        }
    }
}

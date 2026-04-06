import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedFilter: OrdersFilter = .inProgress
    @State private var expandedOrderIDs: Set<String> = []

    private var filteredOrders: [Order] {
        switch selectedFilter {
        case .inProgress:
            return appState.activeOrders
        case .settled:
            return appState.settledOrders
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OrderFilterChips(selectedFilter: $selectedFilter)
                    .padding(.horizontal)
                    .padding(.top, 12)

                if filteredOrders.isEmpty {
                    ContentUnavailableView(
                        selectedFilter.emptyTitle,
                        systemImage: selectedFilter.systemImage,
                        description: Text(selectedFilter.emptyMessage)
                    )
                    .padding(.top, 72)
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(filteredOrders) { order in
                            OrderHistoryCard(
                                order: order,
                                showsTracking: selectedFilter == .inProgress,
                                isExpanded: expandedOrderIDs.contains(order.id),
                                onToggleExpansion: { toggleExpansion(for: order.id) },
                                onOpenDetails: {
                                appState.goToOrderDetails(order.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("Orders")
        .background(Color(.systemGroupedBackground))
    }
}

extension OrdersView {
    private func toggleExpansion(for orderID: String) {
        if expandedOrderIDs.contains(orderID) {
            expandedOrderIDs.remove(orderID)
        } else {
            expandedOrderIDs.insert(orderID)
        }
    }
}
#Preview {
    NavigationStack {
        OrdersView()
            .environmentObject(AppState.preview)
    }
}

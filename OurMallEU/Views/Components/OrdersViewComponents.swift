import SwiftUI

enum OrdersFilter: String, CaseIterable, Identifiable {
    case inProgress = "In progress"
    case settled = "Settled"

    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .inProgress:
            return "shippingbox"
        case .settled:
            return "checkmark.circle"
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .inProgress:
            return "No in-progress orders"
        case .settled:
            return "No settled orders"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .inProgress:
            return "Paid orders that are still moving through fulfillment will appear here."
        case .settled:
            return "Orders where every item is delivered or cancelled will appear here."
        }
    }
}

struct OrderFilterChips: View {
    @Binding var selectedFilter: OrdersFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(OrdersFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                selectedFilter == filter ? Color.blue : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct OrderHistoryCard: View {
    let order: Order
    let showsTracking: Bool
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onOpenDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onToggleExpansion) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Order \(order.id.prefix(8))")
                            .font(.headline)
                        Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(order.displayStatusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(orderBadgeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            orderBadgeColor.opacity(0.12),
                            in: Capsule()
                        )

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(order.vendorGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.vendor.name)
                            .font(.subheadline.weight(.semibold))

                        ForEach(group.items) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.productName)
                                    Text(item.selectedOptions.keys.sorted().map { "\($0.capitalized): \(item.selectedOptions[$0] ?? "")" }.joined(separator: " • "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Qty \(item.quantity)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text((item.unitPrice * Decimal(item.quantity)).currencyText)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.status.title)
                                        .font(.caption)
                                        .foregroundStyle(item.status == .cancelled ? .red : .secondary)
                                }
                            }

                            if showsTracking {
                                ItemTrackingProgressView(status: item.status)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button("View order details", action: onOpenDetails)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
    
    private var orderBadgeColor: Color {
        if order.isCancelled {
            return .red
        }
        
        if order.isSettled {
            return .green
        }
        
        return .blue
    }
}

struct ItemTrackingProgressView: View {
    let status: ItemStatus
    private let steps: [ItemStatus] = [.pending, .confirmed, .shipped, .delivered]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Circle()
                        .fill(circleColor(for: step))
                        .frame(width: 10, height: 10)
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(connectorColor(for: index))
                            .frame(maxWidth: .infinity)
                            .frame(height: 3)
                            .clipShape(Capsule())
                    }
                }
            }
            
            HStack(alignment: .top) {
                ForEach(steps, id: \.self) { step in
                    Text(step.title)
                        .font(.caption2.weight(step == status ? .semibold : .regular))
                        .foregroundStyle(labelColor(for: step))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func circleColor(for step: ItemStatus) -> Color {
        if status == .cancelled {
            return Color.gray.opacity(0.35)
        }
        
        if stepIndex(step) <= stepIndex(status) {
            return step == .delivered ? .green : .blue
        }
        
        return Color.gray.opacity(0.25)
    }
    
    private func connectorColor(for index: Int) -> Color {
        if status == .cancelled {
            return Color.gray.opacity(0.35)
        }
        
        return index < stepIndex(status) ? .blue : Color.gray.opacity(0.22)
    }
    
    private func labelColor(for step: ItemStatus) -> Color {
        if status == .cancelled {
            return .secondary
        }
        
        return step == status ? .primary : .secondary
    }
    
    private func stepIndex(_ step: ItemStatus) -> Int {
        switch step {
        case .pending:
            return 0
        case .confirmed:
            return 1
        case .shipped:
            return 2
        case .delivered:
            return 3
        case .cancelled:
            return 3
        }
    }
}

import Foundation

enum CancellationTarget: Identifiable {
    case item(OrderItem)
    case vendor(VendorOrderGroup)
    case fullOrder

    var id: String {
        switch self {
        case .item(let item):
            return "item-\(item.id)"
        case .vendor(let group):
            return "vendor-\(group.id)"
        case .fullOrder:
            return "full-order"
        }
    }

    var title: String {
        switch self {
        case .item:
            return "Cancel item?"
        case .vendor:
            return "Cancel vendor order?"
        case .fullOrder:
            return "Cancel entire order?"
        }
    }

    var message: String {
        switch self {
        case .item(let item):
            return "This will cancel \(item.productName) only."
        case .vendor(let group):
            return "This will cancel all items from \(group.vendor.name)."
        case .fullOrder:
            return "This will cancel every vendor and item in this order."
        }
    }

    func refundAmount(in order: Order) -> Decimal {
        switch self {
        case .item(let item):
            guard item.status != .cancelled else { return 0 }
            return (item.unitPrice * Decimal(item.quantity)).rounded()
        case .vendor(let group):
            return group.items
                .filter { $0.status != .cancelled }
                .reduce(0) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
                .rounded()
        case .fullOrder:
            return order.vendorGroups
                .flatMap(\.items)
                .filter { $0.status != .cancelled }
                .reduce(0) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
                .rounded()
        }
    }
}

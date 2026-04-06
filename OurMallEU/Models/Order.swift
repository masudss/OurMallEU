import Foundation

enum OrderStatus: String, Codable, CaseIterable, Hashable {
    case inProgress = "in_progress"
    case settled
    
    var title: String {
        switch self {
        case .inProgress:
            return "In progress"
        case .settled:
            return "Settled"
        }
    }
}

enum ItemStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case confirmed
    case shipped
    case delivered
    case cancelled
    
    var title: String {
        rawValue.capitalized
    }
    
    var isSettled: Bool {
        self == .delivered || self == .cancelled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        guard let value = ItemStatus(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported item status: \(rawValue)")
        }
        self = value
    }
}

struct OrderItem: Codable, Hashable, Identifiable {
    let id: String
    let productID: String
    let productName: String
    let quantity: Int
    let unitPrice: Decimal
    let selectedOptions: [String: String]
    var status: ItemStatus
}

struct VendorOrderGroup: Codable, Hashable, Identifiable {
    let vendor: Vendor
    var items: [OrderItem]
    var status: OrderStatus

    var id: String {
        vendor.id
    }
}

struct Order: Codable, Hashable, Identifiable {
    let id: String
    var status: OrderStatus
    var vendorGroups: [VendorOrderGroup]
    let createdAt: Date
}

extension VendorOrderGroup {
    var isSettled: Bool {
        status == .settled
    }
    
    var isCancelled: Bool {
        !items.isEmpty && items.allSatisfy { $0.status == .cancelled }
    }
    
    var isDelivered: Bool {
        !items.isEmpty && items.allSatisfy { $0.status == .delivered }
    }
    
    var displayStatusTitle: String {
        if isCancelled {
            return "Cancelled"
        }
        
        if isDelivered {
            return "Delivered"
        }
        
        return status.title
    }
}

extension Order {
    var isSettled: Bool {
        status == .settled
    }
    
    var allItems: [OrderItem] {
        vendorGroups.flatMap(\.items)
    }
    
    var isCancelled: Bool {
        !allItems.isEmpty && allItems.allSatisfy { $0.status == .cancelled }
    }
    
    var isDelivered: Bool {
        !allItems.isEmpty && allItems.allSatisfy { $0.status == .delivered }
    }
    
    var displayStatusTitle: String {
        if isCancelled {
            return "Cancelled"
        }
        
        if isDelivered {
            return "Delivered"
        }
        
        return status.title
    }
}

struct PaymentRequest: Encodable, Hashable {
    let vendors: [String: [CheckoutProductPayload]]
    let summary: PaymentSummaryPayload
}

struct CheckoutProductPayload: Encodable, Hashable {
    let productId: String
    let quantity: Int
    let unitPrice: Decimal
    let selectedOptions: [String: String]
}

struct PaymentSummaryPayload: Encodable, Hashable {
    let subtotal: Decimal
    let discount: Decimal
    let vat: Decimal
    let grandTotal: Decimal
}

struct PaymentResponse: Decodable, Hashable {
    let orderId: String
    let paymentReference: String
    let status: String
}

extension PaymentRequest {
    func asDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }
}

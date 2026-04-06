import Foundation
@testable import OurMallEU

@MainActor
final class MockCommerceService: CommerceServicing {
    var pages: [Int: ProductPage] = [:]
    var fetchError: Error?
    var submitError: Error?
    var submittedPayloads: [[String: Any]] = []

    func fetchProducts(page: Int, pageSize: Int) async throws -> ProductPage {
        if let fetchError {
            throw fetchError
        }

        return pages[page] ?? ProductPage(items: [], page: page, hasMorePages: false)
    }

    func submitPayment(payload: [String: Any]) async throws -> PaymentResponse {
        if let submitError {
            throw submitError
        }

        submittedPayloads.append(payload)
        return PaymentResponse(
            orderId: "order-test-1001",
            paymentReference: "PAY-TEST-1001",
            status: ItemStatus.pending.rawValue
        )
    }
}

enum TestFactory {
    static func vendor(id: String = "vendor-1", name: String = "Vendor One") -> Vendor {
        Vendor(id: id, name: name)
    }

    static func product(
        id: String = "product-1",
        name: String = "Product",
        category: [String] = ["general"],
        vendor: Vendor = vendor(),
        price: Decimal = 100,
        discountPercentage: Decimal = 0,
        quantityRemaining: Int = 5,
        options: [ProductOption] = [],
        status: ItemStatus = .pending
    ) -> Product {
        Product(
            id: id,
            name: name,
            category: category,
            imageURL: nil,
            vendor: vendor,
            price: price,
            discountPercentage: discountPercentage,
            offerEndsAt: nil,
            quantityRemaining: quantityRemaining,
            summary: "Summary",
            options: options,
            status: status
        )
    }

    static func order(
        id: String = "order-1",
        itemStatuses: [ItemStatus],
        orderStatus: OrderStatus
    ) -> Order {
        Order(
            id: id,
            status: orderStatus,
            vendorGroups: [vendorGroup(itemStatuses: itemStatuses, status: orderStatus)],
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    static func order(
        id: String,
        groups: [VendorOrderGroup],
        orderStatus: OrderStatus
    ) -> Order {
        Order(
            id: id,
            status: orderStatus,
            vendorGroups: groups,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    static func vendorGroup(
        vendor: Vendor = vendor(),
        itemStatuses: [ItemStatus],
        status: OrderStatus
    ) -> VendorOrderGroup {
        VendorOrderGroup(
            vendor: vendor,
            items: itemStatuses.enumerated().map { index, itemStatus in
                OrderItem(
                    id: "item-\(index)",
                    productID: "product-\(index)",
                    productName: "Product \(index)",
                    quantity: 1,
                    unitPrice: Decimal(50 + (index * 10)),
                    selectedOptions: [:],
                    status: itemStatus
                )
            },
            status: status
        )
    }
}

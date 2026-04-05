import Foundation
import Testing
@testable import OurMallEU

@Suite("Product Models")
struct ProductModelTests {
    @Test("Default selection uses the first available option values")
    func defaultSelectionUsesFirstAvailableOptionValues() {
        let product = TestFactory.product(
            options: [
                ProductOption(name: "size", values: ["S", "M", "L"]),
                ProductOption(name: "color", values: ["Red", "Black"])
            ]
        )

        #expect(product.defaultSelection.quantity == 1)
        #expect(product.defaultSelection.selectedOptions["size"] == "S")
        #expect(product.defaultSelection.selectedOptions["color"] == "Red")
    }

    @Test("Discounted price and stock are derived from source values")
    func discountedPriceAndStockAreDerivedFromSourceValues() {
        let product = TestFactory.product(price: 240, discountPercentage: 10, quantityRemaining: 0)

        #expect(product.discountedPrice == Decimal(216))
        #expect(product.inStock == false)
    }

    @Test("DTO mapping applies option sorting and pending fallback status")
    func dtoMappingAppliesOptionSortingAndPendingFallbackStatus() {
        let dto = ProductDTO(
            id: "dto-1",
            name: "Mapped Product",
            imageURL: nil,
            vendor: TestFactory.vendor(),
            price: 90,
            discountPercentage: 5,
            offerEndsAt: nil,
            quantityRemaining: 7,
            summary: nil,
            options: ["color": ["Black"], "size": ["S", "M"]],
            status: nil
        )

        let product = dto.toProduct()

        #expect(product.status == .pending)
        #expect(product.summary.contains("premium multi-vendor"))
        #expect(product.options.map(\.name) == ["color", "size"])
    }
}


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

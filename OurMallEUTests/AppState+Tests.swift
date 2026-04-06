import Foundation
import Testing
@testable import OurMallEU

@Suite("AppState")
@MainActor
struct AppStateTests {
    @Test("Refresh products loads the first page")
    func refreshProductsLoadsTheFirstPage() async {
        let service = MockCommerceService()
        service.pages = [
            1: ProductPage(items: [TestFactory.product(id: "p1"), TestFactory.product(id: "p2")], page: 1, hasMorePages: true)
        ]
        let state = AppState(service: service)

        await state.refreshProducts()

        #expect(state.products.map(\.id) == ["p1", "p2"])
        #expect(state.productErrorMessage == nil)
    }

    @Test("Refresh products surfaces offline fallback message")
    func refreshProductsSurfacesOfflineFallbackMessage() async {
        let service = MockCommerceService()
        service.fetchError = APIError.transport("offline")
        let state = AppState(service: service)

        await state.refreshProducts()

        #expect(state.products.isEmpty == false)
        #expect(state.productErrorMessage == "Backend unavailable. Showing offline catalog.")
    }
    
    @Test("Refresh products falls back to local sample products when backend is unavailable")
    func refreshProductsFallsBackToLocalSampleProductsWhenBackendIsUnavailable() async {
        let service = MockCommerceService()
        service.fetchError = APIError.transport("offline")
        let state = AppState(service: service)
        
        await state.refreshProducts()
        
        #expect(state.products.isEmpty == false)
        #expect(state.products.map(\.id) == Array(Product.sampleProducts.prefix(6)).map(\.id))
        #expect(state.productErrorMessage == "Backend unavailable. Showing offline catalog.")
    }

    @Test("Next page loads when current product is near the end")
    func nextPageLoadsWhenCurrentProductIsNearTheEnd() async throws {
        let service = MockCommerceService()
        service.pages = [
            1: ProductPage(items: [
                TestFactory.product(id: "p1"),
                TestFactory.product(id: "p2"),
                TestFactory.product(id: "p3"),
                TestFactory.product(id: "p4"),
                TestFactory.product(id: "p5"),
                TestFactory.product(id: "p6")
            ], page: 1, hasMorePages: true),
            2: ProductPage(items: [TestFactory.product(id: "p7")], page: 2, hasMorePages: false)
        ]
        let state = AppState(service: service)
        await state.refreshProducts()

        state.loadNextPageIfNeeded(currentProduct: try #require(state.products.last))
        try await Task.sleep(for: .milliseconds(100))

        #expect(state.products.map(\.id) == ["p1", "p2", "p3", "p4", "p5", "p6", "p7"])
    }
    
    @Test("Fallback products also paginate when backend is unavailable")
    func fallbackProductsAlsoPaginateWhenBackendIsUnavailable() async throws {
        let service = MockCommerceService()
        service.fetchError = APIError.transport("offline")
        let state = AppState(service: service)
        
        await state.refreshProducts()
        state.loadNextPageIfNeeded(currentProduct: try #require(state.products.last))
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(state.products.map(\.id) == Array(Product.sampleProducts.prefix(12)).map(\.id))
    }

    @Test("Add to cart uses default options and merges repeated selections")
    func addToCartUsesDefaultOptionsAndMergesRepeatedSelections() {
        let state = AppState(service: MockCommerceService())
        let product = TestFactory.product(
            quantityRemaining: 3,
            options: [
                ProductOption(name: "size", values: ["S", "M"]),
                ProductOption(name: "color", values: ["Red", "Blue"])
            ]
        )

        state.addToCart(product)
        state.addToCart(product)

        let item = state.cartItems.values.first
        #expect(state.cartItems.count == 1)
        #expect(state.cartCount == 2)
        #expect(item?.selectedOptions["size"] == "S")
        #expect(item?.selectedOptions["color"] == "Red")
    }

    @Test("Different option selections create different cart rows")
    func differentOptionSelectionsCreateDifferentCartRows() {
        let state = AppState(service: MockCommerceService())
        let product = TestFactory.product(options: [ProductOption(name: "color", values: ["Red", "Blue"])])

        state.addToCart(product, selection: ProductSelection(selectedOptions: ["color": "Red"], quantity: 1))
        state.addToCart(product, selection: ProductSelection(selectedOptions: ["color": "Blue"], quantity: 1))

        #expect(state.cartItems.count == 2)
        #expect(state.cartCount == 2)
    }

    @Test("Out of stock products are not added to cart")
    func outOfStockProductsAreNotAddedToCart() {
        let state = AppState(service: MockCommerceService())
        let product = TestFactory.product(quantityRemaining: 0)

        state.addToCart(product)

        #expect(state.cartItems.isEmpty)
        #expect(state.cartCount == 0)
    }

    @Test("Updating quantity removes a cart item at zero")
    func updatingQuantityRemovesCartItemAtZero() {
        let state = AppState(service: MockCommerceService())
        let product = TestFactory.product()
        state.addToCart(product)
        let itemID = state.cartItems.keys.first ?? ""

        state.updateQuantity(for: itemID, quantity: 0)

        #expect(state.cartItems.isEmpty)
    }

    @Test("Cart totals exclude VAT while checkout totals include VAT")
    func cartTotalsExcludeVatWhileCheckoutTotalsIncludeVat() {
        let state = AppState(service: MockCommerceService())
        let vendor = TestFactory.vendor()
        let product = TestFactory.product(vendor: vendor, price: 100, discountPercentage: 10)
        state.addToCart(product, selection: ProductSelection(selectedOptions: [:], quantity: 2))

        #expect(state.cartTotals.subtotal == Decimal(180))
        #expect(state.cartTotals.vat == 0)
        #expect(state.checkoutTotals.vat == Decimal(string: "13.5"))
        #expect(state.checkoutTotals.grandTotal == Decimal(string: "193.5"))
    }

    @Test("Selected vendor toggling affects checkout selection")
    func selectedVendorTogglingAffectsCheckoutSelection() {
        let state = AppState(service: MockCommerceService())
        let vendor = TestFactory.vendor(id: "vendor-a", name: "Vendor A")
        let product = TestFactory.product(vendor: vendor)
        state.addToCart(product)

        #expect(state.selectedSections.count == 1)
        state.toggleVendorSelection(vendor.id)
        #expect(state.selectedSections.isEmpty)
        state.toggleVendorSelection(vendor.id)
        #expect(state.selectedSections.count == 1)
    }
    
    @Test("Available categories are unique and sorted")
    func availableCategoriesAreUniqueAndSorted() {
        let state = AppState(service: MockCommerceService())
        state.products = [
            TestFactory.product(id: "a", category: ["electronics", "audio"]),
            TestFactory.product(id: "b", category: ["clothing", "electronics"])
        ]
        
        #expect(state.availableProductCategories == ["audio", "clothing", "electronics"])
    }
    
    @Test("Product filtering matches keyword category price and stock")
    func productFilteringMatchesKeywordCategoryPriceAndStock() {
        let state = AppState(service: MockCommerceService())
        state.products = [
            TestFactory.product(id: "shoe", name: "Aero Runner", category: ["clothing"], price: 120, discountPercentage: 0, quantityRemaining: 8),
            TestFactory.product(id: "watch", name: "Nordic Smart Watch", category: ["electronics"], price: 240, discountPercentage: 10, quantityRemaining: 0),
            TestFactory.product(id: "tee", name: "Essential Tee", category: ["clothing"], price: 28, discountPercentage: 0, quantityRemaining: 42)
        ]
        
        let clothingResults = state.filteredProducts(
            matching: "tee",
            filter: ProductFilter(selectedCategory: "clothing", priceFilter: .under50, inStockOnly: true)
        )
        let electronicsResults = state.filteredProducts(
            matching: "",
            filter: ProductFilter(selectedCategory: "electronics", priceFilter: .above150, inStockOnly: false)
        )
        
        #expect(clothingResults.map(\.id) == ["tee"])
        #expect(electronicsResults.map(\.id) == ["watch"])
    }

    @Test("Navigation helpers append and clear routes")
    func navigationHelpersAppendAndClearRoutes() {
        let state = AppState(service: MockCommerceService())
        let product = TestFactory.product()

        state.goToCart()
        state.goToOrders()
        state.goToProduct(product)
        state.goHome()

        #expect(state.path.isEmpty)
    }

    @Test("Order lists split in-progress and settled orders")
    func orderListsSplitInProgressAndSettledOrders() {
        let state = AppState(service: MockCommerceService())
        state.successfulOrders = [
            TestFactory.order(id: "in-progress", itemStatuses: [.pending, .shipped], orderStatus: .inProgress),
            TestFactory.order(id: "settled", itemStatuses: [.delivered, .cancelled], orderStatus: .settled)
        ]

        #expect(state.activeOrders.map(\.id) == ["in-progress"])
        #expect(state.settledOrders.map(\.id) == ["settled"])
        #expect(state.ordersCount == 2)
    }

    @Test("Cancelling an item updates persisted order state")
    func cancellingAnItemUpdatesPersistedOrderState() {
        let state = AppState(service: MockCommerceService())
        let order = TestFactory.order(id: "order-1", itemStatuses: [.shipped, .delivered], orderStatus: .inProgress)
        state.successfulOrders = [order]

        state.cancelOrderItem(in: "order-1", orderItemID: "item-0")

        let updatedOrder = state.order(withID: "order-1")
        #expect(updatedOrder?.vendorGroups[0].items[0].status == .cancelled)
        #expect(updatedOrder?.status == .settled)
    }

    @Test("Cancelling a vendor cancels all items in that group")
    func cancellingAVendorCancelsAllItemsInThatGroup() {
        let state = AppState(service: MockCommerceService())
        state.successfulOrders = [
            TestFactory.order(
                id: "order-2",
                groups: [
                    TestFactory.vendorGroup(
                        vendor: TestFactory.vendor(id: "vendor-a", name: "Vendor A"),
                        itemStatuses: [.pending, .confirmed],
                        status: .inProgress
                    ),
                    TestFactory.vendorGroup(
                        vendor: TestFactory.vendor(id: "vendor-b", name: "Vendor B"),
                        itemStatuses: [.shipped],
                        status: .inProgress
                    )
                ],
                orderStatus: .inProgress
            )
        ]

        state.cancelVendor(in: "order-2", vendorID: "vendor-a")

        let updatedOrder = state.order(withID: "order-2")
        #expect(updatedOrder?.vendorGroups[0].items.allSatisfy { $0.status == .cancelled } == true)
        #expect(updatedOrder?.vendorGroups[1].items[0].status == .shipped)
    }

    @Test("Cancelling an order cancels every item")
    func cancellingAnOrderCancelsEveryItem() {
        let state = AppState(service: MockCommerceService())
        state.successfulOrders = [
            TestFactory.order(id: "order-3", itemStatuses: [.pending, .confirmed], orderStatus: .inProgress)
        ]

        state.cancelOrder("order-3")

        let updatedOrder = state.order(withID: "order-3")
        #expect(updatedOrder?.status == .settled)
        #expect(updatedOrder?.allItems.allSatisfy { $0.status == .cancelled } == true)
    }

    @Test("Submitting payment succeeds, persists order, and clears cart")
    func submittingPaymentSucceedsPersistsOrderAndClearsCart() async throws {
        let service = MockCommerceService()
        let state = AppState(service: service)
        let vendor = TestFactory.vendor(id: "vendor-pay", name: "Vendor Pay")
        let product = TestFactory.product(
            id: "product-pay",
            vendor: vendor,
            price: 120,
            discountPercentage: 10,
            options: [ProductOption(name: "color", values: ["Black", "White"])]
        )
        state.addToCart(product, selection: ProductSelection(selectedOptions: ["color": "White"], quantity: 2))

        await state.submitPayment()

        let payload = try #require(service.submittedPayloads.first)
        let vendors = try #require(payload["vendors"] as? [String: Any])
        #expect(vendors["vendor-pay"] != nil)
        #expect(state.currentOrder?.allItems.first?.status == .pending)
        #expect(state.paymentReference == "PAY-TEST-1001")
        #expect(state.hasCompletedPayment == true)
        #expect(state.successfulOrders.count == 1)
        #expect(state.cartItems.isEmpty)
        #expect(state.selectedVendorIDs.isEmpty)
    }

    @Test("Submitting payment captures service failure")
    func submittingPaymentCapturesServiceFailure() async {
        let service = MockCommerceService()
        service.submitError = APIError.transport("payment failed")
        let state = AppState(service: service)
        state.addToCart(TestFactory.product())

        await state.submitPayment()

        #expect(state.hasCompletedPayment == false)
        #expect(state.paymentReference == nil)
        #expect(state.paymentErrorMessage == "payment failed")
    }
}

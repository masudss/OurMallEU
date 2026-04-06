import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var isShowingSplash = true
    @Published var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var isLoadingNextPage = false
    @Published var productErrorMessage: String?
    @Published var cartItems: [String: CartItem] = [:]
    @Published var selectedVendorIDs: Set<String> = []
    @Published var isSubmittingPayment = false
    @Published var paymentErrorMessage: String?
    @Published var paymentReference: String?
    @Published var currentOrder: Order?
    @Published var successfulOrders: [Order] = []
    @Published var hasCompletedPayment = false

    let heroBanners: [URL] = [
        URL(string: "https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=1400&q=80")!,
        URL(string: "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=960&q=60")!,
        URL(string: "https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=960&q=60")!
    ]

    private let service: CommerceServicing
    private let pageSize = 6
    private var hasStarted = false
    private(set) var currentPage = 0
    private(set) var hasMoreProducts = true

    init(service: CommerceServicing? = nil) {
        self.service = service ?? CommerceAPIClient()
    }

    static let preview = AppState(service: PreviewCommerceService())

    var cartCount: Int {
        cartItems.values.reduce(0) { $0 + $1.quantity }
    }
    
    var ordersCount: Int {
        successfulOrders.count
    }

    var activeOrders: [Order] {
        successfulOrders.filter { order in
            order.allItems.contains { !$0.status.isSettled }
        }
    }
    
    var settledOrders: [Order] {
        successfulOrders.filter { order in
            !order.allItems.isEmpty && order.allItems.allSatisfy(\.status.isSettled)
        }
    }
    
    var availableProductCategories: [String] {
        Array(Set(products.flatMap(\.category)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var vendorSections: [VendorCartSection] {
        let grouped = Dictionary(grouping: cartItems.values) { $0.product.vendor }

        return grouped
            .map { vendor, items in
                VendorCartSection(
                    vendor: vendor,
                    items: items.sorted {
                        if $0.product.name == $1.product.name {
                            return $0.selectedOptionsText < $1.selectedOptionsText
                        }
                        return $0.product.name < $1.product.name
                    },
                    isSelected: selectedVendorIDs.contains(vendor.id)
                )
            }
            .sorted { $0.vendor.name < $1.vendor.name }
    }

    var selectedSections: [VendorCartSection] {
        vendorSections.filter(\.isSelected)
    }

    var checkoutTotals: CheckoutTotals {
        guard !selectedSections.isEmpty else {
            return .empty
        }

        let subtotal = selectedSections.reduce(0) { $0 + $1.subtotal }
        let discount = selectedSections.reduce(0) { $0 + $1.discountTotal }
        let vat = (subtotal * .vatRate).rounded()
        let grandTotal = (subtotal + vat).rounded()
        return CheckoutTotals(subtotal: subtotal.rounded(), discount: discount.rounded(), vat: vat, grandTotal: grandTotal)
    }

    var cartTotals: CheckoutTotals {
        guard !selectedSections.isEmpty else {
            return .empty
        }

        let subtotal = selectedSections.reduce(0) { $0 + $1.subtotal }
        let discount = selectedSections.reduce(0) { $0 + $1.discountTotal }
        return CheckoutTotals(
            subtotal: subtotal.rounded(),
            discount: discount.rounded(),
            vat: 0,
            grandTotal: subtotal.rounded()
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            isShowingSplash = false
            await refreshProducts()
        }
    }

    func refreshProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        productErrorMessage = nil
        currentPage = 0
        hasMoreProducts = true
        products = []

        do {
            let firstPage = try await service.fetchProducts(page: 1, pageSize: pageSize)
            currentPage = firstPage.page
            hasMoreProducts = firstPage.hasMorePages
            products = firstPage.items
        } catch {
            productErrorMessage = error.localizedDescription
        }

        isLoadingProducts = false
    }

    func retryLoadingProducts() {
        Task {
            await refreshProducts()
        }
    }

    func loadNextPageIfNeeded(currentProduct: Product) {
        guard hasMoreProducts, !isLoadingProducts, !isLoadingNextPage else { return }
        guard products.suffix(4).contains(where: { $0.id == currentProduct.id }) else { return }

        Task {
            await loadNextPage()
        }
    }

    func addToCart(_ product: Product) {
        addToCart(product, selection: product.defaultSelection)
    }

    func addToCart(_ product: Product, selection: ProductSelection) {
        guard product.inStock else { return }
        resetPaymentStateForCartChanges()

        let normalizedSelection = normalizedSelection(for: product, selection: selection)
        let candidate = CartItem(
            product: product,
            selectedOptions: normalizedSelection.selectedOptions,
            quantity: 0
        )

        let existingQuantity = cartItems[candidate.cartKey]?.quantity ?? 0
        let newQuantity = min(product.quantityRemaining, existingQuantity + max(1, normalizedSelection.quantity))
        guard newQuantity > 0 else { return }

        cartItems[candidate.cartKey] = CartItem(
            product: product,
            selectedOptions: normalizedSelection.selectedOptions,
            quantity: newQuantity
        )
        selectedVendorIDs.insert(product.vendor.id)
    }

    func quantityInCart(for product: Product) -> Int {
        cartItems.values
            .filter { $0.product.id == product.id }
            .reduce(0) { $0 + $1.quantity }
    }
    
    func filteredProducts(matching query: String, filter: ProductFilter) -> [Product] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return products.filter { product in
            let matchesQuery: Bool
            if normalizedQuery.isEmpty {
                matchesQuery = true
            } else {
                let searchableText = [
                    product.name,
                    product.vendor.name,
                    product.summary,
                    product.category.joined(separator: " ")
                ]
                .joined(separator: " ")
                matchesQuery = searchableText.localizedCaseInsensitiveContains(normalizedQuery)
            }
            
            let matchesCategory = filter.selectedCategory.map { category in
                product.category.contains { $0.caseInsensitiveCompare(category) == .orderedSame }
            } ?? true
            let matchesPrice = filter.priceFilter?.matches(price: product.discountedPrice) ?? true
            let matchesStock = filter.inStockOnly ? product.inStock : true
            
            return matchesQuery && matchesCategory && matchesPrice && matchesStock
        }
    }

    func updateQuantity(for itemID: String, quantity: Int) {
        guard let existing = cartItems[itemID] else { return }
        resetPaymentStateForCartChanges()

        if quantity <= 0 {
            cartItems.removeValue(forKey: itemID)
        } else {
            cartItems[itemID] = CartItem(
                product: existing.product,
                selectedOptions: existing.selectedOptions,
                quantity: min(quantity, existing.product.quantityRemaining)
            )
        }

        pruneSelectedVendors()
    }

    func toggleVendorSelection(_ vendorID: String) {
        if selectedVendorIDs.contains(vendorID) {
            selectedVendorIDs.remove(vendorID)
        } else {
            selectedVendorIDs.insert(vendorID)
        }
    }

    func goToCart() {
        path.append(.cart)
    }

    func goToOrders() {
        path.append(.orders)
    }

    func goToOrderDetails(_ orderID: String) {
        path.append(.orderDetails(orderID))
    }

    func goToProduct(_ product: Product) {
        path.append(.product(product))
    }

    func goToCheckout() {
        guard !selectedSections.isEmpty else { return }
        path.append(.checkout)
    }

    func goToPayment() {
        guard !selectedSections.isEmpty else { return }
        path.append(.payment)
    }

    func goHome() {
        path.removeAll()
    }

    func submitPayment() async {
        isSubmittingPayment = true
        paymentErrorMessage = nil

        do {
            try? await Task.sleep(for: .seconds(2))
            let request = try buildPaymentRequest()
            let payload = try request.asDictionary()
            currentOrder = buildPendingOrder()

            let response = try await service.submitPayment(payload: payload)
            paymentReference = response.paymentReference
            hasCompletedPayment = true
            if let currentOrder {
                successfulOrders.insert(currentOrder, at: 0)
            }
            removePurchasedItems()
        } catch {
            paymentErrorMessage = error.localizedDescription
            hasCompletedPayment = false
        }

        isSubmittingPayment = false
    }

    func cancelOrderItem(_ orderItemID: String) {
        guard let currentOrder else { return }
        cancelOrderItem(in: currentOrder.id, orderItemID: orderItemID)
    }

    func cancelVendor(_ vendorID: String) {
        guard let currentOrder else { return }
        cancelVendor(in: currentOrder.id, vendorID: vendorID)
    }

    func cancelOrder() {
        guard let currentOrder else { return }
        cancelOrder(currentOrder.id)
    }

    func order(withID orderID: String) -> Order? {
        successfulOrders.first(where: { $0.id == orderID })
    }

    func cancelOrderItem(in orderID: String, orderItemID: String) {
        updateOrder(withID: orderID) { order in
            for groupIndex in order.vendorGroups.indices {
                for itemIndex in order.vendorGroups[groupIndex].items.indices where order.vendorGroups[groupIndex].items[itemIndex].id == orderItemID {
                    order.vendorGroups[groupIndex].items[itemIndex].status = .cancelled
                }
                syncVendorStatus(for: groupIndex, in: &order)
            }
            syncOrderStatus(in: &order)
        }
    }

    func cancelVendor(in orderID: String, vendorID: String) {
        updateOrder(withID: orderID) { order in
            for groupIndex in order.vendorGroups.indices where order.vendorGroups[groupIndex].vendor.id == vendorID {
                order.vendorGroups[groupIndex].status = .settled
                order.vendorGroups[groupIndex].items = order.vendorGroups[groupIndex].items.map {
                    OrderItem(
                        id: $0.id,
                        productID: $0.productID,
                        productName: $0.productName,
                        quantity: $0.quantity,
                        unitPrice: $0.unitPrice,
                        selectedOptions: $0.selectedOptions,
                        status: .cancelled
                    )
                }
            }
            syncOrderStatus(in: &order)
        }
    }

    func cancelOrder(_ orderID: String) {
        updateOrder(withID: orderID) { order in
            order.status = .settled
            order.vendorGroups = order.vendorGroups.map { group in
                VendorOrderGroup(
                    vendor: group.vendor,
                    items: group.items.map {
                        OrderItem(
                            id: $0.id,
                            productID: $0.productID,
                            productName: $0.productName,
                            quantity: $0.quantity,
                            unitPrice: $0.unitPrice,
                            selectedOptions: $0.selectedOptions,
                            status: .cancelled
                        )
                    },
                    status: .settled
                )
            }
        }
    }

    private func loadNextPage() async {
        guard hasMoreProducts else { return }
        isLoadingNextPage = true

        do {
            let nextPage = currentPage + 1
            let response = try await service.fetchProducts(page: nextPage, pageSize: pageSize)
            currentPage = response.page
            hasMoreProducts = response.hasMorePages
            products.append(contentsOf: response.items)
        } catch {
            productErrorMessage = error.localizedDescription
        }

        isLoadingNextPage = false
    }

    private func normalizedSelection(for product: Product, selection: ProductSelection) -> ProductSelection {
        var resolvedOptions: [String: String] = [:]

        for option in product.options {
            if let chosen = selection.selectedOptions[option.name], option.values.contains(chosen) {
                resolvedOptions[option.name] = chosen
            } else if let defaultValue = option.values.first {
                resolvedOptions[option.name] = defaultValue
            }
        }

        return ProductSelection(
            selectedOptions: resolvedOptions,
            quantity: min(max(1, selection.quantity), product.quantityRemaining)
        )
    }

    private func buildPaymentRequest() throws -> PaymentRequest {
        guard !selectedSections.isEmpty else {
            throw APIError.emptyCheckout
        }

        let vendors = Dictionary(uniqueKeysWithValues: selectedSections.map { section in
            (
                section.vendor.id,
                section.items.map {
                    CheckoutProductPayload(
                        productId: $0.product.id,
                        quantity: $0.quantity,
                        unitPrice: $0.product.discountedPrice.rounded(),
                        selectedOptions: $0.selectedOptions
                    )
                }
            )
        })

        let totals = checkoutTotals
        return PaymentRequest(
            vendors: vendors,
            summary: PaymentSummaryPayload(
                subtotal: totals.subtotal,
                discount: totals.discount,
                vat: totals.vat,
                grandTotal: totals.grandTotal
            )
        )
    }

    private func buildPendingOrder() -> Order {
        let vendorGroups = selectedSections.map { section in
            VendorOrderGroup(
                vendor: section.vendor,
                items: section.items.map {
                    OrderItem(
                        id: UUID().uuidString,
                        productID: $0.product.id,
                        productName: $0.product.name,
                        quantity: $0.quantity,
                        unitPrice: $0.product.discountedPrice.rounded(),
                        selectedOptions: $0.selectedOptions,
                        status: .pending
                    )
                },
                status: .inProgress
            )
        }

        return Order(
            id: UUID().uuidString,
            status: .inProgress,
            vendorGroups: vendorGroups,
            createdAt: Date()
        )
    }

    private func removePurchasedItems() {
        let purchasedItemIDs = Set(selectedSections.flatMap { $0.items.map(\.id) })
        purchasedItemIDs.forEach { cartItems.removeValue(forKey: $0) }
        selectedVendorIDs.removeAll()
    }

    private func pruneSelectedVendors() {
        let currentVendorIDs = Set(cartItems.values.map { $0.product.vendor.id })
        selectedVendorIDs = selectedVendorIDs.intersection(currentVendorIDs)
    }

    private func resetPaymentStateForCartChanges() {
        hasCompletedPayment = false
        paymentErrorMessage = nil
        paymentReference = nil
    }

    private func updateOrder(withID orderID: String, mutation: (inout Order) -> Void) {
        if var currentOrder, currentOrder.id == orderID {
            mutation(&currentOrder)
            self.currentOrder = currentOrder
        }

        if let index = successfulOrders.firstIndex(where: { $0.id == orderID }) {
            var updatedOrder = successfulOrders[index]
            mutation(&updatedOrder)
            successfulOrders[index] = updatedOrder
        }
    }

    private func syncVendorStatus(for groupIndex: Int, in order: inout Order) {
        let items = order.vendorGroups[groupIndex].items
        order.vendorGroups[groupIndex].status = items.allSatisfy(\.status.isSettled) ? .settled : .inProgress
    }

    private func syncOrderStatus(in order: inout Order) {
        order.status = order.vendorGroups.allSatisfy { $0.items.allSatisfy(\.status.isSettled) } ? .settled : .inProgress
    }
}

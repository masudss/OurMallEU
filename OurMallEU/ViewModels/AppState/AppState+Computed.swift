import Foundation

extension AppState {
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
}

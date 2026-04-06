import Foundation

extension AppState {
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

    private func pruneSelectedVendors() {
        let currentVendorIDs = Set(cartItems.values.map { $0.product.vendor.id })
        selectedVendorIDs = selectedVendorIDs.intersection(currentVendorIDs)
    }

    private func resetPaymentStateForCartChanges() {
        hasCompletedPayment = false
        paymentErrorMessage = nil
        paymentReference = nil
    }
}

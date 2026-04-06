import Foundation

extension AppState {
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
}

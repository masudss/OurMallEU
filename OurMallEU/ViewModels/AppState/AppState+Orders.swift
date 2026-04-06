import Foundation

extension AppState {
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

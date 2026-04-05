import SwiftUI

struct OrderDetailsView: View {
    @EnvironmentObject private var appState: AppState

    let orderID: String
    @State private var pendingCancellation: CancellationTarget?
    @State private var isProcessingCancellation = false
    @State private var refundAmount: Decimal?

    private var order: Order? {
        appState.order(withID: orderID)
    }

    var body: some View {
        Group {
            if let order {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Order details")
                                .font(.headline)
                            Text("Track and manage your paid order while it is in transit.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        OrderStatusSection(
                            order: order,
                            onCancelItem: { item in
                                pendingCancellation = .item(item)
                            },
                            onCancelVendor: { group in
                                pendingCancellation = .vendor(group)
                            },
                            onCancelOrder: {
                                pendingCancellation = .fullOrder
                            }
                        )
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView(
                    "Order unavailable",
                    systemImage: "shippingbox",
                    description: Text("This order could not be found.")
                )
            }
        }
        .navigationTitle("Order details")
        .overlay {
            if isProcessingCancellation {
                PaymentProcessingOverlay(message: "Processing refund...")
                    .transition(.opacity)
            }

            if let refundAmount {
                RefundSuccessDialog(refundAmount: refundAmount) {
                    self.refundAmount = nil
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .alert(item: $pendingCancellation) { target in
            Alert(
                title: Text(target.title),
                message: Text(target.message),
                primaryButton: .destructive(Text("Yes")) {
                    Task {
                        await handleCancellation(target)
                    }
                },
                secondaryButton: .cancel(Text("No"))
            )
        }
    }

    private func handleCancellation(_ target: CancellationTarget) async {
        guard let order else { return }

        let amount = target.refundAmount(in: order)
        guard amount > 0 else { return }

        isProcessingCancellation = true
        try? await Task.sleep(for: .seconds(2))

        switch target {
        case .item(let item):
            appState.cancelOrderItem(in: orderID, orderItemID: item.id)
        case .vendor(let group):
            appState.cancelVendor(in: orderID, vendorID: group.vendor.id)
        case .fullOrder:
            appState.cancelOrder(orderID)
        }

        isProcessingCancellation = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            refundAmount = amount
        }
    }
}

#Preview {
    NavigationStack {
        OrderDetailsView(orderID: "preview-order")
            .environmentObject(AppState.preview)
    }
}

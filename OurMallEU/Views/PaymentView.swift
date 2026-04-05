import SwiftUI

struct PaymentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPaymentSuccessDialog = false
    @State private var pendingCancellation: CancellationTarget?
    @State private var isProcessingCancellation = false
    @State private var refundAmount: Decimal?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Please make payment to confirm your purchase and alert the vendor ship your item.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Total")
                        .font(.headline)
                    Text(appState.checkoutTotals.grandTotal.currencyText)
                        .font(.largeTitle.bold())
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if let paymentErrorMessage = appState.paymentErrorMessage {
                    Label(paymentErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }

                if let currentOrder = appState.currentOrder {
                    OrderStatusSection(
                        order: currentOrder,
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
            }
            .padding()
        }
        .navigationTitle("Payment")
        .overlay {
            if appState.isSubmittingPayment {
                PaymentProcessingOverlay()
                    .transition(.opacity)
            }

            if isProcessingCancellation {
                PaymentProcessingOverlay(message: "Processing refund...")
                    .transition(.opacity)
            }

            if showPaymentSuccessDialog {
                PaymentSuccessDialog {
                    showPaymentSuccessDialog = false
                }
                .transition(.scale.combined(with: .opacity))
            }

            if let refundAmount {
                RefundSuccessDialog(refundAmount: refundAmount) {
                    self.refundAmount = nil
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: appState.hasCompletedPayment) { _, hasCompletedPayment in
            if hasCompletedPayment {
                showPaymentSuccessDialog = true
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
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let paymentReference = appState.paymentReference {
                    Text("Payment reference: \(paymentReference)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !appState.hasCompletedPayment {
                    Button {
                        Task {
                            await appState.submitPayment()
                        }
                    } label: {
                        if appState.isSubmittingPayment {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Pay now")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isSubmittingPayment)
                } else {
                    Button("Go home") {
                        appState.goHome()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.thinMaterial)
        }
    }

    private func handleCancellation(_ target: CancellationTarget) async {
        guard let order = appState.currentOrder else { return }

        let amount = target.refundAmount(in: order)
        guard amount > 0 else { return }

        isProcessingCancellation = true
        try? await Task.sleep(for: .seconds(2))

        switch target {
        case .item(let item):
            appState.cancelOrderItem(item.id)
        case .vendor(let group):
            appState.cancelVendor(group.vendor.id)
        case .fullOrder:
            appState.cancelOrder()
        }

        isProcessingCancellation = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            refundAmount = amount
        }
    }
}

enum CancellationTarget: Identifiable {
    case item(OrderItem)
    case vendor(VendorOrderGroup)
    case fullOrder

    var id: String {
        switch self {
        case .item(let item):
            return "item-\(item.id)"
        case .vendor(let group):
            return "vendor-\(group.id)"
        case .fullOrder:
            return "full-order"
        }
    }

    var title: String {
        switch self {
        case .item:
            return "Cancel item?"
        case .vendor:
            return "Cancel vendor order?"
        case .fullOrder:
            return "Cancel entire order?"
        }
    }

    var message: String {
        switch self {
        case .item(let item):
            return "This will cancel \(item.productName) only."
        case .vendor(let group):
            return "This will cancel all items from \(group.vendor.name)."
        case .fullOrder:
            return "This will cancel every vendor and item in this order."
        }
    }

    func refundAmount(in order: Order) -> Decimal {
        switch self {
        case .item(let item):
            guard item.status != .cancelled else { return 0 }
            return (item.unitPrice * Decimal(item.quantity)).rounded()
        case .vendor(let group):
            return group.items
                .filter { $0.status != .cancelled }
                .reduce(0) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
                .rounded()
        case .fullOrder:
            return order.vendorGroups
                .flatMap(\.items)
                .filter { $0.status != .cancelled }
                .reduce(0) { $0 + ($1.unitPrice * Decimal($1.quantity)) }
                .rounded()
        }
    }
}

struct PaymentProcessingOverlay: View {
    var message = "Processing payment..."

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.blue)
                    .scaleEffect(1.8)
                    .padding(24)
                    .background(.white, in: Circle())

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .allowsHitTesting(true)
    }
}

private struct PaymentSuccessDialog: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.10))
                        .frame(width: 120, height: 120)

                    Image(systemName: "bicycle")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(.blue)
                }

                VStack(spacing: 8) {
                    Text("Items are on the way")
                        .font(.title3.bold())

                    Text("Your payment was successful and your order is now being prepared for delivery.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Okay", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 24)
        }
    }
}

struct RefundSuccessDialog: View {
    let refundAmount: Decimal
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.10))
                        .frame(width: 120, height: 120)

                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(.green)
                }

                VStack(spacing: 8) {
                    Text("Refund successful")
                        .font(.title3.bold())

                    Text("You have been refunded \(refundAmount.currencyText) for the cancelled items.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Okay", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 24)
        }
    }
}

struct OrderStatusSection: View {
    let order: Order
    let onCancelItem: (OrderItem) -> Void
    let onCancelVendor: (VendorOrderGroup) -> Void
    let onCancelOrder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Order status")
                    .font(.headline)
                Spacer()
                Text(order.displayStatusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(order.isCancelled ? .red : (order.isSettled ? .green : .blue))
            }

            ForEach(order.vendorGroups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.vendor.name)
                                .font(.subheadline.weight(.semibold))
                            Text(group.displayStatusTitle)
                                .font(.caption)
                                .foregroundStyle(group.isCancelled ? .red : (group.isSettled ? .green : .secondary))
                        }

                        Spacer()

                        Button("Cancel vendor") {
                            onCancelVendor(group)
                        }
                        .buttonStyle(.bordered)
                        .disabled(group.status == .settled)
                    }

                    ForEach(group.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.productName)
                                Text(item.selectedOptions.keys.sorted().map { "\($0.capitalized): \(item.selectedOptions[$0] ?? "")" }.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Qty \(item.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(item.status.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(item.status == .cancelled ? .red : .secondary)

                            Button("Cancel") {
                                onCancelItem(item)
                            }
                            .buttonStyle(.borderless)
                            .disabled(item.status.isSettled)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Button("Cancel entire order") {
                onCancelOrder()
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(order.status == .settled)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PaymentView()
            .environmentObject(AppState.preview)
    }
}

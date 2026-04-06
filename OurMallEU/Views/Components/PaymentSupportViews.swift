import SwiftUI

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

struct PaymentSuccessDialog: View {
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

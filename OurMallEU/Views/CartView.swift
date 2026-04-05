import SwiftUI

struct CartView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            if appState.vendorSections.isEmpty {
                ContentUnavailableView("Your cart is empty", systemImage: "cart")
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(appState.vendorSections) { section in
                        VendorCartCard(section: section)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Cart")
        .safeAreaInset(edge: .bottom) {
            if !appState.vendorSections.isEmpty {
                VStack {
                    CartSummaryBar(
                        totals: appState.cartTotals,
                        selectionCount: appState.selectedSections.count,
                        onCheckout: appState.goToCheckout
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(.thinMaterial)
            }
        }
    }
}

private struct VendorCartCard: View {
    @EnvironmentObject private var appState: AppState
    let section: VendorCartSection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    appState.toggleVendorSelection(section.vendor.id)
                } label: {
                    Image(systemName: section.isSelected ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(section.isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.vendor.name)
                        .font(.headline)
                    Text("Vendor total: \(section.subtotal.currencyText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ForEach(section.items) { item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.product.name)
                            .font(.subheadline.weight(.semibold))
                        Text(item.selectedOptionsText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(item.product.discountedPrice.currencyText) each")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Stepper(value: Binding(
                        get: { item.quantity },
                        set: { newValue in appState.updateQuantity(for: item.id, quantity: newValue) }
                    ), in: 0...item.product.quantityRemaining) {
                        Text("Qty \(item.quantity)")
                            .font(.caption.weight(.medium))
                    }
                    .labelsHidden()

                    Text(item.totalPrice.currencyText)
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 72, alignment: .trailing)
                }
                .padding(.vertical, 10)

                if item.id != section.items.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

private struct CartSummaryBar: View {
    let totals: CheckoutTotals
    let selectionCount: Int
    let onCheckout: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Selected vendors")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectionCount)")
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Grand total")
                    .font(.headline)
                Spacer()
                Text(totals.grandTotal.currencyText)
                    .font(.headline)
            }

            Button("Checkout", action: onCheckout)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(selectionCount == 0)
        }
    }
}

#Preview {
    NavigationStack {
        CartView()
            .environmentObject(AppState.preview)
    }
}

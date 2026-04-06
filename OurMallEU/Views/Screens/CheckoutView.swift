import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(appState.selectedSections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.vendor.name)
                            .font(.headline)

                        ForEach(section.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.product.name)
                                    Text(item.selectedOptionsText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Qty \(item.quantity)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.totalPrice.currencyText)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Price breakdown")
                        .font(.headline)

                    BreakdownRow(title: "Subtotal", value: appState.checkoutTotals.subtotal.currencyText)
                    BreakdownRow(title: "Discounts", value: "-\(appState.checkoutTotals.discount.currencyText)")
                    BreakdownRow(title: "VAT", value: appState.checkoutTotals.vat.currencyText)
                    Divider()
                    BreakdownRow(title: "Total", value: appState.checkoutTotals.grandTotal.currencyText, emphasized: true)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding()
        }
        .navigationTitle("Checkout")
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button("Continue to payment") {
                    appState.goToPayment()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.thinMaterial)
        }
    }
}

private struct BreakdownRow: View {
    let title: String
    let value: String
    var emphasized = false

    var body: some View {
        HStack {
            Text(title)
                .font(emphasized ? .headline : .body)
            Spacer()
            Text(value)
                .font(emphasized ? .headline : .body)
        }
    }
}

#Preview {
    NavigationStack {
        CheckoutView()
            .environmentObject(AppState.preview)
    }
}

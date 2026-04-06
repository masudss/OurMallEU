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
        .navigationBarBackButtonHidden(appState.hasCompletedPayment)
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
#Preview {
    NavigationStack {
        PaymentView()
            .environmentObject(AppState.preview)
    }
}

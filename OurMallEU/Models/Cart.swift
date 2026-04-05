import Foundation

struct CartItem: Identifiable, Hashable {
    let product: Product
    let selectedOptions: [String: String]
    var quantity: Int

    var id: String {
        cartKey
    }

    var cartKey: String {
        let optionsKey = selectedOptions.keys.sorted().map { "\($0)=\(selectedOptions[$0] ?? "")" }.joined(separator: "|")
        return "\(product.id)::\(optionsKey)"
    }

    var totalPrice: Decimal {
        product.discountedPrice * Decimal(quantity)
    }

    var totalListPrice: Decimal {
        product.price * Decimal(quantity)
    }

    var selectedOptionsText: String {
        guard !selectedOptions.isEmpty else {
            return "Default options"
        }

        return selectedOptions.keys
            .sorted()
            .map { "\($0.capitalized): \(selectedOptions[$0] ?? "")" }
            .joined(separator: " • ")
    }
}

struct VendorCartSection: Identifiable, Hashable {
    let vendor: Vendor
    let items: [CartItem]
    let isSelected: Bool

    var id: String {
        vendor.id
    }

    var subtotal: Decimal {
        items.reduce(0) { $0 + $1.totalPrice }
    }

    var listTotal: Decimal {
        items.reduce(0) { $0 + $1.totalListPrice }
    }

    var discountTotal: Decimal {
        listTotal - subtotal
    }
}

struct CheckoutTotals: Hashable {
    let subtotal: Decimal
    let discount: Decimal
    let vat: Decimal
    let grandTotal: Decimal

    static let empty = CheckoutTotals(subtotal: 0, discount: 0, vat: 0, grandTotal: 0)
}

extension Decimal {
    static let vatRate: Decimal = 0.075

    func rounded(scale: Int = 2) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .bankers)
        return result
    }

    var currencyText: String {
        NumberFormatter.currency.string(from: NSDecimalNumber(decimal: rounded())) ?? "\(self)"
    }
}

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale.current
        return formatter
    }()
}

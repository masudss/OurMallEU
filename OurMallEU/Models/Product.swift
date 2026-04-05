import Foundation

struct Vendor: Codable, Hashable, Identifiable {
    let id: String
    let name: String
}

struct Product: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let imageURL: URL?
    let vendor: Vendor
    let price: Decimal
    let discountPercentage: Decimal
    let offerEndsAt: Date?
    let quantityRemaining: Int
    let summary: String
    let options: [ProductOption]
    var status: ItemStatus = .pending

    var inStock: Bool {
        quantityRemaining > 0
    }

    var discountMultiplier: Decimal {
        max(0, min(1, discountPercentage / 100))
    }

    var discountedPrice: Decimal {
        price - (price * discountMultiplier)
    }

    var offerEndsText: String {
        guard let offerEndsAt else {
            return "No active offer"
        }

        if offerEndsAt < Date() {
            return "Offer ended"
        }

        return "Offer ends \(RelativeDateTimeFormatter().localizedString(for: offerEndsAt, relativeTo: Date()))"
    }

    var defaultSelection: ProductSelection {
        ProductSelection(
            selectedOptions: Dictionary(uniqueKeysWithValues: options.compactMap { option in
                guard let firstValue = option.values.first else { return nil }
                return (option.name, firstValue)
            }),
            quantity: 1
        )
    }
}

struct ProductOption: Codable, Hashable, Identifiable {
    let name: String
    let values: [String]

    var id: String {
        name
    }

    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct ProductSelection: Hashable {
    var selectedOptions: [String: String]
    var quantity: Int
}

struct ProductPage: Hashable {
    let items: [Product]
    let page: Int
    let hasMorePages: Bool
}

struct ProductDTO: Decodable {
    let id: String
    let name: String
    let imageURL: URL?
    let vendor: Vendor
    let price: Decimal
    let discountPercentage: Decimal?
    let offerEndsAt: Date?
    let quantityRemaining: Int
    let summary: String?
    let options: [String: [String]]?
    let status: ItemStatus?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageURL = "image_url"
        case vendor
        case price
        case discountPercentage = "discount_percentage"
        case offerEndsAt = "offer_ends_at"
        case quantityRemaining = "quantity_remaining"
        case summary
        case options
        case status
    }

    func toProduct() -> Product {
        Product(
            id: id,
            name: name,
            imageURL: imageURL,
            vendor: vendor,
            price: price,
            discountPercentage: discountPercentage ?? 0,
            offerEndsAt: offerEndsAt,
            quantityRemaining: quantityRemaining,
            summary: summary ?? "A premium multi-vendor catalog product with curated options.",
            options: (options ?? [:])
                .map { ProductOption(name: $0.key, values: $0.value) }
                .sorted { $0.name < $1.name },
            status: status ?? .pending
        )
    }
}

extension Product {
    private static func previewImageURL(fileName: String, fallback: String) -> URL? {
        let localURL = URL(fileURLWithPath: "/tmp/ourmalleu-images/\(fileName)")
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        return URL(string: fallback)
    }

    static let sampleProducts: [Product] = [
        Product(
            id: "shoe-1",
            name: "Aero Runner",
            imageURL: previewImageURL(
                fileName: "shoe.jpg",
                fallback: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=80"
            ),
            vendor: Vendor(id: "vendor-a", name: "BluePeak Sports"),
            price: 120,
            discountPercentage: 15,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            quantityRemaining: 8,
            summary: "Lightweight running shoes built for long city miles and daily training.",
            options: [
                ProductOption(name: "size", values: ["S", "M", "L", "XL", "XXL", "XXXL"]),
                ProductOption(name: "color", values: ["Red", "Black", "White"])
            ]
        ),
        Product(
            id: "watch-1",
            name: "Nordic Smart Watch",
            imageURL: previewImageURL(
                fileName: "watch.jpg",
                fallback: "https://images.unsplash.com/photo-1434056886845-dac89ffe9b56?auto=format&fit=crop&w=900&q=80"
            ),
            vendor: Vendor(id: "vendor-b", name: "NorthHub Electronics"),
            price: 240,
            discountPercentage: 10,
            offerEndsAt: Calendar.current.date(byAdding: .hour, value: 10, to: Date()),
            quantityRemaining: 0,
            summary: "An everyday smart watch with health tracking and strong battery life.",
            options: [
                ProductOption(name: "color", values: ["Black", "Silver", "Blue"])
            ]
        ),
        Product(
            id: "bag-1",
            name: "Metro Carry Bag",
            imageURL: URL(string: "https://images.unsplash.com/photo-1548036328-c9fa89d128fa?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-a", name: "BluePeak Sports"),
            price: 85,
            discountPercentage: 5,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            quantityRemaining: 4,
            summary: "Structured carry bag with padded compartments and weather-ready fabric.",
            options: [
                ProductOption(name: "color", values: ["Black", "Green", "Navy"])
            ]
        ),
        Product(
            id: "hoodie-1",
            name: "Core Street Hoodie",
            imageURL: URL(string: "https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-c", name: "ThreadHaus"),
            price: 72,
            discountPercentage: 20,
            offerEndsAt: Calendar.current.date(byAdding: .hour, value: 28, to: Date()),
            quantityRemaining: 13,
            summary: "Heavyweight hoodie with a relaxed fit and brushed inner lining.",
            options: [
                ProductOption(name: "size", values: ["S", "M", "L", "XL", "XXL"]),
                ProductOption(name: "color", values: ["Gray", "Black", "Cream"])
            ]
        ),
        Product(
            id: "speaker-1",
            name: "Pulse Mini Speaker",
            imageURL: URL(string: "https://images.unsplash.com/photo-1589003077984-894e133dabab?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-b", name: "NorthHub Electronics"),
            price: 96,
            discountPercentage: 12,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            quantityRemaining: 16,
            summary: "Portable Bluetooth speaker with crisp sound and all-day playback.",
            options: [
                ProductOption(name: "color", values: ["Black", "Red", "White"])
            ]
        ),
        Product(
            id: "lamp-1",
            name: "Halo Desk Lamp",
            imageURL: URL(string: "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-d", name: "Casa Nova"),
            price: 58,
            discountPercentage: 8,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
            quantityRemaining: 7,
            summary: "Minimal desk lamp with dimmable warmth and a stable metal base.",
            options: [
                ProductOption(name: "color", values: ["White", "Black", "Brass"])
            ]
        ),
        Product(
            id: "chair-1",
            name: "Contour Lounge Chair",
            imageURL: URL(string: "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-d", name: "Casa Nova"),
            price: 180,
            discountPercentage: 18,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            quantityRemaining: 3,
            summary: "Soft upholstered lounge chair shaped for comfort and small spaces.",
            options: [
                ProductOption(name: "color", values: ["Sand", "Olive", "Charcoal"])
            ]
        ),
        Product(
            id: "tee-1",
            name: "Essential Tee",
            imageURL: URL(string: "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-c", name: "ThreadHaus"),
            price: 28,
            discountPercentage: 0,
            offerEndsAt: nil,
            quantityRemaining: 42,
            summary: "Soft jersey tee made for daily wear and easy layering.",
            options: [
                ProductOption(name: "size", values: ["S", "M", "L", "XL", "XXL", "XXXL"]),
                ProductOption(name: "color", values: ["White", "Black", "Green"])
            ]
        ),
        Product(
            id: "kettle-1",
            name: "Arc Electric Kettle",
            imageURL: URL(string: "https://images.unsplash.com/photo-1517705008128-361805f42e86?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-e", name: "Kitchen Fold"),
            price: 64,
            discountPercentage: 14,
            offerEndsAt: Calendar.current.date(byAdding: .hour, value: 36, to: Date()),
            quantityRemaining: 11,
            summary: "Fast-boil kettle with a clean spout and compact countertop footprint.",
            options: [
                ProductOption(name: "color", values: ["Silver", "Matte Black"])
            ]
        ),
        Product(
            id: "blender-1",
            name: "Vivid Blend Pro",
            imageURL: URL(string: "https://images.unsplash.com/photo-1570222094114-d054a817e56b?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-e", name: "Kitchen Fold"),
            price: 135,
            discountPercentage: 9,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            quantityRemaining: 6,
            summary: "Countertop blender designed for smoothies, soups, and frozen mixes.",
            options: [
                ProductOption(name: "color", values: ["Black", "White"])
            ]
        ),
        Product(
            id: "camera-1",
            name: "Vista Pocket Camera",
            imageURL: URL(string: "https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-b", name: "NorthHub Electronics"),
            price: 320,
            discountPercentage: 11,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            quantityRemaining: 5,
            summary: "Compact travel camera with sharp optics and simple manual controls.",
            options: [
                ProductOption(name: "color", values: ["Black", "Silver"])
            ]
        ),
        Product(
            id: "sofa-1",
            name: "Cloud Corner Sofa",
            imageURL: URL(string: "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-d", name: "Casa Nova"),
            price: 720,
            discountPercentage: 16,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 6, to: Date()),
            quantityRemaining: 2,
            summary: "Large modular sofa with deep cushions and neutral upholstery.",
            options: [
                ProductOption(name: "color", values: ["Beige", "Slate", "Stone"])
            ]
        ),
        Product(
            id: "headphone-1",
            name: "QuietPulse Headphones",
            imageURL: URL(string: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-b", name: "NorthHub Electronics"),
            price: 210,
            discountPercentage: 13,
            offerEndsAt: Calendar.current.date(byAdding: .hour, value: 20, to: Date()),
            quantityRemaining: 14,
            summary: "Noise-cancelling headphones tuned for commuting and focused work.",
            options: [
                ProductOption(name: "color", values: ["Black", "White", "Blue"])
            ]
        ),
        Product(
            id: "boot-1",
            name: "Trailmark Boots",
            imageURL: URL(string: "https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-a", name: "BluePeak Sports"),
            price: 145,
            discountPercentage: 7,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            quantityRemaining: 10,
            summary: "Durable outdoor boots with strong grip and weather-resistant materials.",
            options: [
                ProductOption(name: "size", values: ["S", "M", "L", "XL", "XXL"]),
                ProductOption(name: "color", values: ["Brown", "Black"])
            ]
        ),
        Product(
            id: "bottle-1",
            name: "Thermo Steel Bottle",
            imageURL: URL(string: "https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=900&q=80"),
            vendor: Vendor(id: "vendor-a", name: "BluePeak Sports"),
            price: 32,
            discountPercentage: 6,
            offerEndsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            quantityRemaining: 30,
            summary: "Insulated bottle that keeps drinks cold for long training days.",
            options: [
                ProductOption(name: "color", values: ["Blue", "Black", "White"])
            ]
        )
    ]
}

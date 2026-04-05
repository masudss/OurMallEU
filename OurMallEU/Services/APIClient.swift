import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case badStatusCode(Int)
    case decodingFailed
    case emptyCheckout
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .badStatusCode(let code):
            return "The server request failed with status code \(code)."
        case .decodingFailed:
            return "The response could not be decoded."
        case .emptyCheckout:
            return "Select at least one vendor before continuing to payment."
        case .transport(let message):
            return message
        }
    }
}

protocol CommerceServicing {
    func fetchProducts(page: Int, pageSize: Int) async throws -> ProductPage
    func submitPayment(payload: [String: Any]) async throws -> PaymentResponse
}

struct APIConfiguration {
    let baseURL: URL

    static let live = APIConfiguration(baseURL: URL(string: "https://example.com/api")!)
}

private struct ProductPageDTO: Decodable {
    let items: [ProductDTO]
    let page: Int
    let hasMorePages: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case page
        case hasMorePages = "has_more_pages"
    }
}

final class CommerceAPIClient: CommerceServicing {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        configuration: APIConfiguration = .live,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchProducts(page: Int, pageSize: Int) async throws -> ProductPage {
        var components = URLComponents(url: configuration.baseURL.appending(path: "products"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]

        guard let url = components?.url else {
            throw APIError.invalidResponse
        }

        do {
            let (data, response) = try await session.data(from: url)
            try validate(response)

            if let pageResponse = try? decoder.decode(ProductPageDTO.self, from: data) {
                return ProductPage(
                    items: pageResponse.items.map { $0.toProduct() },
                    page: pageResponse.page,
                    hasMorePages: pageResponse.hasMorePages
                )
            }

            if let flatProducts = try? decoder.decode([ProductDTO].self, from: data) {
                let products = flatProducts.map { $0.toProduct() }
                return ProductPage(items: products, page: page, hasMorePages: products.count >= pageSize)
            }

            throw APIError.decodingFailed
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    func submitPayment(payload: [String: Any]) async throws -> PaymentResponse {
        let url = configuration.baseURL.appending(path: "payments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response)
            return try decoder.decode(PaymentResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.badStatusCode(httpResponse.statusCode)
        }
    }
}

final class PreviewCommerceService: CommerceServicing {
    func fetchProducts(page: Int, pageSize: Int) async throws -> ProductPage {
        try await Task.sleep(for: .milliseconds(250))
        let products = Product.sampleProducts
        let startIndex = max(0, (page - 1) * pageSize)
        guard startIndex < products.count else {
            return ProductPage(items: [], page: page, hasMorePages: false)
        }

        let endIndex = min(products.count, startIndex + pageSize)
        let pageItems = Array(products[startIndex..<endIndex])
        return ProductPage(items: pageItems, page: page, hasMorePages: endIndex < products.count)
    }

    func submitPayment(payload: [String: Any]) async throws -> PaymentResponse {
        try await Task.sleep(for: .milliseconds(600))
        return PaymentResponse(
            orderId: UUID().uuidString,
            paymentReference: "PAY-\(Int.random(in: 1000...9999))",
            status: ItemStatus.pending.rawValue
        )
    }
}

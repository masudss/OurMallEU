# OurMallEU

## Overview
OurMallEU is a SwiftUI multi-vendor ecommerce app prototype. It includes a splash screen, a searchable and filterable product catalog, configurable product detail pages, a multi-vendor cart, checkout and payment flows, and an order history experience with tracking, cancellation, and refund feedback. `AppState` is the central source of truth for products, cart state, checkout totals, payment progress, and stored orders.

## Technologies and Architecture
The project is built with Swift and SwiftUI, and uses Apple’s `Testing` framework for unit tests. Backend work is handled with `async/await`, and the app follows a simple MVVM-style structure: models define the domain layer, views render the UI, `AppState` acts as the shared view model and state container, and `APIClient` handles network communication.

## Structure
`OurMallEUApp.swift` and `ContentView.swift` bootstrap the app and own navigation. The `Models` folder contains the core domain types for products, cart items, vendor sections, orders, and payment payloads. `Services/APIClient.swift` handles product fetches and payment submission. `ViewModels/AppState.swift` contains the core business logic for catalog loading, filtering, cart updates, checkout totals, order persistence, and cancellation. The `Views` folder contains the catalog, product detail, cart, checkout, payment, orders, order details, and splash screens. `OurMallEUTests` contains the unit tests for model and state logic.

## Product List Logic
The product list screen loads catalog data through `AppState.refreshProducts()` and paginates with `loadNextPageIfNeeded(currentProduct:)`. At the top of the screen, users can search by keyword and open filters for category, price range, and stock availability. Below that, the screen displays a rotating carousel and then a two-column product grid. Filtering is driven by shared logic in `AppState`, matching against product name, vendor name, summary, and categories, while category filtering is powered by the `category: [String]` field on `Product`.

## Cart, Multi-Vendor Checkout, and Payment
Cart items are keyed by product id plus selected options, which means the same product with different selected options is stored as separate cart lines. The cart groups items into vendor-based sections so that each vendor can be selected independently for checkout. The cart screen total excludes VAT, while the checkout screen includes VAT and discount calculations. When payment is submitted, the app builds a vendor-grouped request body, simulates payment processing, persists a new order into `successfulOrders`, and clears the purchased cart lines on success.

## Orders, Vendor Split, and Cancellation
Orders remain grouped by vendor end to end through `vendorGroups`, which allows the app to support vendor-based summaries, vendor-level cancellation, and vendor-specific refund handling. The orders screen separates orders into `In progress` and `Settled`, where an in-progress order still has at least one item that is not settled, and a settled order has all items either delivered or cancelled. Cancellation is supported at item level, vendor level, and full-order level. Refund amounts are calculated only for the affected active items, and state is tracked separately at order level (`inProgress`, `settled`) and item level (`pending`, `confirmed`, `shipped`, `delivered`, `cancelled`).

## API Summary
The product endpoint currently uses the base URL `https://mp160a575ce3a6471b72.free.beeceptor.com` and fetches products from `/data`. The response contains a `products` array, and each product includes fields such as `id`, `name`, `category`, `imageURL`, `vendor`, `price`, `discountPercentage`, `offerEndsAt`, `quantityRemaining`, `summary`, `options`, and `status`.

```json
{
  "products": [
    {
      "id": "shoe-1",
      "name": "Aero Runner",
      "category": ["clothing"],
      "imageURL": "https://...",
      "vendor": { "id": "vendor-a", "name": "BluePeak Sports" },
      "price": 120,
      "discountPercentage": 15,
      "offerEndsAt": "2026-04-08T13:00:00Z",
      "quantityRemaining": 8,
      "summary": "Lightweight running shoes...",
      "options": [
        { "name": "size", "values": ["S", "M", "L"] }
      ],
      "status": "PENDING"
    }
  ]
}
```

Add-to-cart is local-only in this prototype and stores product, selected options, and quantity in app state. Payment submission acts as order creation and sends a vendor-grouped payload containing vendor ids, product ids, quantities, unit prices, selected options, and a summary section for subtotal, discount, VAT, and grand total.

```json
{
  "vendors": {
    "vendor-a": [
      {
        "productId": "shoe-1",
        "quantity": 2,
        "unitPrice": 102.0,
        "selectedOptions": { "size": "M", "color": "Red" }
      }
    ]
  },
  "summary": {
    "subtotal": 204.0,
    "discount": 36.0,
    "vat": 15.3,
    "grandTotal": 219.3
  }
}
```

Cancellation is currently local state logic inside `AppState`, but the supported scopes are already clear: item, vendor, and full order. A backend version of the same logic would typically accept an order id plus the cancellation scope, and optionally an item id or vendor id depending on the requested action.

```json
{ "orderId": "order-1", "scope": "item", "itemId": "item-1" }
```

```json
{ "orderId": "order-1", "scope": "vendor", "vendorId": "vendor-a" }
```

```json
{ "orderId": "order-1", "scope": "order" }
```

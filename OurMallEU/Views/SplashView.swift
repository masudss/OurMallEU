import SwiftUI

struct SplashView: View {
    private let brandBlue = Color(red: 0.07, green: 0.35, blue: 0.88)

    var body: some View {
        ZStack {
            brandBlue
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding()
                    .background(.white.opacity(0.16), in: Circle())

                Text("OurMallEU")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Shop trusted vendors in one cart")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(32)
        }
    }
}

#Preview {
    SplashView()
}

import SwiftUI

struct AnimatedLaunchSplashView: View {
    let onFinish: () -> Void

    @State private var rotation = 0.0
    @State private var didStart = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Image("app_ic_loading")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true

            withAnimation(.linear(duration: 6.6).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                onFinish()
            }
        }
    }
}

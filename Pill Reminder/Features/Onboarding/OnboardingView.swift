import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            titleLine1: "Never Miss",
            titleLine2: "a Dose",
            subtitle:
                "Stay on track with your medications.\nSimple reminders and clear daily tracking.",
            heroImageName: "app_bg_onbording_1",
            showsLegal: true
        ),
        OnboardingPage(
            titleLine1: "Your Daily",
            titleLine2: "Medication List",
            subtitle:
                "See what you need to take today.\nMark each dose as taken or skipped in seconds.",
            heroImageName: "app_bg_onbording_2",
            showsLegal: false
        ),
        OnboardingPage(
            titleLine1: "Timely",
            titleLine2: "Reminders",
            subtitle:
                "Get notified exactly when it's time to take your medicine.\nLate doses are automatically marked.",
            heroImageName: "app_bg_onbording_3",
            showsLegal: false
        ),
    ]

    let onFinish: () -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                OnboardingPageView(
                    page: page,
                    currentPage: currentPage,
                    pagesCount: pages.count,
                    continueAction: {
                        if currentPage < pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                currentPage += 1
                            }
                        } else {
                            onFinish()
                        }
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .top)
        .background(Color(hex: "#F2F2F2").ignoresSafeArea())
    }
}

private struct OnboardingPageView: View {
    @Environment(\.openURL) private var openURL

    let page: OnboardingPage
    let currentPage: Int
    let pagesCount: Int
    let continueAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let longestSide = max(proxy.size.width, proxy.size.height)
            let isSEDevice = longestSide <= 667
            let titleSize: CGFloat = isSEDevice ? 30 : 36
            let subtitleSize: CGFloat = isSEDevice ? 14 : 16

            VStack(spacing: 0) {
                OnboardingHeroView(imageName: page.heroImageName)
                    .frame(width: proxy.size.width)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: -topInset)
                    .padding(.bottom, -topInset)

                VStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(page.titleLine1)
                            .font(.system(size: titleSize, weight: .heavy))
                            .foregroundStyle(Color(hex: "FF0A3D"))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        Text(page.titleLine2)
                            .font(.system(size: titleSize, weight: .heavy))
                            .foregroundStyle(Color(hex: "687286"))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }

                    Text(page.subtitle)
                        .font(.system(size: subtitleSize, weight: .regular))
                        .foregroundStyle(Color(hex: "3B4353"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .padding(.top, 12)
                        .padding(.horizontal, 26)
                }
                .padding(.top, isSEDevice ? 8 : 14)
                .padding(.bottom, isSEDevice ? 16 : 20)

                paginationDots
                bottomFixedArea
                    .padding(.bottom, 5)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .bottom
            )
            .clipped()
        }
        .ignoresSafeArea(edges: .top)
    }

    private var paginationDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<pagesCount, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentPage
                            ? Color(hex: "FF0A3D") : Color(hex: "A4AEBA")
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.bottom, 16)
    }

    private var bottomFixedArea: some View {
        VStack(spacing: 0) {
            Button(action: continueAction) {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: "FF2450"), Color(hex: "FF002B"),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: Color(hex: "FF0A3D").opacity(0.25),
                        radius: 8,
                        y: 3
                    )
            }
            .padding(.horizontal, 26)

            if page.showsLegal {
                VStack(spacing: 2) {
                    Text("By Proceeding You Accept")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "99A1AF"))

                    HStack(spacing: 4) {
                        Text("Our")
                        Button("Terms Of Use") {
                            openURL(AppConstants.Links.termsOfUse)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(hex: "FF002B"))
                        Text("And")
                        Button("Privacy Policy") {
                            openURL(AppConstants.Links.privacyPolicy)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(hex: "FF002B"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "99A1AF"))
                }
                .padding(.top, 12)
            } else {
                Color.clear.frame(height: 40)
            }
        }

    }
}

private struct OnboardingHeroView: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottom
            )
            .clipped()

    }
}

struct OnboardingPage {
    let titleLine1: String
    let titleLine2: String
    let subtitle: String
    let heroImageName: String
    let showsLegal: Bool
}

#Preview("Onboarding") {
    OnboardingView(onFinish: {})
}

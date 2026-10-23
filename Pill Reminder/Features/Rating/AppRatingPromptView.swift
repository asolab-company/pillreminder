import SwiftUI

struct AppRatingPromptView: View {
    let onClose: () -> Void
    let onSubmit: (Int) -> Void

    @State private var selectedStars = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(hex: "F8F8FA"))
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color(hex: "E7E8ED"), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "F1F3F6"))
                            Circle()
                                .stroke(Color(hex: "FFD5DF"), lineWidth: 1)
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(hex: "8C94A3"))
                        }
                        .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
                .overlay {
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "FF0A3D"), Color(hex: "FF0052")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .shadow(color: Color(hex: "FF0A3D").opacity(0.25), radius: 6, y: 3)

                            Image(systemName: "star.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("Enjoying the app?")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(hex: "273043"))

                        Text("Your feedback helps us improve and create a\nbetter experience for everyone")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color(hex: "7C8596"))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { index in
                                Button {
                                    selectedStars = index
                                } label: {
                                    Image(systemName: selectedStars >= index ? "star.fill" : "star")
                                        .font(.system(size: 30, weight: .medium))
                                        .foregroundStyle(selectedStars >= index ? Color(hex: "FF0A3D") : Color(hex: "9EA7B6"))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)

                        Button {
                            onSubmit(selectedStars)
                        } label: {
                            Text("Submit Rating")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color(hex: "FF0A3D").opacity(0.25), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedStars == 0)
                        .opacity(selectedStars == 0 ? 0.65 : 1)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 24)
                }
                .frame(maxWidth: 360)
                .frame(height: 360)
                .padding(.horizontal, 20)
        }
    }
}

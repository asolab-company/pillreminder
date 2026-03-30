import UIKit

@MainActor
enum DeviceSize {
    static var longestSide: CGFloat {
        max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    }

    static var isSmallDevice: Bool {
        longestSide <= 812
    }

    static var isExtraSmallDevice: Bool {
        longestSide <= 667
    }
}

import SwiftUI

struct DeviceSize {
    let size: CGSize

    var longestSide: CGFloat {
        max(size.width, size.height)
    }

    var isSmallDevice: Bool {
        longestSide <= 812
    }

    var isExtraSmallDevice: Bool {
        longestSide <= 667
    }
}

extension EnvironmentValues {
    @Entry var deviceSize = DeviceSize(size: .zero)
}

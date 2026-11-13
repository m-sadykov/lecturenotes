import SwiftUI

/// Icon in a filled circle for toolbar buttons, matching the settings button on the
/// home screen. Use with `hiddenSharedBackground()` on the toolbar item so
/// the system glass background does not wrap the circle.
struct ToolbarCircleIcon: View {
    let systemImage: String

    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(AppColor.fillSubtle)
            .clipShape(.circle)
            .contentShape(.circle)
    }
}

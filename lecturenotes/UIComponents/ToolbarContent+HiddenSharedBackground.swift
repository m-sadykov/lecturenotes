import SwiftUI

extension ToolbarContent {
    /// Removes the iOS 26 glass background the system draws behind toolbar items, so a
    /// custom background such as `ToolbarCircleIcon` shows as is. Earlier iOS versions
    /// draw no such background, so the content is returned unchanged.
    @ToolbarContentBuilder
    func hiddenSharedBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

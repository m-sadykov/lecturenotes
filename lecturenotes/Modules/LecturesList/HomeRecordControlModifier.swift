import SwiftUI

/// Places the record button on the home screen.
///
/// On iOS 26 and later the button sits in the bottom toolbar next to the system search field,
/// which keeps the screen's two main actions in one bar. Earlier systems keep the floating button.
struct HomeRecordControlModifier: ViewModifier {
    /// Hides the control while the mini recorder, the AI consent card or a sheet covers the bottom of the screen.
    let isHidden: Bool
    let onRecord: () -> Void

    @State private var feedbackTrigger = 0

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .toolbar {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)

                    ToolbarSpacer(.fixed, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        Button("Record", systemImage: "mic.fill", action: record)
                            .buttonStyle(.glassProminent)
                            .tint(AppColor.ink)
                    }
                }
                .toolbarVisibility(isHidden ? .hidden : .visible, for: .bottomBar)
                .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
        } else {
            content
                .overlay(alignment: .bottomTrailing) {
                    if !isHidden {
                        FloatingRecordButton(action: onRecord)
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
        }
    }

    private func record() {
        feedbackTrigger += 1
        onRecord()
    }
}

extension View {
    func homeRecordControl(isHidden: Bool, onRecord: @escaping () -> Void) -> some View {
        modifier(HomeRecordControlModifier(isHidden: isHidden, onRecord: onRecord))
    }
}

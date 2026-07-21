import SwiftUI

struct FloatingRecordButton: View {
    let action: () -> Void
    @State private var feedbackTrigger = 0

    var body: some View {
        Button {
            feedbackTrigger += 1
            action()
        } label: {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(AppColor.onInk)
                .frame(width: 72, height: 72)
                .background(AppColor.ink)
                .clipShape(.circle)
                .shadow(color: AppColor.shadow, radius: 8)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    }
}

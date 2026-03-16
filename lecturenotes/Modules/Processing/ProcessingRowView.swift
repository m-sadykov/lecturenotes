import SwiftUI

struct ProcessingRowView: View {
    enum State {
        case idle
        case active
        case completed
    }

    let label: String
    let state: State

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            switch state {
            case .idle:
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            case .active:
                ProgressView()
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

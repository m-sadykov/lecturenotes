import SwiftUI

struct ProcessingRowView: View {
    let label: String
    let isActive: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if isActive {
                ProgressView()
            }
        }
    }
}

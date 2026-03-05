import SwiftUI

struct FlashcardCardView: View {
    let text: String

    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding()
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 16))
    }
}

import SwiftUI

struct PaywallView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Free") {
                    Text("3 lectures per month")
                    Text("10 minutes max per lecture")
                    Text("Summary + Outline")
                }

                Section("Pro") {
                    Text("$4.99 / month")
                    Text("50 lectures per month")
                    Text("60 minutes max per lecture")
                    Text("Flashcards + Quiz + Glossary")
                }

                Section {
                    Button("Upgrade to Pro", systemImage: "crown.fill") {}
                        .buttonStyle(.borderedProminent)
                    Button("Restore Purchases", systemImage: "arrow.clockwise") {}
                        .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Subscription")
        }
    }
}

#Preview {
    PaywallView()
}

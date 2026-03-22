import Foundation

struct SupportEmailDraft: Identifiable {
    let recipient: String
    let subject: String
    let body: String

    var id: String {
        "\(recipient)|\(subject)"
    }

    var mailtoURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        return components.url ?? URL(string: "mailto:\(recipient)")!
    }
}

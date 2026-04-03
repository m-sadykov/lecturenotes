import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case arabic = "ar"
    case catalan = "ca"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case finnish = "fi"
    case french = "fr"
    case german = "de"
    case greek = "el"
    case hebrew = "he"
    case hindi = "hi"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case malay = "ms"
    case norwegianBokmal = "nb"
    case polish = "pl"
    case portuguese = "pt"
    case romanian = "ro"
    case russian = "ru"
    case simplifiedChinese = "zh-Hans"
    case slovak = "sk"
    case spanish = "es"
    case swedish = "sv"
    case thai = "th"
    case traditionalChinese = "zh-Hant"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"

    var id: String {
        rawValue
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .arabic, .hebrew:
            .rightToLeft
        default:
            .leftToRight
        }
    }

    var nativeName: String {
        switch self {
        case .english:
            "English"
        case .arabic:
            "العربية"
        case .catalan:
            "Català"
        case .croatian:
            "Hrvatski"
        case .czech:
            "Čeština"
        case .danish:
            "Dansk"
        case .dutch:
            "Nederlands"
        case .finnish:
            "Suomi"
        case .french:
            "Français"
        case .german:
            "Deutsch"
        case .greek:
            "Ελληνικά"
        case .hebrew:
            "עברית"
        case .hindi:
            "हिन्दी"
        case .hungarian:
            "Magyar"
        case .indonesian:
            "Bahasa Indonesia"
        case .italian:
            "Italiano"
        case .japanese:
            "日本語"
        case .korean:
            "한국어"
        case .malay:
            "Bahasa Melayu"
        case .norwegianBokmal:
            "Norsk Bokmål"
        case .polish:
            "Polski"
        case .portuguese:
            "Português"
        case .romanian:
            "Română"
        case .russian:
            "Русский"
        case .simplifiedChinese:
            "简体中文"
        case .slovak:
            "Slovenčina"
        case .spanish:
            "Español"
        case .swedish:
            "Svenska"
        case .thai:
            "ไทย"
        case .traditionalChinese:
            "繁體中文"
        case .turkish:
            "Türkçe"
        case .ukrainian:
            "Українська"
        case .vietnamese:
            "Tiếng Việt"
        }
    }

    var englishName: String {
        switch self {
        case .english:
            "English"
        case .arabic:
            "Arabic"
        case .catalan:
            "Catalan"
        case .croatian:
            "Croatian"
        case .czech:
            "Czech"
        case .danish:
            "Danish"
        case .dutch:
            "Dutch"
        case .finnish:
            "Finnish"
        case .french:
            "French"
        case .german:
            "German"
        case .greek:
            "Greek"
        case .hebrew:
            "Hebrew"
        case .hindi:
            "Hindi"
        case .hungarian:
            "Hungarian"
        case .indonesian:
            "Indonesian"
        case .italian:
            "Italian"
        case .japanese:
            "Japanese"
        case .korean:
            "Korean"
        case .malay:
            "Malay"
        case .norwegianBokmal:
            "Norwegian Bokmål"
        case .polish:
            "Polish"
        case .portuguese:
            "Portuguese"
        case .romanian:
            "Romanian"
        case .russian:
            "Russian"
        case .simplifiedChinese:
            "Simplified Chinese"
        case .slovak:
            "Slovak"
        case .spanish:
            "Spanish"
        case .swedish:
            "Swedish"
        case .thai:
            "Thai"
        case .traditionalChinese:
            "Traditional Chinese"
        case .turkish:
            "Turkish"
        case .ukrainian:
            "Ukrainian"
        case .vietnamese:
            "Vietnamese"
        }
    }

    static func systemPreferred(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        let supportedLanguages = Self.allCases.map(\.rawValue)
        let preferredLanguage = Bundle.preferredLocalizations(
            from: supportedLanguages,
            forPreferences: preferredLanguages
        ).first

        return preferredLanguage.flatMap(Self.init(rawValue:)) ?? .english
    }
}

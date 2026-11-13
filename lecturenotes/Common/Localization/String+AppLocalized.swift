import Foundation

extension String {
    /// Like `String(localized:)`, but resolved in the in-app language when one is set.
    ///
    /// `String(localized:)` skips the `Bundle.main` override from `Bundle.setAppLanguage`,
    /// so its strings come out in the system language. This looks the key up in the
    /// selected language's `.lproj` bundle with that language's locale, which also picks
    /// the right plural forms.
    nonisolated init(appLocalized value: String.LocalizationValue) {
        guard let languageBundle = Bundle.appLanguageBundle else {
            self.init(localized: value)
            return
        }

        let languageCode = languageBundle.bundleURL.deletingPathExtension().lastPathComponent
        self.init(localized: value, bundle: languageBundle, locale: Locale(identifier: languageCode))
    }
}

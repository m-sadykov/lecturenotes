import Foundation
import ObjectiveC.runtime

private var localizedBundleAssociationKey: UInt8 = 0

extension Bundle {
    static func setAppLanguage(_ language: AppLanguage?) {
        object_setClass(Bundle.main, LocalizedBundle.self)

        guard let language else {
            objc_setAssociatedObject(
                Bundle.main,
                &localizedBundleAssociationKey,
                nil,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return
        }

        let preferredLocalization = Bundle.main.path(forResource: language.rawValue, ofType: "lproj")
        let languageCode = language.rawValue.split(separator: "-").first.map(String.init)
        let fallbackLocalization = languageCode.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
        let bundlePath = preferredLocalization ?? fallbackLocalization

        let localizedBundle = bundlePath.flatMap(Bundle.init(path:))
        objc_setAssociatedObject(
            Bundle.main,
            &localizedBundleAssociationKey,
            localizedBundle,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let localizedBundle = objc_getAssociatedObject(
            self,
            &localizedBundleAssociationKey
        ) as? Bundle

        return localizedBundle?.localizedString(forKey: key, value: value, table: tableName)
            ?? super.localizedString(forKey: key, value: value, table: tableName)
    }
}

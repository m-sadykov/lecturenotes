import SwiftUI
import UIKit

enum AppInterfaceLayoutDirection {
    static func apply(for language: AppLanguage) {
        let semanticContentAttribute: UISemanticContentAttribute = switch language.layoutDirection {
        case .rightToLeft:
            .forceRightToLeft
        case .leftToRight:
            .forceLeftToRight
        @unknown default:
            .unspecified
        }

        UIView.appearance().semanticContentAttribute = semanticContentAttribute
        UINavigationBar.appearance().semanticContentAttribute = semanticContentAttribute
        UITableView.appearance().semanticContentAttribute = semanticContentAttribute
        UICollectionView.appearance().semanticContentAttribute = semanticContentAttribute
        UITextField.appearance().semanticContentAttribute = semanticContentAttribute
        UISearchBar.appearance().semanticContentAttribute = semanticContentAttribute
        UITextView.appearance().semanticContentAttribute = semanticContentAttribute

        for windowScene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in windowScene.windows {
                apply(semanticContentAttribute, to: window)
            }
        }
    }

    private static func apply(_ semanticContentAttribute: UISemanticContentAttribute, to window: UIWindow) {
        window.semanticContentAttribute = semanticContentAttribute
        window.rootViewController.map {
            apply(semanticContentAttribute, to: $0)
        }
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }

    private static func apply(_ semanticContentAttribute: UISemanticContentAttribute, to viewController: UIViewController) {
        viewController.view.semanticContentAttribute = semanticContentAttribute

        for child in viewController.children {
            apply(semanticContentAttribute, to: child)
        }

        if let presentedViewController = viewController.presentedViewController {
            apply(semanticContentAttribute, to: presentedViewController)
        }

        if let navigationController = viewController as? UINavigationController {
            navigationController.navigationBar.semanticContentAttribute = semanticContentAttribute
            for child in navigationController.viewControllers {
                apply(semanticContentAttribute, to: child)
            }
        }

        if let tabBarController = viewController as? UITabBarController {
            tabBarController.tabBar.semanticContentAttribute = semanticContentAttribute
            for child in tabBarController.viewControllers ?? [] {
                apply(semanticContentAttribute, to: child)
            }
        }

        apply(semanticContentAttribute, to: viewController.view)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }

    private static func apply(_ semanticContentAttribute: UISemanticContentAttribute, to view: UIView) {
        view.semanticContentAttribute = semanticContentAttribute

        for subview in view.subviews {
            apply(semanticContentAttribute, to: subview)
        }
    }
}

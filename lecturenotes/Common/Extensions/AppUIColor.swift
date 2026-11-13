import UIKit

enum AppUIColor {
    static let hairline = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.05)
    }

    static let fillSubtle = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.05)
    }

    static let fillElevated = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.22)
            : UIColor.black.withAlphaComponent(0.06)
    }

    static let ink = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    }

    static let onInk = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    }

    static let surface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : .white
    }

    /// Highlight color for headings and icons in generated study notes: brand purple in
    /// light mode, and plain white in dark mode to match the app's monochrome dark theme.
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0.420, green: 0.357, blue: 0.886, alpha: 1)
    }

    static let overlayScrim = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.16)
    }

    static let shadow = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.12)
    }
}

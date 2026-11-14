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

    /// Highlight color for headings, icons and controls on the lecture detail screen.
    /// Monochrome to match the rest of the app: black in light mode, white in dark mode.
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
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

//
//  SplashScreenView.swift
//  lecturenotes
//
//  Created by Marat Sadykov on 22.03.2026.
//

import SwiftUI
import UIKit

/// Launch splash: the app icon centered on black while startup work finishes.
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            appIcon
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .clipShape(.rect(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                .accessibilityHidden(true)
        }
    }

    private var appIcon: Image {
        if let uiImage = AppIconProvider.image {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "AppIcon")
    }
}

private enum AppIconProvider {
    static var image: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primary["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last
        else {
            return nil
        }

        return UIImage(named: iconName)
    }
}

#Preview {
    SplashScreenView()
}

//
//  SplashScreenView.swift
//  lecturenotes
//
//  Created by Marat Sadykov on 22.03.2026.
//

import SwiftUI
import UIKit

struct SplashScreenView: View {
    let progress: Double

    var body: some View {
        ZStack {
//            AppBackgroundView()
            Color(.systemGray6)
                .ignoresSafeArea()


            VStack {
                Spacer()

                appIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)

                Spacer()

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color.black)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    .frame(width: 180)
            }
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
    SplashScreenView(progress: 0.5)
}

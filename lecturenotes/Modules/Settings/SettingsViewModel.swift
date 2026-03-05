import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var selectedLanguage = "English"
    var deleteAudioAfterProcessing = false

    let languages = ["English", "Русский", "Қазақша"]
}

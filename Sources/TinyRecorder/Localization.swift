import Foundation

/// One resource lookup for both AppKit strings and SwiftUI's dynamic labels.
/// Language follows macOS (including its per-app language preference).
enum L10n {
    static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        // build.sh embeds SwiftPM's resource bundle inside the app. Resolve it
        // there first so moving the app never depends on the build directory.
        if let url = Bundle.main.url(forResource: "TinyRecorder_TinyRecorder", withExtension: "bundle"),
           let resources = Bundle(url: url) {
            return resources
        }
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }()

    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    /// Plural rules belong to the language, not an English "s" suffix in code.
    static func count(_ key: String, _ value: Int) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        // Plural grammar follows the app language, which may differ from
        // the region/number-format locale (for example English UI in China).
        let locale = Locale(identifier: bundle.preferredLocalizations.first ?? "en")
        return String(format: format, locale: locale, arguments: [value])
    }
}

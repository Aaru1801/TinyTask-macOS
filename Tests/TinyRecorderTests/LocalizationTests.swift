import XCTest
@testable import TinyRecorder

final class LocalizationTests: XCTestCase {
    private func languageBundle(_ language: String) throws -> Bundle {
        // SwiftPM normalizes localization directory names to lowercase.
        let name = try XCTUnwrap(L10n.bundle.localizations.first {
            $0.caseInsensitiveCompare(language) == .orderedSame
        })
        let url = L10n.bundle.bundleURL.appendingPathComponent(name + ".lproj")
        return try XCTUnwrap(Bundle(url: url))
    }

    private func strings(_ bundle: Bundle) throws -> [String: String] {
        let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }

    func testBothCatalogsHaveIdenticalKeysAndFormatArguments() throws {
        let english = try strings(languageBundle("en"))
        let chinese = try strings(languageBundle("zh-Hans"))
        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        XCTAssertGreaterThan(english.count, 400)
        let placeholders = try NSRegularExpression(pattern: #"%(?:[0-9]+\$)?(?:\.[0-9]+)?(?:@|ld|d|f)"#)
        for key in english.keys {
            func formats(_ text: String) -> [String] {
                let range = NSRange(text.startIndex..., in: text)
                return placeholders.matches(in: text, range: range).map {
                    String(text[Range($0.range, in: text)!])
                }.sorted()
            }
            XCTAssertEqual(formats(english[key]!), formats(chinese[key]!), key)
        }
    }

    func testChineseLabelsAndEnglishFallback() throws {
        let chinese = try languageBundle("zh-Hans")
        XCTAssertEqual(chinese.localizedString(forKey: "Record", value: nil, table: nil), "录制")
        XCTAssertEqual(chinese.localizedString(forKey: "Input Monitoring", value: nil, table: nil), "输入监控")
        let english = try languageBundle("en")
        XCTAssertEqual(english.localizedString(forKey: "Record", value: nil, table: nil), "Record")
        XCTAssertEqual(L10n.text("Untranslated fallback"), "Untranslated fallback")
    }

    func testInterpolatedValuesAreNotUsedAsFormatStrings() throws {
        let chinese = try languageBundle("zh-Hans")
        let format = chinese.localizedString(forKey: "Export %@", value: nil, table: nil)
        XCTAssertEqual(String(format: format, "100% %@ 宏"), "导出 100% %@ 宏")
        let progress = chinese.localizedString(forKey: "%@%% done — %@", value: nil, table: nil)
        XCTAssertEqual(String(format: progress, "50", "剩余 1 秒"), "已完成 50% — 剩余 1 秒")
    }

    func testPluralRulesForZeroOneAndMany() throws {
        let english = try languageBundle("en")
        let chinese = try languageBundle("zh-Hans")
        for (count, expected) in [(0, "0 saved macros"), (1, "1 saved macro"), (2, "2 saved macros")] {
            let en = english.localizedString(forKey: "saved_macros", value: nil, table: nil)
            let zh = chinese.localizedString(forKey: "saved_macros", value: nil, table: nil)
            XCTAssertEqual(String(format: en, locale: Locale(identifier: "en"), arguments: [count]), expected)
            XCTAssertEqual(String(format: zh, locale: Locale(identifier: "zh-Hans"), arguments: [count]), "\(count) 个已保存的宏")
        }
    }

    func testStoredAccentNamesAndMacroSyntaxStayLanguageIndependent() throws {
        XCTAssertEqual(accentNames.first, "Red")
        let source = "TINYRECORDER 1\nKEYDOWN A\nKEYUP A\n"
        let imported = try TextMacroFormat.parse(source)
        XCTAssertEqual(imported.events.count, 2)
        XCTAssertTrue(TextMacroFormat.export(imported.events).contains("KEYDOWN A"))
    }
}

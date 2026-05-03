import Foundation
import Combine

/// A saved macro entry in the library.
struct SavedMacro: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var events: [RecordedEvent]
    var createdAt: Date
    var modifiedAt: Date
    var version: Int = 2
    /// How many times to replay. 0 = continuous (infinite).
    var loops: Int = 1

    var duration: TimeInterval { events.last?.time ?? 0 }
    var eventCount: Int { events.count }
    var clickCount: Int {
        events.filter { $0.kind == .leftMouseDown || $0.kind == .rightMouseDown || $0.kind == .otherMouseDown }.count
    }
    var keyCount: Int { events.filter { $0.kind.isKey }.count }
    var scrollCount: Int { events.filter { $0.kind == .scrollWheel }.count }

    enum CodingKeys: String, CodingKey {
        case id, name, events, createdAt, modifiedAt, version, loops
    }

    init(id: UUID, name: String, events: [RecordedEvent],
         createdAt: Date, modifiedAt: Date, version: Int = 2, loops: Int = 1) {
        self.id = id
        self.name = name
        self.events = events
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
        self.loops = loops
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.events = try c.decode([RecordedEvent].self, forKey: .events)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 2
        self.loops = try c.decodeIfPresent(Int.self, forKey: .loops) ?? 1
    }
}

/// On-disk representation of the whole library.
private struct LibraryData: Codable {
    var macros: [SavedMacro]
    var currentMacroID: UUID?
    var version: Int = 1
}

/// The user's saved macros. Auto-persists to Application Support.
final class MacroLibrary: ObservableObject {
    @Published private(set) var macros: [SavedMacro] = []
    @Published var currentMacroID: UUID?

    var currentMacro: SavedMacro? {
        guard let id = currentMacroID else { return nil }
        return macros.first { $0.id == id }
    }

    private static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("TinyRecorder", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("library.json")
    }

    init() { load() }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode(LibraryData.self, from: data) else {
            return
        }
        self.macros = decoded.macros
        self.currentMacroID = decoded.currentMacroID
    }

    func save() {
        let data = LibraryData(macros: macros, currentMacroID: currentMacroID)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        guard let encoded = try? enc.encode(data) else { return }
        try? encoded.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - Mutations

    @discardableResult
    func add(events: [RecordedEvent], name: String? = nil, loops: Int = 1) -> SavedMacro {
        let n = (name?.isEmpty == false) ? name! : autoName()
        let m = SavedMacro(
            id: UUID(),
            name: n,
            events: events,
            createdAt: Date(),
            modifiedAt: Date(),
            loops: loops
        )
        macros.insert(m, at: 0)
        currentMacroID = m.id
        save()
        return m
    }

    func setLoops(id: UUID, loops: Int) {
        guard let idx = macros.firstIndex(where: { $0.id == id }) else { return }
        macros[idx].loops = max(0, loops)
        macros[idx].modifiedAt = Date()
        save()
    }

    func updateEvents(id: UUID, events: [RecordedEvent]) {
        guard let idx = macros.firstIndex(where: { $0.id == id }) else { return }
        macros[idx].events = events
        macros[idx].modifiedAt = Date()
        save()
    }

    func rename(id: UUID, to name: String) {
        guard let idx = macros.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        macros[idx].name = trimmed.isEmpty ? "Untitled" : trimmed
        macros[idx].modifiedAt = Date()
        save()
    }

    func delete(id: UUID) {
        macros.removeAll { $0.id == id }
        if currentMacroID == id {
            currentMacroID = macros.first?.id
        }
        save()
    }

    func duplicate(id: UUID) {
        guard let src = macros.first(where: { $0.id == id }) else { return }
        let copy = SavedMacro(
            id: UUID(),
            name: src.name + " copy",
            events: src.events,
            createdAt: Date(),
            modifiedAt: Date(),
            loops: src.loops
        )
        if let idx = macros.firstIndex(where: { $0.id == id }) {
            macros.insert(copy, at: idx + 1)
        } else {
            macros.insert(copy, at: 0)
        }
        save()
    }

    func select(id: UUID) {
        currentMacroID = id
        save()
    }

    // MARK: - Helpers

    private func autoName() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d · HH:mm"
        return "Macro " + f.string(from: Date())
    }
}

// MARK: - Relative-time helper

enum RelativeTime {
    static func string(from date: Date) -> String {
        let s = -date.timeIntervalSinceNow
        if s < 60 { return "just now" }
        if s < 3600 { return "\(Int(s / 60))m ago" }
        if s < 86_400 { return "\(Int(s / 3600))h ago" }
        if s < 604_800 { return "\(Int(s / 86_400))d ago" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

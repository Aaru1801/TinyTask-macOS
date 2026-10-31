import SwiftUI
import AppKit

/// Keyboard-first search for launching macros and common actions
/// without leaving the keyboard. It deliberately floats above both the compact
/// popover and full library so the interaction model stays identical everywhere.
struct QuickRunPalette: View {
    let controller: MenuBarController
    var compact = false
    let onDismiss: () -> Void

    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var library: MacroLibrary

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var queryFocused: Bool

    private enum Action {
        case macro(UUID)
        case record
        case play
        case importFile
        case edit
        case settings
    }

    private struct Entry: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let tint: Color
        let action: Action
        var trailing: String? = nil
        var searchText: String = ""
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                searchHeader
                Divider()
                resultsList
                Divider()
                keyboardFooter
            }
            .frame(maxWidth: compact ? 370 : 520)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.20), radius: 24, y: 10)
            .padding(.horizontal, compact ? 14 : 24)
        }
        .onAppear {
            selectedIndex = 0
            DispatchQueue.main.async { queryFocused = true }
        }
        .onChange(of: query) {
            selectedIndex = 0
        }
        .onChange(of: entries.count) { _, count in
            selectedIndex = max(0, min(selectedIndex, max(0, count - 1)))
        }
        .onExitCommand(perform: onDismiss)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Quick Run"))
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)

            TextField(L10n.text("Search macros and commands"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: compact ? 14 : 15))
                .focused($queryFocused)
                .onSubmit(activateSelected)
                .onMoveCommand { direction in
                    switch direction {
                    case .down: moveSelection(by: 1)
                    case .up: moveSelection(by: -1)
                    default: break
                    }
                }

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Clear Quick Run search"))
            }

            KeyCapView(text: "esc", size: .sm)
        }
        .padding(.horizontal, 16)
        .frame(height: compact ? 56 : 62)
    }

    @ViewBuilder
    private var resultsList: some View {
        if entries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
                Text(L10n.text("No match for “%@”", String(describing: query)))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(L10n.text("Try a macro name, tag, or command."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            resultRow(entry, selected: index == selectedIndex)
                                .id(entry.id)
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: compact ? 292 : 336)
                .onChange(of: selectedIndex) { _, index in
                    guard entries.indices.contains(index) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(entries[index].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func resultRow(_ entry: Entry, selected: Bool) -> some View {
        Button { activate(entry) } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(entry.tint)
                    .frame(width: 26, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(entry.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
                if let trailing = entry.trailing {
                    Text(trailing)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                Image(systemName: "return")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(height: compact ? 52 : 56)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(selected ? 0.08 : 0), lineWidth: 0.5)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(entry.title), \(entry.subtitle)" +
                (entry.trailing.map { ", \($0)" } ?? "")
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var keyboardFooter: some View {
        HStack(spacing: 12) {
            keyboardHint("↑↓", L10n.text("Navigate"))
            keyboardHint("↵", L10n.text("Run"))
            Spacer()
            Text(query.isEmpty ? L10n.text("Recent & favorites") : L10n.text("Search results"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
    }

    private func keyboardHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            KeyCapView(text: key, size: .sm)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var entries: [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let commands = commandEntries.filter {
            trimmed.isEmpty || fuzzyScore(trimmed, in: $0.title + " " + $0.subtitle) != nil
        }

        let orderedMacros = library.macros.sorted { lhs, rhs in
            if lhs.favorite != rhs.favorite { return lhs.favorite }
            return (lhs.lastPlayedAt ?? lhs.modifiedAt) > (rhs.lastPlayedAt ?? rhs.modifiedAt)
        }
        let macros: [SavedMacro]
        if trimmed.isEmpty {
            macros = Array(orderedMacros.prefix(compact ? 5 : 6))
        } else {
            macros = orderedMacros
                .compactMap { macro -> (SavedMacro, Int)? in
                    let haystack = ([macro.name, macro.notes] + macro.tags).joined(separator: " ")
                    return fuzzyScore(trimmed, in: haystack).map { (macro, $0) }
                }
                .sorted { $0.1 > $1.1 }
                .map(\.0)
        }

        let macroEntries = macros.map { macro in
            Entry(
                id: "macro-\(macro.id.uuidString)",
                title: macro.name,
                subtitle: L10n.text("%@ events · %@", String(describing: macro.eventCount), String(describing: quickDuration(macro.duration))) +
                    (macro.tags.isEmpty ? "" : " · \(macro.tags.prefix(2).joined(separator: ", "))"),
                symbol: macro.icon ?? "wave.3.right",
                tint: cardAccentColor(for: macro.accent),
                action: .macro(macro.id),
                trailing: macro.loops <= 0 ? "∞" : (macro.loops > 1 ? "×\(macro.loops)" : nil),
                searchText: ([macro.name, macro.notes] + macro.tags).joined(separator: " ")
            )
        }

        let combined = macroEntries + commands
        guard !trimmed.isEmpty else { return combined }
        return combined.sorted { lhs, rhs in
            let lhsScore = fuzzyScore(trimmed, in: lhs.title + " " + lhs.subtitle + " " + lhs.searchText) ?? Int.min
            let rhsScore = fuzzyScore(trimmed, in: rhs.title + " " + rhs.subtitle + " " + rhs.searchText) ?? Int.min
            return lhsScore > rhsScore
        }
    }

    private var commandEntries: [Entry] {
        var commands: [Entry] = [
            Entry(
                id: "command-record",
                title: state.recordingCountdownActive ? L10n.text("Cancel Recording") : (recorder.isRecording ? L10n.text("Stop & Save Recording") : L10n.text("Start Recording")),
                subtitle: recorder.isRecording ? L10n.text("Finish the live capture safely") : L10n.text("Capture mouse and keyboard input"),
                symbol: recorder.isRecording ? "stop.fill" : "record.circle",
                tint: Brand.red500,
                action: .record,
                trailing: state.recordHotkey.name
            ),
            Entry(
                id: "command-import",
                title: L10n.text("Import Macro…"),
                subtitle: L10n.text("TinyRecorder, TinyTask, JSON, or text"),
                symbol: "square.and.arrow.down",
                tint: .secondary,
                action: .importFile,
                trailing: "⌘O"
            ),
        ]
        if player.isPlaying || !recorder.events.isEmpty {
            commands.insert(Entry(
                id: "command-play",
                title: player.isPlaying ? L10n.text("Stop Playback") : L10n.text("Play Current Macro"),
                subtitle: library.currentMacro?.name ?? L10n.text("Replay the current event buffer"),
                symbol: player.isPlaying ? "stop.fill" : "play.fill",
                tint: player.isPlaying ? Brand.red500 : .secondary,
                action: .play,
                trailing: player.isPlaying ? state.stopHotkey.name : state.playHotkey.name
            ), at: 1)
        }
        if library.currentMacro != nil {
            commands.append(Entry(
                id: "command-edit",
                title: L10n.text("Open Current in Editor"),
                subtitle: library.currentMacro?.name ?? L10n.text("Current macro"),
                symbol: "slider.horizontal.below.rectangle",
                tint: .secondary,
                action: .edit,
                trailing: "⌥⌘E"
            ))
        }
        commands.append(Entry(
            id: "command-settings",
            title: L10n.text("Settings…"),
            subtitle: L10n.text("Hotkeys, capture, playback, and appearance"),
            symbol: "gearshape.fill",
            tint: .secondary,
            action: .settings,
            trailing: "⌘,"
        ))
        return commands
    }

    private func moveSelection(by delta: Int) {
        guard !entries.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + entries.count) % entries.count
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func activateSelected() {
        guard entries.indices.contains(selectedIndex) else { return }
        activate(entries[selectedIndex])
    }

    private func activate(_ entry: Entry) {
        onDismiss()
        DispatchQueue.main.async {
            switch entry.action {
            case .macro(let id): controller.playMacroByID(id)
            case .record: controller.toggleRecording()
            case .play:
                if player.isPlaying { controller.stopAll() }
                else { controller.play() }
            case .importFile: controller.open()
            case .edit: controller.openEditor()
            case .settings: controller.showSettingsWindow()
            }
        }
    }

    /// Compact subsequence matcher with adjacency/word-start bonuses. It feels
    /// forgiving like Spotlight while keeping deterministic, dependency-free UI.
    private func fuzzyScore(_ needle: String, in haystack: String) -> Int? {
        let needle = Array(needle.lowercased())
        let haystack = Array(haystack.lowercased())
        guard !needle.isEmpty else { return 0 }

        var score = 0
        var cursor = 0
        var previousMatch: Int?
        for (needleIndex, character) in needle.enumerated() {
            guard cursor <= haystack.count else { return nil }
            guard let relative = haystack[cursor...].firstIndex(of: character) else { return nil }
            let index = relative
            score += 10
            if let previousMatch, index == previousMatch + 1 { score += 9 }
            if index == 0 || haystack[index - 1].isWhitespace { score += 6 }
            score -= min(4, index - cursor)
            previousMatch = index
            cursor = index + 1
            if needleIndex < needle.count - 1, cursor >= haystack.count { return nil }
        }
        return score - max(0, haystack.count - needle.count) / 12
    }

    private func quickDuration(_ seconds: TimeInterval) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        if safe < 10 { return L10n.text("%.1fs", safe) }
        if safe < 60 { return L10n.text("%@s", String(describing: Int(safe.rounded()))) }
        return String(format: "%d:%02d", Int(safe) / 60, Int(safe) % 60)
    }
}

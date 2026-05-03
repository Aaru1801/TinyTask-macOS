import SwiftUI
import AppKit

// MARK: - Root popover

struct PopoverContentView: View {
    let controller: MenuBarController

    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState
    @EnvironmentObject var library: MacroLibrary

    @State private var search: String = ""
    @State private var renamingID: UUID?
    @State private var renameText: String = ""

    private var filteredMacros: [SavedMacro] {
        let trimmed = search.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty { return library.macros }
        return library.macros.filter { $0.name.lowercased().contains(trimmed) }
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                LibraryHeader(
                    controller: controller,
                    search: $search
                )
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if !state.accessibilityGranted {
                    PermissionBanner(controller: controller)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if filteredMacros.isEmpty {
                    EmptyState(hasSearch: !search.isEmpty)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(filteredMacros) { macro in
                                MacroCard(
                                    macro: macro,
                                    isCurrent: macro.id == library.currentMacroID,
                                    isRenaming: renamingID == macro.id,
                                    renameText: $renameText,
                                    onSelect: {
                                        controller.selectMacro(macro.id)
                                    },
                                    onPlay: {
                                        controller.selectMacro(macro.id)
                                        controller.play()
                                    },
                                    onEdit: {
                                        controller.selectMacro(macro.id)
                                        controller.openEditor()
                                    },
                                    onDelete: {
                                        controller.deleteMacro(macro.id)
                                    },
                                    onDuplicate: {
                                        controller.duplicateMacro(macro.id)
                                    },
                                    onExport: {
                                        controller.selectMacro(macro.id)
                                        controller.exportAsScript()
                                    },
                                    onStartRename: {
                                        renamingID = macro.id
                                        renameText = macro.name
                                    },
                                    onCommitRename: {
                                        if let id = renamingID {
                                            controller.renameMacro(id, to: renameText)
                                        }
                                        renamingID = nil
                                    },
                                    onSetLoops: { newLoops in
                                        controller.setMacroLoops(macro.id, to: newLoops)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    }
                }

                Divider().opacity(0.5)

                LibraryFooter(controller: controller, state: state)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
        .frame(width: 400, height: 540)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.accessibilityGranted)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: filteredMacros.count)
    }
}

// MARK: - Header (logo + search + record)

private struct LibraryHeader: View {
    let controller: MenuBarController
    @Binding var search: String
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player

    var body: some View {
        HStack(spacing: 8) {
            BrandMark(size: 30)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search macros…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                    )
            )

            // Record button (red prominent)
            Button {
                controller.toggleRecording()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: recorder.isRecording ? "stop.fill" : "circle.fill")
                        .font(.system(size: recorder.isRecording ? 9 : 8, weight: .black))
                    Text(recorder.isRecording ? "Stop" : "Record")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 6.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.97, green: 0.32, blue: 0.32),
                                    Color(red: 0.78, green: 0.13, blue: 0.13),
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                        )
                        .shadow(color: .red.opacity(0.35), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(HoverPressButtonStyle(hoverScale: 1.04))
        }
    }
}

// MARK: - Macro card

private struct MacroCard: View {
    let macro: SavedMacro
    let isCurrent: Bool
    let isRenaming: Bool
    @Binding var renameText: String
    let onSelect: () -> Void
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onExport: () -> Void
    let onStartRename: () -> Void
    let onCommitRename: () -> Void
    let onSetLoops: (Int) -> Void

    @State private var hovered = false
    @FocusState private var renameFocused: Bool

    private var durationText: String {
        let d = macro.duration
        let m = Int(d) / 60
        let s = Int(d) % 60
        let cs = Int((d - floor(d)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            if isRenaming {
                TextField("Name", text: $renameText, onCommit: onCommitRename)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
                    .focused($renameFocused)
                    .onAppear { renameFocused = true }
            } else {
                Text(macro.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // Tiny waveform
            MiniWaveform(events: macro.events)
                .frame(height: 18)

            // Bottom row: duration + actions
            HStack(spacing: 4) {
                Text(durationText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                CardActionButton(systemImage: "play.fill", tint: .green) { onPlay() }
                    .help("Play")
                LoopChip(loops: macro.loops, onChange: onSetLoops)
                CardActionButton(systemImage: "slider.horizontal.below.rectangle", tint: .blue) { onEdit() }
                    .help("Edit")
                Menu {
                    Button("Rename…") { onStartRename() }
                    Button("Duplicate") { onDuplicate() }
                    Button("Export…") { onExport() }
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22, height: 18)
            }
        }
        .padding(10)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(isCurrent ? 0.07 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            isCurrent ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.10),
                            lineWidth: isCurrent ? 1.0 : 0.5
                        )
                )
                .shadow(color: .black.opacity(hovered ? 0.18 : 0.06), radius: hovered ? 6 : 2, y: 2)
        )
        .scaleEffect(hovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: hovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isCurrent)
        .onHover { hovered = $0 }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Play")     { onPlay() }
            Button("Edit…")    { onEdit() }
            Divider()
            Button("Rename…")  { onStartRename() }
            Button("Duplicate") { onDuplicate() }
            Button("Export…")  { onExport() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

private struct LoopChip: View {
    let loops: Int
    let onChange: (Int) -> Void

    @State private var hovered = false
    @State private var showCustom = false
    @State private var customText = ""

    private var label: String {
        loops <= 0 ? "∞" : "×\(loops)"
    }

    private var tint: Color {
        loops <= 0 ? .orange : (loops > 1 ? .accentColor : .secondary)
    }

    var body: some View {
        Menu {
            Section("Repeat") {
                Button("1× (no loop)") { onChange(1) }
                Button("2×")           { onChange(2) }
                Button("5×")           { onChange(5) }
                Button("10×")          { onChange(10) }
                Button("25×")          { onChange(25) }
                Button("100×")         { onChange(100) }
            }
            Divider()
            Button { onChange(0) } label: {
                Label("Continuous", systemImage: "infinity")
            }
            Divider()
            Button("Custom…") {
                customText = loops > 0 ? "\(loops)" : ""
                showCustom = true
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: loops <= 0 ? "infinity" : "repeat")
                    .font(.system(size: 8, weight: .bold))
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(loops != 1 ? AnyShapeStyle(tint) : AnyShapeStyle(Color.secondary))
            .frame(minWidth: 26)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        loops != 1
                            ? tint.opacity(hovered ? 0.18 : 0.12)
                            : Color.primary.opacity(hovered ? 0.10 : 0.05)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                loops != 1 ? tint.opacity(0.45) : Color.primary.opacity(0.10),
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(loops <= 0 ? "Repeats continuously" : (loops == 1 ? "Plays once" : "Repeats \(loops) times"))
        .onHover { hovered = $0 }
        .alert("Custom repeat count", isPresented: $showCustom) {
            TextField("e.g. 42", text: $customText)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                let trimmed = customText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed == "∞" {
                    onChange(0)
                } else if let n = Int(trimmed) {
                    onChange(max(0, n))
                }
            }
        } message: {
            Text("Enter how many times to repeat. 0 (or blank) = continuous.")
        }
    }
}

private struct CardActionButton: View {
    let systemImage: String
    let tint: Color
    var isMenu: Bool = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(hovered ? AnyShapeStyle(tint) : AnyShapeStyle(Color.secondary))
                .frame(width: 22, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(hovered ? 0.10 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Mini waveform

struct MiniWaveform: View {
    let events: [RecordedEvent]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let total = events.last?.time ?? 0
            let dur = total > 0 ? total : 1

            // Sample down to ~60 bars
            let bars = sampleEvents(maxBars: 60, width: w, dur: dur)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: h * 0.5)
                    .frame(maxHeight: .infinity, alignment: .center)

                ForEach(bars, id: \.0) { (x, kind, isImpact) in
                    Rectangle()
                        .fill(color(for: kind))
                        .frame(
                            width: isImpact ? 1.6 : 1,
                            height: isImpact ? h * 0.95 : h * 0.45
                        )
                        .offset(x: x)
                }
            }
        }
    }

    private func sampleEvents(maxBars: Int, width: CGFloat, dur: TimeInterval) -> [(CGFloat, RecordedEvent.Kind, Bool)] {
        guard !events.isEmpty else { return [] }
        let n = min(events.count, maxBars)
        let stride = max(1, events.count / n)
        var result: [(CGFloat, RecordedEvent.Kind, Bool)] = []
        var i = 0
        while i < events.count {
            let ev = events[i]
            let x = CGFloat(ev.time / dur) * width
            let isImpact = ev.kind == .leftMouseDown || ev.kind == .rightMouseDown ||
                           ev.kind == .keyDown
            result.append((x, ev.kind, isImpact))
            i += stride
        }
        return result
    }

    private func color(for kind: RecordedEvent.Kind) -> Color {
        switch kind {
        case .leftMouseDown, .leftMouseUp:    return .green
        case .rightMouseDown, .rightMouseUp:  return .orange
        case .keyDown, .keyUp, .flagsChanged: return .blue
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: return .purple
        case .scrollWheel:                    return .teal
        default:                              return Color.secondary.opacity(0.7)
        }
    }
}

// MARK: - Empty state

private struct EmptyState: View {
    let hasSearch: Bool
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: hasSearch ? "magnifyingglass" : "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(hasSearch ? "No matches" : "No macros yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(hasSearch ? "Try a different search term." : "Press Record to capture your first macro.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }
}

// MARK: - Footer

private struct LibraryFooter: View {
    let controller: MenuBarController
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            FooterRow(
                icon: "plus",
                label: "New macro",
                rightAccessory: AnyView(KeyCapView(text: "⌘R")),
                action: { controller.toggleRecording() }
            )
            FooterRow(
                icon: "slider.horizontal.below.rectangle",
                label: "Open editor",
                rightAccessory: nil,
                action: { controller.openEditor() }
            )
            FooterRow(
                icon: "gearshape",
                label: "Preferences",
                rightAccessory: nil,
                action: { state.showSettings.toggle() }
            )
        }
        .popover(isPresented: $state.showSettings, arrowEdge: .bottom) {
            SettingsPanel(controller: controller)
        }
    }
}

private struct FooterRow: View {
    let icon: String
    let label: String
    let rightAccessory: AnyView?
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                Spacer()
                if let r = rightAccessory { r }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.06 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Permission banner

private struct PermissionBanner: View {
    let controller: MenuBarController
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Permissions required")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Grant Accessibility & Input Monitoring to record and replay.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Open") { controller.openAccessibilityPrefs() }
                .buttonStyle(PillButtonStyle(tint: .orange))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.45), lineWidth: 0.8)
                )
        )
    }
}

// MARK: - Settings panel (preserved)

struct SettingsPanel: View {
    let controller: MenuBarController
    @EnvironmentObject var state: AppState

    @State private var showCustomLoop = false
    @State private var customLoopText = ""

    private let fkeys: [(UInt32, String)] = [
        (KeyCode.f1, "F1"), (KeyCode.f2, "F2"), (KeyCode.f3, "F3"), (KeyCode.f4, "F4"),
        (KeyCode.f5, "F5"), (KeyCode.f6, "F6"), (KeyCode.f7, "F7"), (KeyCode.f8, "F8"),
        (KeyCode.f9, "F9"), (KeyCode.f10, "F10"), (KeyCode.f11, "F11"), (KeyCode.f12, "F12"),
    ]

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .popover)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.secondary)
                    Text("Preferences")
                        .font(.system(size: 13, weight: .semibold))
                }

                settingsGroup("Hotkeys", systemImage: "keyboard") {
                    hotkeyRow(title: "Record / Stop recording", binding: Binding(
                        get: { state.recordHotkey },
                        set: { state.recordHotkey = $0; controller.reapplyHotkeys() }
                    ))
                    hotkeyRow(title: "Stop everything", binding: Binding(
                        get: { state.stopHotkey },
                        set: { state.stopHotkey = $0; controller.reapplyHotkeys() }
                    ))
                    hotkeyRow(title: "Play", binding: Binding(
                        get: { state.playHotkey },
                        set: { state.playHotkey = $0; controller.reapplyHotkeys() }
                    ))
                }

                settingsGroup("Playback", systemImage: "play.circle") {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Default repeat")
                                .font(.system(size: 11.5))
                            Spacer()
                            ChipMenuButton(
                                title: state.loops <= 0 ? "∞" : "\(state.loops)×",
                                icon: state.loops <= 0 ? "infinity" : "repeat",
                                tint: state.loops <= 0 ? .orange : (state.loops > 1 ? .accentColor : nil)
                            ) {
                                Section("Repeat") {
                                    Button("1× (no loop)") { state.loops = 1 }
                                    Button("2×")           { state.loops = 2 }
                                    Button("5×")           { state.loops = 5 }
                                    Button("10×")          { state.loops = 10 }
                                    Button("25×")          { state.loops = 25 }
                                    Button("100×")         { state.loops = 100 }
                                }
                                Divider()
                                Button { state.loops = 0 } label: {
                                    Label("Continuous", systemImage: "infinity")
                                }
                                Divider()
                                Button("Custom…") {
                                    customLoopText = state.loops > 0 ? "\(state.loops)" : ""
                                    showCustomLoop = true
                                }
                            }
                        }
                        Text("Applied to newly recorded macros · adjust per-macro on each card.")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                    HStack {
                        Text("Speed").font(.system(size: 11.5))
                        Spacer()
                        SegmentedSpeedPicker(speed: $state.speed)
                    }
                }

                settingsGroup("Permissions", systemImage: "lock.shield") {
                    HStack(spacing: 8) {
                        Button("Accessibility") { controller.openAccessibilityPrefs() }
                            .buttonStyle(PillButtonStyle(tint: .blue))
                        Button("Input Monitoring") { controller.openInputMonitoringPrefs() }
                            .buttonStyle(PillButtonStyle(tint: .blue))
                    }
                }

                HStack {
                    Spacer()
                    Text("v1.2.0")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Button("Quit") { controller.quit() }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
            }
            .padding(14)
        }
        .frame(width: 320)
        .alert("Custom loop count", isPresented: $showCustomLoop) {
            TextField("e.g. 42", text: $customLoopText)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                let trimmed = customLoopText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed == "∞" { state.loops = 0 }
                else if let n = Int(trimmed) { state.loops = max(0, n) }
            }
        } message: {
            Text("Enter a number, or 0 (or leave blank) for continuous.")
        }
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.7)
            }
            .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(10)
                .cardSurface(cornerRadius: 10)
        }
    }

    private func hotkeyRow(title: String, binding: Binding<HotkeyBinding>) -> some View {
        HStack {
            Text(title).font(.system(size: 11.5))
            Spacer()
            ChipMenuButton(
                title: binding.wrappedValue.name,
                icon: nil,
                tint: nil
            ) {
                ForEach(fkeys, id: \.0) { pair in
                    Button {
                        binding.wrappedValue = HotkeyBinding(keyCode: pair.0, name: pair.1)
                    } label: {
                        if pair.0 == binding.wrappedValue.keyCode {
                            Label(pair.1, systemImage: "checkmark")
                        } else {
                            Text(pair.1)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ChipMenuButton (styled Menu)

struct ChipMenuButton<MenuContent: View>: View {
    let title: String
    var icon: String? = nil
    var tint: Color? = nil
    @ViewBuilder var menu: () -> MenuContent

    @State private var hovered = false

    private var fg: AnyShapeStyle {
        tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary)
    }
    private var bgFill: Color {
        (tint ?? .primary).opacity(hovered ? 0.14 : 0.08)
    }
    private var border: Color {
        (tint ?? .primary).opacity(tint == nil ? 0.14 : 0.40)
    }

    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .opacity(0.55)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(bgFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(border, lineWidth: 0.5)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Segmented speed picker (custom)

struct SegmentedSpeedPicker: View {
    @Binding var speed: Double

    private let options: [(value: Double, label: String)] = [
        (0.5, "0.5×"), (1.0, "1×"), (2.0, "2×"), (4.0, "4×")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { opt in
                SpeedSegment(
                    label: opt.label,
                    isSelected: speed == opt.value,
                    action: { speed = opt.value }
                )
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                )
        )
    }
}

private struct SpeedSegment: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color.accentColor.opacity(0.95),
                                             Color.accentColor.opacity(0.78)],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                : (hovered
                                    ? AnyShapeStyle(Color.primary.opacity(0.07))
                                    : AnyShapeStyle(Color.clear))
                        )
                        .shadow(color: isSelected ? Color.accentColor.opacity(0.30) : .clear,
                                radius: isSelected ? 3 : 0, y: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Pill button style

struct PillButtonStyle: ButtonStyle {
    var tint: Color = .blue
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(configuration.isPressed ? 0.6 : 0.95),
                                     tint.opacity(configuration.isPressed ? 0.45 : 0.78)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                    )
                    .shadow(color: tint.opacity(hovered ? 0.45 : 0.25), radius: hovered ? 6 : 3, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (hovered ? 1.04 : 1.0))
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: hovered)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: configuration.isPressed)
            .onHover { hovered = $0 }
    }
}

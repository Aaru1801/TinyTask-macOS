import SwiftUI
import AppKit

struct PopoverContentView: View {
    let controller: MenuBarController

    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            // Real macOS vibrancy.
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HeaderCard(controller: controller)

                if !state.accessibilityGranted {
                    PermissionBanner(controller: controller)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                StatsCard()
                ActionRow(controller: controller)
                MacroCard(controller: controller)
                StatusLine()
                Spacer(minLength: 0)
                BottomBar(controller: controller)
            }
            .padding(14)
        }
        .frame(width: 360, height: 540)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.accessibilityGranted)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: recorder.isRecording)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: player.isPlaying)
    }
}

// MARK: - Header

private struct HeaderCard: View {
    let controller: MenuBarController
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState

    var statusText: String {
        if recorder.isRecording { return "Recording" }
        if player.isPlaying     { return "Playing" }
        return "Idle"
    }

    var statusColor: Color {
        if recorder.isRecording { return .red }
        if player.isPlaying     { return .green }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 10) {
            BrandMark(size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("TinyRecorder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Free macro recorder")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status pill
            HStack(spacing: 6) {
                StatusDot(color: statusColor, pulsing: recorder.isRecording || player.isPlaying)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 5)
            .padding(.trailing, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(statusColor.opacity(0.14))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(statusColor.opacity(0.42), lineWidth: 0.7)
                    )
            )

            Button {
                state.showSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.07))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
                    )
            }
            .buttonStyle(HoverPressButtonStyle(hoverScale: 1.08))
            .popover(isPresented: $state.showSettings, arrowEdge: .bottom) {
                SettingsPanel(controller: controller)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .cardSurface(cornerRadius: 14)
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

// MARK: - Stats card

private struct StatsCard: View {
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState

    @State private var showCustomLoop = false
    @State private var customLoopText = ""

    var durationText: String {
        let d: TimeInterval = recorder.isRecording
            ? recorder.liveDuration
            : (recorder.events.last?.time ?? 0)
        let m = Int(d) / 60
        let s = Int(d) % 60
        let cs = Int((d - floor(d)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }

    var loopText: String {
        if player.isPlaying {
            let t = player.totalLoops <= 0 ? "∞" : "\(player.totalLoops)"
            return "\(player.currentLoop)/\(t)"
        }
        return state.loops <= 0 ? "∞" : "\(state.loops)×"
    }

    var body: some View {
        HStack(spacing: 0) {
            StatCell(label: "Events",   value: "\(recorder.events.count)", icon: "wave.3.right")
            divider
            StatCell(label: "Duration", value: durationText,                icon: "clock")
            divider
            Menu {
                Section("Quick presets") {
                    Button("1× (no loop)") { state.loops = 1 }
                    Button("2×")           { state.loops = 2 }
                    Button("5×")           { state.loops = 5 }
                    Button("10×")          { state.loops = 10 }
                    Button("25×")          { state.loops = 25 }
                    Button("100×")         { state.loops = 100 }
                }
                Divider()
                Button {
                    state.loops = 0
                } label: {
                    Label("Continuous", systemImage: "infinity")
                }
                Divider()
                Button("Custom…") {
                    customLoopText = state.loops > 0 ? "\(state.loops)" : ""
                    showCustomLoop = true
                }
            } label: {
                StatCell(label: "Loop", value: loopText, icon: "repeat", interactive: true)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 11)
        .cardSurface(cornerRadius: 12)
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

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(width: 1, height: 28)
    }
}

private struct StatCell: View {
    let label: String
    let value: String
    let icon: String
    var interactive: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                if interactive {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .opacity(0.6)
                }
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: value)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Action row

private struct ActionRow: View {
    let controller: MenuBarController
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            CircleAction(icon: "folder",                      label: "Open",   tint: .blue) {
                controller.open()
            }
            CircleAction(icon: "arrow.down.doc",              label: "Save",   tint: .indigo,
                         disabled: recorder.events.isEmpty) {
                controller.save()
            }
            CircleAction(
                icon: recorder.isRecording ? "stop.circle.fill" : "record.circle.fill",
                label: recorder.isRecording ? "Stop" : "Rec",
                tint: .red,
                pulsing: recorder.isRecording,
                primary: true
            ) {
                controller.toggleRecording()
            }
            CircleAction(
                icon: player.isPlaying ? "stop.fill" : "play.fill",
                label: player.isPlaying ? "Stop" : "Play",
                tint: .green,
                disabled: recorder.events.isEmpty
            ) {
                if player.isPlaying { controller.stopAll() } else { controller.play() }
            }
            CircleAction(icon: "square.and.arrow.up",         label: "Export", tint: .orange,
                         disabled: recorder.events.isEmpty) {
                controller.exportAsScript()
            }
            CircleAction(icon: "slider.horizontal.3",         label: "Prefs",  tint: .gray) {
                state.showSettings.toggle()
            }
        }
    }
}

private struct CircleAction: View {
    let icon: String
    let label: String
    let tint: Color
    var pulsing: Bool = false
    var disabled: Bool = false
    var primary: Bool = false
    let action: () -> Void

    @State private var hovered = false
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Soft halo
                    if hovered && !disabled {
                        Circle()
                            .fill(tint.opacity(0.18))
                            .frame(width: 50, height: 50)
                            .blur(radius: 6)
                    }
                    // Base
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: primary
                                    ? [tint.opacity(0.95), tint.opacity(0.78)]
                                    : [Color.primary.opacity(0.07), Color.primary.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Circle().strokeBorder(
                                primary
                                    ? .white.opacity(0.22)
                                    : tint.opacity(disabled ? 0.10 : (hovered ? 0.55 : 0.32)),
                                lineWidth: primary ? 0.8 : 0.7
                            )
                        )
                        .shadow(
                            color: primary ? tint.opacity(0.45) : .black.opacity(0.18),
                            radius: primary ? 8 : 3,
                            x: 0, y: primary ? 3 : 1
                        )
                        .frame(width: 42, height: 42)

                    // Pulse ring for recording
                    if pulsing {
                        Circle()
                            .strokeBorder(tint.opacity(0.7), lineWidth: 1.4)
                            .frame(width: 42, height: 42)
                            .scaleEffect(pulse ? 1.45 : 1.0)
                            .opacity(pulse ? 0 : 0.85)
                            .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            disabled
                                ? AnyShapeStyle(Color.secondary.opacity(0.4))
                                : (primary ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 50, height: 50)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(disabled ? AnyShapeStyle(Color.secondary.opacity(0.5)) : AnyShapeStyle(.primary))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverPressButtonStyle(hoverScale: disabled ? 1.0 : 1.06))
        .disabled(disabled)
        .onHover { hovered = $0 }
        .onAppear { if pulsing { pulse = true } }
        .onChange(of: pulsing) { newValue in pulse = newValue }
    }
}

// MARK: - Macro card

private struct MacroCard: View {
    let controller: MenuBarController
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState

    var subtitle: String {
        if recorder.events.isEmpty { return "No macro recorded yet" }
        let mouse = recorder.events.filter { $0.kind.isMouse }.count
        let keys  = recorder.events.filter { $0.kind.isKey }.count
        return "\(mouse) mouse · \(keys) key events"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11, weight: .semibold))
                Text("CURRENT MACRO")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = state.lastSavedURL {
                    Text(url.lastPathComponent)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button {
                    controller.openEditor()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.below.rectangle")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(recorder.events.isEmpty ? .secondary : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(recorder.events.isEmpty ? 0.04 : 0.10))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(HoverPressButtonStyle(hoverScale: 1.05))
                .disabled(recorder.events.isEmpty)
            }

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: recorder.events.isEmpty
                                    ? [Color.primary.opacity(0.08), Color.primary.opacity(0.04)]
                                    : [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.06)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                        )
                    Image(systemName: recorder.events.isEmpty ? "tray" : "doc.fill")
                        .foregroundStyle(recorder.events.isEmpty ? .secondary : .primary)
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recorder.events.isEmpty ? "Empty" : "Macro · \(recorder.events.count) events")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if player.isPlaying {
                ProgressView(value: player.progress)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .transition(.opacity)
            }

            // Subtle inline timeline showing distribution of events.
            if !recorder.events.isEmpty {
                MacroTimeline(events: recorder.events, progress: player.isPlaying ? player.progress : nil)
                    .frame(height: 16)
            }
        }
        .padding(12)
        .cardSurface(cornerRadius: 12)
    }
}

/// A small horizontal "scrubber" showing event density across the macro's duration.
private struct MacroTimeline: View {
    let events: [RecordedEvent]
    let progress: Double?

    private var totalDuration: TimeInterval { events.last?.time ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let h = geo.size.height
            let dur = totalDuration > 0 ? totalDuration : 1

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: h)

                ForEach(0..<min(events.count, 200), id: \.self) { i in
                    let stride = max(1, events.count / 200)
                    let ev = events[i * stride]
                    let x = CGFloat(ev.time / dur) * width
                    let isClick = ev.kind == .leftMouseDown || ev.kind == .rightMouseDown ||
                                  ev.kind == .keyDown
                    Rectangle()
                        .fill(
                            isClick ? Color.accentColor.opacity(0.85)
                                    : Color.secondary.opacity(0.45)
                        )
                        .frame(width: isClick ? 1.6 : 1, height: isClick ? h : h * 0.55)
                        .offset(x: x)
                }

                if let p = progress {
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 2, height: h)
                        .offset(x: CGFloat(p) * width)
                }
            }
        }
    }
}

// MARK: - Status line

private struct StatusLine: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(state.statusMessage.isEmpty ? "Ready." : state.statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: state.statusMessage)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Bottom bar

private struct BottomBar: View {
    let controller: MenuBarController
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            HotkeyChip(label: "Rec",  value: state.recordHotkey.name)
            HotkeyChip(label: "Stop", value: state.stopHotkey.name)
            HotkeyChip(label: "Play", value: state.playHotkey.name)
            Spacer()
            Button {
                controller.quit()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 9.5, weight: .bold))
                    Text("Quit")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .chipSurface()
            }
            .buttonStyle(HoverPressButtonStyle(hoverScale: 1.06))
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}

private struct HotkeyChip: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)
            KeyCapView(text: value)
        }
    }
}

// MARK: - Settings panel

private struct SettingsPanel: View {
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
                    HStack {
                        Text("Repeat")
                            .font(.system(size: 11.5))
                        Spacer()
                        Menu {
                            Button("1× (no loop)") { state.loops = 1 }
                            Button("2×")           { state.loops = 2 }
                            Button("5×")           { state.loops = 5 }
                            Button("10×")          { state.loops = 10 }
                            Button("25×")          { state.loops = 25 }
                            Button("100×")         { state.loops = 100 }
                            Divider()
                            Button {
                                state.loops = 0
                            } label: { Label("Continuous", systemImage: "infinity") }
                            Divider()
                            Button("Custom…") {
                                customLoopText = state.loops > 0 ? "\(state.loops)" : ""
                                showCustomLoop = true
                            }
                        } label: {
                            Text(state.loops <= 0 ? "∞ Continuous" : "\(state.loops)×")
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 120)
                    }
                    HStack {
                        Text("Speed")
                            .font(.system(size: 11.5))
                        Spacer()
                        Picker("", selection: $state.speed) {
                            Text("0.5×").tag(0.5)
                            Text("1×").tag(1.0)
                            Text("2×").tag(2.0)
                            Text("4×").tag(4.0)
                        }
                        .labelsHidden()
                        .frame(width: 110)
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
                    Text("v1.0.0")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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
            Picker("", selection: Binding(
                get: { binding.wrappedValue.keyCode },
                set: { newValue in
                    if let pair = fkeys.first(where: { $0.0 == newValue }) {
                        binding.wrappedValue = HotkeyBinding(keyCode: pair.0, name: pair.1)
                    }
                }
            )) {
                ForEach(fkeys, id: \.0) { pair in
                    Text(pair.1).tag(pair.0)
                }
            }
            .labelsHidden()
            .frame(width: 90)
        }
    }
}

// MARK: - Helpers

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

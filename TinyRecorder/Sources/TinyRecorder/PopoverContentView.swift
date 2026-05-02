import SwiftUI
import AppKit

struct PopoverContentView: View {
    let controller: MenuBarController

    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HeaderCard(controller: controller)
                if !state.accessibilityGranted {
                    PermissionBanner(controller: controller)
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
        .preferredColorScheme(.dark)
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
        return Color(white: 0.45)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("TinyRecorder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text("Free macro recorder")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            Spacer()
            Button {
                state.showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(Color(white: 0.12))
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $state.showSettings, arrowEdge: .bottom) {
                SettingsPanel(controller: controller)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .opacity(recorder.isRecording ? animatedOpacity : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animatedOpacity)
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().stroke(statusColor.opacity(0.65), lineWidth: 1.2)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(white: 0.16), lineWidth: 1)
        )
    }

    @State private var animatedOpacity: Double = 1.0
}

// MARK: - Permission banner

private struct PermissionBanner: View {
    let controller: MenuBarController

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility permission required")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text("TinyRecorder needs Accessibility & Input Monitoring access to capture and replay events.")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Open") { controller.openAccessibilityPrefs() }
                .buttonStyle(PillButtonStyle(tint: .orange))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.08))
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
        let d: TimeInterval
        if recorder.isRecording {
            d = recorder.liveDuration
        } else {
            d = recorder.events.last?.time ?? 0
        }
        let m = Int(d) / 60
        let s = Int(d) % 60
        let cs = Int((d - floor(d)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }

    /// Live "current/total" while playing, or the configured loop setting when idle.
    /// "∞" means continuous.
    var loopText: String {
        if player.isPlaying {
            let current = "\(player.currentLoop)"
            let total = player.totalLoops <= 0 ? "∞" : "\(player.totalLoops)"
            return "\(current)/\(total)"
        } else {
            return state.loops <= 0 ? "∞" : "\(state.loops)×"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(recorder.events.count)", label: "Events", icon: "wave.3.right")
            divider
            StatPill(value: durationText, label: "Duration", icon: "clock")
            divider
            Menu {
                Button("1× (no loop)") { state.loops = 1 }
                Button("2×")           { state.loops = 2 }
                Button("5×")           { state.loops = 5 }
                Button("10×")          { state.loops = 10 }
                Button("25×")          { state.loops = 25 }
                Button("100×")         { state.loops = 100 }
                Divider()
                Button("∞ Continuous") { state.loops = 0 }
                Divider()
                Button("Custom…") {
                    customLoopText = state.loops > 0 ? "\(state.loops)" : ""
                    showCustomLoop = true
                }
            } label: {
                StatPill(value: loopText, label: "Loop", icon: "repeat")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.07))
        )
        .alert("Custom loop count", isPresented: $showCustomLoop) {
            TextField("e.g. 42", text: $customLoopText)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                let trimmed = customLoopText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed == "∞" {
                    state.loops = 0
                } else if let n = Int(trimmed) {
                    state.loops = max(0, n)
                }
            }
        } message: {
            Text("How many times to repeat the macro. Enter 0 (or leave blank) for continuous.")
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(white: 0.18))
            .frame(width: 1, height: 28)
    }
}

private struct StatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(.gray)
            }
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Action row (TinyTask-like)

private struct ActionRow: View {
    let controller: MenuBarController
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            CircleAction(icon: "folder.fill",       label: "Open",     tint: .blue) {
                controller.open()
            }
            CircleAction(icon: "square.and.arrow.down.fill", label: "Save", tint: .indigo) {
                controller.save()
            }
            CircleAction(
                icon: recorder.isRecording ? "stop.circle.fill" : "record.circle.fill",
                label: recorder.isRecording ? "Stop" : "Rec",
                tint: recorder.isRecording ? Color(red: 0.95, green: 0.25, blue: 0.25) : .red,
                pulsing: recorder.isRecording
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
            CircleAction(icon: "square.and.arrow.up.fill", label: "Export", tint: .orange, disabled: recorder.events.isEmpty) {
                controller.exportAsScript()
            }
            CircleAction(icon: "slider.horizontal.3", label: "Prefs", tint: .gray) {
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
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.10))
                        .overlay(
                            Circle().stroke(tint.opacity(disabled ? 0.15 : 0.45), lineWidth: 1)
                        )
                    if pulsing {
                        Circle()
                            .stroke(tint.opacity(0.6), lineWidth: 1.4)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .opacity(pulse ? 0.0 : 0.8)
                            .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(disabled ? .gray.opacity(0.4) : tint)
                }
                .frame(width: 44, height: 44)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(disabled ? .gray.opacity(0.5) : .white)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onAppear { if pulsing { pulse = true } }
        .onChange(of: pulsing) { newValue in pulse = newValue }
    }
}

// MARK: - Macro card (current recording info)

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
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundColor(.gray)
                    .font(.system(size: 12, weight: .semibold))
                Text("Current Macro")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .tracking(0.5)
                Spacer()
                if let url = state.lastSavedURL {
                    Text(url.lastPathComponent)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Button {
                    controller.openEditor()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.below.rectangle")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(recorder.events.isEmpty ? .gray.opacity(0.45) : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color(white: recorder.events.isEmpty ? 0.07 : 0.18))
                    )
                }
                .buttonStyle(.plain)
                .disabled(recorder.events.isEmpty)
            }

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.12))
                    Image(systemName: recorder.events.isEmpty ? "tray" : "doc.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recorder.events.isEmpty ? "Empty" : "Macro · \(recorder.events.count) events")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            if player.isPlaying {
                ProgressView(value: player.progress)
                    .progressViewStyle(.linear)
                    .tint(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.16), lineWidth: 1)
        )
    }
}

// MARK: - Status line

private struct StatusLine: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text(state.statusMessage.isEmpty ? "Ready." : state.statusMessage)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineLimit(1)
            Spacer()
        }
    }
}

// MARK: - Bottom bar

private struct BottomBar: View {
    let controller: MenuBarController
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            HotkeyChip(label: "Rec", value: state.recordHotkey.name)
            HotkeyChip(label: "Stop", value: state.stopHotkey.name)
            HotkeyChip(label: "Play", value: state.playHotkey.name)
            Spacer()
            Button {
                controller.quit()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .bold))
                    Text("Quit")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(white: 0.10))
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HotkeyChip: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.gray)
                .tracking(0.4)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color(white: 0.10))
        )
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferences")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            settingsGroup("Hotkeys") {
                hotkeyRow(title: "Record / Stop Recording", binding: Binding(
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

            settingsGroup("Playback") {
                HStack(alignment: .center) {
                    Text("Repeat")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Menu {
                        Button("1× (no loop)") { state.loops = 1 }
                        Button("2×")           { state.loops = 2 }
                        Button("5×")           { state.loops = 5 }
                        Button("10×")          { state.loops = 10 }
                        Button("25×")          { state.loops = 25 }
                        Button("100×")         { state.loops = 100 }
                        Divider()
                        Button("∞ Continuous") { state.loops = 0 }
                        Divider()
                        Button("Custom…") {
                            customLoopText = state.loops > 0 ? "\(state.loops)" : ""
                            showCustomLoop = true
                        }
                    } label: {
                        Text(state.loops <= 0 ? "∞ Continuous" : "\(state.loops)×")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 110)
                }
                HStack {
                    Text("Speed")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Picker("", selection: $state.speed) {
                        Text("0.5×").tag(0.5)
                        Text("1×").tag(1.0)
                        Text("2×").tag(2.0)
                        Text("4×").tag(4.0)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
            }

            settingsGroup("Permissions") {
                Button("Open Accessibility Settings") {
                    controller.openAccessibilityPrefs()
                }
                .buttonStyle(PillButtonStyle(tint: .blue))
                Button("Open Input Monitoring Settings") {
                    controller.openInputMonitoringPrefs()
                }
                .buttonStyle(PillButtonStyle(tint: .blue))
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Color.black)
        .alert("Custom loop count", isPresented: $showCustomLoop) {
            TextField("e.g. 42", text: $customLoopText)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                let trimmed = customLoopText.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed == "∞" {
                    state.loops = 0
                } else if let n = Int(trimmed) {
                    state.loops = max(0, n)
                }
            }
        } message: {
            Text("How many times to repeat the macro. Enter 0 (or leave blank) for continuous.")
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(white: 0.07))
            )
        }
    }

    private func hotkeyRow(title: String, binding: Binding<HotkeyBinding>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
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
            .frame(width: 80)
        }
    }
}

// MARK: - Helpers

struct PillButtonStyle: ButtonStyle {
    var tint: Color = .blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(tint.opacity(configuration.isPressed ? 0.5 : 0.85))
            )
    }
}

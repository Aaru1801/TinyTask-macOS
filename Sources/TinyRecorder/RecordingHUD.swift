import Cocoa
import SwiftUI
import Combine

// MARK: - Window controller

final class RecordingHUDController {
    private var window: NSPanel?
    private let recorder: Recorder
    private let onDiscard: () -> Void
    private let onStop:    () -> Void
    private weak var state: AppState?

    init(recorder: Recorder,
         state: AppState?,
         onDiscard: @escaping () -> Void,
         onStop: @escaping () -> Void) {
        self.recorder = recorder
        self.state = state
        self.onDiscard = onDiscard
        self.onStop = onStop
    }

    func show() {
        if window == nil { create() }
        position()
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.18
            self.window?.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.18
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
    }

    private func create() {
        let view = RecordingHUDView(
            recorder: recorder,
            state: state,
            onDiscard: onDiscard,
            onStop: onStop
        )
        let host = NSHostingView(rootView: view)
        let fitting = host.fittingSize
        let w: CGFloat = fitting.width  > 0 ? fitting.width  : 320
        let h: CGFloat = fitting.height > 0 ? fitting.height : 240

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // The HUD floats over the live desktop — the one place real Liquid Glass
        // refraction shines. Host the SwiftUI body INSIDE an NSGlassEffectView so
        // the glass samples real content behind it (macOS 26+); fall back to the
        // HUD vibrancy material on earlier systems.
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 16
            glass.contentView = host
            panel.contentView = glass
        } else {
            let fx = NSVisualEffectView()
            fx.material = .hudWindow
            fx.blendingMode = .behindWindow
            fx.state = .active
            fx.wantsLayer = true
            fx.layer?.cornerRadius = 16
            fx.layer?.masksToBounds = true
            host.frame = fx.bounds
            host.autoresizingMask = [.width, .height]
            fx.addSubview(host)
            panel.contentView = fx
        }
        window = panel
    }

    private func position() {
        guard let win = window else { return }
        // Position on the screen the user is actually working on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = win.frame.size
        // Top-right with menu-bar gap.
        let x = visible.maxX - size.width - 24
        let y = visible.maxY - size.height - 12
        win.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }
}

// MARK: - View

struct RecordingHUDView: View {
    @ObservedObject var recorder: Recorder
    weak var state: AppState?
    let onDiscard: () -> Void
    let onStop:  () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The actual configured "stop recording" hotkey — pressing record again toggles off.
    private var stopHotkeyName: String {
        state?.recordHotkey.name ?? "F6"
    }
    /// The "stop everything" hotkey, shown as the discard shortcut affordance.
    private var emergencyHotkeyName: String {
        state?.stopHotkey.name ?? "F7"
    }

    private var minutes: String { String(format: "%02d", Int(recorder.liveDuration) / 60) }
    private var seconds: String { String(format: "%02d", Int(recorder.liveDuration) % 60) }
    private var hundredths: String {
        String(format: "%02d", Int((recorder.liveDuration - floor(recorder.liveDuration)) * 100))
    }

    var body: some View {
        let s = recorder.liveStats
        ZStack {
            // A calm, dark surface keeps the timer readable over a busy desktop.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.08, green: 0.085, blue: 0.10).opacity(0.88))

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    RecDot(size: 8, color: Brand.red400)
                    Text("Recording")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                    Spacer()
                    Text("TinyRecorder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(minutes):\(seconds)")
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .tracking(-1.5)
                        .foregroundStyle(.white)
                    Text(".\(hundredths)")
                        .font(.system(size: 22, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 0)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Recording duration")
                .accessibilityValue("\(Int(recorder.liveDuration)) seconds")

                VStack(spacing: 8) {
                    LiveWaveform(events: recorder.events)
                        .frame(height: 30)
                        .accessibilityHidden(true)
                    HStack {
                        Text("Input activity")
                        Spacer()
                        Text("\(recorder.eventCount) events")
                            .monospacedDigit()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.60))
                }

                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)

                HStack(spacing: 12) {
                    HUDStat(value: s.clicks, label: "Clicks")
                    HUDStat(value: s.keys, label: "Keys")
                    HUDStat(value: s.scrolls, label: "Scrolls")
                    HUDStat(value: s.drags, label: "Drags")
                }

                HStack(spacing: 8) {
                    HUDButton(title: "Discard", icon: "trash", shortcut: emergencyHotkeyName, tint: nil, action: onDiscard)
                    HUDButton(title: "Stop", icon: "stop.fill", shortcut: stopHotkeyName, tint: Brand.red500, action: onStop)
                        .help("Stop and save recording")
                }
            }
            .padding(18)
        }
        .frame(width: 336)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - HUD pieces

private struct LiveWaveform: View {
    let events: [RecordedEvent]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Show last ~150 events as vertical bars sliding across.
            let recent = Array(events.suffix(150))
            let count = max(1, recent.count)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)

                ForEach(0..<recent.count, id: \.self) { i in
                    let ev = recent[i]
                    let x = (CGFloat(i) / CGFloat(count)) * w
                    let isImpact = Brand.isImpact(ev.kind)
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Brand.eventColor(ev.kind).opacity(isImpact ? 1.0 : 0.6))
                        .frame(
                            width: isImpact ? 2 : 1.2,
                            height: isImpact ? h : h * 0.45
                        )
                        .offset(x: x)
                }
            }
            .frame(height: h)
            .clipped()
        }
    }
}

private struct HUDStat: View {
    let value: Int
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

private struct HUDButton: View {
    let title: String
    let icon: String
    let shortcut: String
    let tint: Color?
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.70))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint ?? Color.white.opacity(hovered ? 0.13 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(hovered ? 0.24 : 0.10), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(title == "Stop" ? "Stop and save recording" : "Discard recording")
        .accessibilityHint("Shortcut \(shortcut)")
    }
}

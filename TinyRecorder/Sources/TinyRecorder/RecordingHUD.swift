import Cocoa
import SwiftUI
import Combine

// MARK: - Window controller

final class RecordingHUDController {
    private var window: NSPanel?
    private let recorder: Recorder
    private let onPause: () -> Void
    private let onStop:  () -> Void
    private weak var state: AppState?

    init(recorder: Recorder, state: AppState?, onPause: @escaping () -> Void, onStop: @escaping () -> Void) {
        self.recorder = recorder
        self.state = state
        self.onPause = onPause
        self.onStop = onStop
    }

    func show() {
        if window == nil { create() }
        position()
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            self.window?.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
    }

    private func create() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
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

        let view = RecordingHUDView(
            recorder: recorder,
            state: state,
            onPause: onPause,
            onStop: onStop
        )
        let host = NSHostingController(rootView: view)
        host.view.wantsLayer = true
        host.view.layer?.cornerRadius = 16
        host.view.layer?.masksToBounds = true
        panel.contentViewController = host
        window = panel
    }

    private func position() {
        guard let win = window, let screen = NSScreen.main else { return }
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
    let onPause: () -> Void
    let onStop:  () -> Void

    @State private var pulse = false

    private var minutes: String { String(format: "%02d", Int(recorder.liveDuration) / 60) }
    private var seconds: String { String(format: "%02d", Int(recorder.liveDuration) % 60) }
    private var hundredths: String {
        String(format: "%02d", Int((recorder.liveDuration - floor(recorder.liveDuration)) * 100))
    }

    private var clickCount: Int {
        recorder.events.filter {
            $0.kind == .leftMouseDown || $0.kind == .rightMouseDown || $0.kind == .otherMouseDown
        }.count
    }
    private var keyCount: Int   { recorder.events.filter { $0.kind == .keyDown }.count }
    private var scrollCount: Int { recorder.events.filter { $0.kind == .scrollWheel }.count }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow, isEmphasized: true)

            VStack(alignment: .leading, spacing: 10) {
                // Top row
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulse ? 0.35 : 1)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                    Text("RECORDING")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("\(recorder.events.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: recorder.events.count)
                    Text("ev")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Big timer
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(minutes)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text(":")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .offset(y: -2)
                    Text(seconds)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text(".")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .offset(y: 2)
                    Text(hundredths)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .baselineOffset(8)
                }
                .padding(.top, -2)

                // Mini live waveform
                LiveWaveform(events: recorder.events)
                    .frame(height: 16)

                // Stat chips
                HStack(spacing: 6) {
                    HUDStatChip(icon: "cursorarrow.click",  count: clickCount,  tint: .green)
                    HUDStatChip(icon: "keyboard",           count: keyCount,    tint: .blue)
                    HUDStatChip(icon: "arrow.up.and.down",  count: scrollCount, tint: .teal)
                }

                // Buttons
                HStack(spacing: 6) {
                    HUDButton(
                        title: "Pause",
                        icon: "pause.fill",
                        shortcut: "⌥⌘,",
                        tint: nil,
                        action: onPause
                    )
                    HUDButton(
                        title: "Stop",
                        icon: "stop.fill",
                        shortcut: "⌥⌘.",
                        tint: .red,
                        action: onStop
                    )
                }
            }
            .padding(14)
        }
        .frame(width: 300, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        .onAppear { pulse = true }
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
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: h)

                ForEach(0..<recent.count, id: \.self) { i in
                    let ev = recent[i]
                    let x = (CGFloat(i) / CGFloat(count)) * w
                    let isImpact =
                        ev.kind == .leftMouseDown || ev.kind == .rightMouseDown ||
                        ev.kind == .keyDown
                    Rectangle()
                        .fill(color(for: ev.kind))
                        .frame(
                            width: isImpact ? 1.6 : 1,
                            height: isImpact ? h : h * 0.45
                        )
                        .offset(x: x)
                }
            }
        }
    }

    private func color(for kind: RecordedEvent.Kind) -> Color {
        switch kind {
        case .leftMouseDown, .leftMouseUp:     return .green
        case .rightMouseDown, .rightMouseUp:   return .orange
        case .keyDown, .keyUp, .flagsChanged:  return .blue
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                                               return .purple
        case .scrollWheel:                     return .teal
        default:                               return Color.secondary.opacity(0.7)
        }
    }
}

private struct HUDStatChip: View {
    let icon: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: count)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                )
        )
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer(minLength: 0)
                Text(shortcut)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint != nil ? .white.opacity(0.85) : .secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill((tint != nil ? Color.white : Color.primary).opacity(0.12))
                    )
            }
            .foregroundStyle(tint != nil ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        tint != nil
                            ? AnyShapeStyle(LinearGradient(
                                colors: [tint!.opacity(0.95), tint!.opacity(0.78)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            : AnyShapeStyle(Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                tint != nil ? Color.white.opacity(0.22) : Color.primary.opacity(0.12),
                                lineWidth: 0.6
                            )
                    )
                    .shadow(
                        color: (tint ?? .black).opacity(hovered ? 0.30 : 0.14),
                        radius: hovered ? 6 : 3, y: 2
                    )
            )
        }
        .buttonStyle(HoverPressButtonStyle(hoverScale: 1.03))
        .onHover { hovered = $0 }
    }
}

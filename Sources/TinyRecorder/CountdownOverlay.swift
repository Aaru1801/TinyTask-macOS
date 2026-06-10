import Cocoa
import SwiftUI
import Combine

/// Big floating "3 · 2 · 1" overlay shown before recording starts so the user
/// can switch to the right window before keyboard/mouse is being captured.
final class CountdownOverlayController {
    private var window: NSPanel?
    private var timer: Timer?
    private let model = CountdownModel()
    /// Bumped on every start()/cancel(). Timer ticks and the dismiss animation
    /// completion both check it, so a cancelled countdown can never fire
    /// onComplete — even if cancel lands during the final fade.
    private var session: UInt64 = 0

    /// True while a countdown is pending (used to make the record hotkey toggle).
    private(set) var isActive = false

    /// `seconds` ticks before completion. `onComplete` runs on the main queue.
    func start(seconds: Int = 3, onComplete: @escaping () -> Void) {
        cancel()
        session &+= 1
        let mySession = session
        isActive = true
        model.reset(to: seconds)

        if window == nil { create() }
        position()
        window?.alphaValue = 0
        window?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.window?.animator().alphaValue = 1
        }
        SoundController.shared.play(.tick)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.session == mySession else { return }
            let next = self.model.remaining - 1
            if next <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.dismiss(session: mySession) { [weak self] in
                    guard let self, self.session == mySession else { return }
                    self.isActive = false
                    onComplete()
                }
            } else {
                SoundController.shared.play(.tick)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.model.remaining = next
                }
            }
        }
    }

    func cancel() {
        session &+= 1
        isActive = false
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
    }

    private func dismiss(session expected: UInt64, _ then: @escaping () -> Void) {
        guard let win = window else { then(); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.session == expected else { return }
            self.window?.orderOut(nil)
            then()
        })
    }

    private func create() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 280),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false

        // Built once; the view observes the model so ticks animate properly
        // instead of swapping in a brand-new hosting controller every second.
        let host = NSHostingController(rootView: CountdownView(model: model))
        host.view.wantsLayer = true
        host.view.layer?.cornerRadius = 28
        host.view.layer?.masksToBounds = true
        panel.contentViewController = host
        window = panel
    }

    private func position() {
        guard let win = window else { return }
        // Show on the screen the user is actually working on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = win.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2
        win.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }
}

// MARK: - Model

final class CountdownModel: ObservableObject {
    @Published var remaining: Int = 3
    /// Bumped per countdown session so the pulse ring restarts cleanly.
    @Published var sessionSeed: Int = 0

    func reset(to seconds: Int) {
        remaining = seconds
        sessionSeed &+= 1
    }
}

// MARK: - View

private struct CountdownView: View {
    @ObservedObject var model: CountdownModel
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
            Circle()
                .strokeBorder(Color.red.opacity(0.55), lineWidth: 3)
                .scaleEffect(pulse ? 1.04 : 1.0)
                .opacity(pulse ? 0.0 : 1.0)
                .animation(.easeOut(duration: 0.7).repeatForever(autoreverses: false), value: pulse)
            VStack(spacing: 4) {
                Text("\(model.remaining)")
                    .font(.system(size: 130, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))
                Text("RECORDING IN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(width: 280, height: 280)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording starts in \(model.remaining) seconds")
        .onAppear { pulse = true }
        .onChange(of: model.sessionSeed) { _ in
            // Restart the pulse for each new countdown session.
            pulse = false
            DispatchQueue.main.async { pulse = true }
        }
    }
}

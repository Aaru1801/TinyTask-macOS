import SwiftUI
import AppKit

// MARK: - Material backgrounds (NSVisualEffectView)

/// Wraps NSVisualEffectView so SwiftUI views get real macOS vibrancy/translucency.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .followsWindowActiveState
    var isEmphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = state
        v.isEmphasized = isEmphasized
        v.autoresizingMask = [.width, .height]
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = isEmphasized
    }
}

// MARK: - Card styles

extension View {
    /// Subtle layered card on top of vibrancy — adapts to light/dark.
    func cardSurface(cornerRadius: CGFloat = 12) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }

    /// Translucent capsule used for chips & pills.
    func chipSurface() -> some View {
        modifier(ChipSurface())
    }

    /// Hover scale + press feedback for tappable elements.
    func interactive(scale: CGFloat = 1.04, pressedScale: CGFloat = 0.97) -> some View {
        modifier(InteractiveScale(hoverScale: scale, pressedScale: pressedScale))
    }
}

private struct CardSurface: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                    )
            )
    }
}

private struct ChipSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                    )
            )
    }
}

private struct InteractiveScale: ViewModifier {
    let hoverScale: CGFloat
    let pressedScale: CGFloat
    @State private var hovered = false
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? pressedScale : (hovered ? hoverScale : 1.0))
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: hovered)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
            .onHover { hovered = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded   { _ in pressed = false }
            )
    }
}

// MARK: - Hoverable button style (used on round action buttons)

struct HoverPressButtonStyle: ButtonStyle {
    @State private var hovered = false
    var hoverScale: CGFloat = 1.05
    var pressScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressScale : (hovered ? hoverScale : 1.0))
            .brightness(hovered && !configuration.isPressed ? 0.04 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: hovered)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: configuration.isPressed)
            .onHover { hovered = $0 }
    }
}

// MARK: - Key-cap chip (used for hotkey display)

struct KeyCapView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
            .frame(minWidth: 22)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

// MARK: - Status dot (animated when active)

struct StatusDot: View {
    let color: Color
    var pulsing: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            // halo
            if pulsing {
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
            }
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.7), radius: pulsing ? 4 : 0)
        }
        .frame(width: 14, height: 14)
        .onAppear { if pulsing { pulse = true } }
        .onChange(of: pulsing) { newValue in pulse = newValue }
    }
}

// MARK: - Brand mark (used in header)

struct BrandMark: View {
    var size: CGFloat = 30
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.32, blue: 0.32),
                            Color(red: 0.78, green: 0.13, blue: 0.13),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: .red.opacity(0.35), radius: 4, x: 0, y: 2)

            // Inner record glyph
            Circle()
                .strokeBorder(.white, lineWidth: size * 0.06)
                .frame(width: size * 0.5, height: size * 0.5)
            Circle()
                .fill(.white)
                .frame(width: size * 0.27, height: size * 0.27)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Window-style helpers

extension NSWindow {
    func applyPolish() {
        titlebarAppearsTransparent = true
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = false
        if let frameAutosaveName = self.frameAutosaveName as String?, frameAutosaveName.isEmpty {
            setFrameAutosaveName("TinyRecorder.MacroEditor")
        }
    }
}

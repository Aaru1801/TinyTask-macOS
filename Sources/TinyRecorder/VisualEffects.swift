import SwiftUI
import AppKit

// MARK: - Brand design tokens

enum Brand {
    static let redTop    = Color(red: 0.97, green: 0.32, blue: 0.32)
    static let redBottom = Color(red: 0.78, green: 0.13, blue: 0.13)

    static var redGradient: LinearGradient {
        LinearGradient(colors: [redTop, redBottom], startPoint: .top, endPoint: .bottom)
    }

    /// The one spring used for state changes app-wide — consistent motion.
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.85)

    /// A flat tint approximating the brand red, for tinting Liquid Glass.
    static let redTint = Color(red: 0.88, green: 0.22, blue: 0.22)

    /// Builds a configured Liquid Glass variant. macOS 26+ only.
    @available(macOS 26.0, *)
    static func glass(tint: Color? = nil, interactive: Bool = false) -> Glass {
        var g: Glass = .regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}

// MARK: - Liquid Glass (macOS 26+) with graceful fallback

extension View {
    /// Renders a Liquid Glass material behind the view on macOS 26+, clipped to
    /// `shape`. On earlier systems it falls back to a translucent filled shape so
    /// the app keeps the same silhouette down to macOS 13.
    @ViewBuilder
    func liquidGlass<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        fallbackFill: Color = Color.primary.opacity(0.06),
        fallbackStroke: Color = Color.primary.opacity(0.10)
    ) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(Brand.glass(tint: tint, interactive: interactive), in: shape)
        } else {
            background(
                shape
                    .fill(tint.map { AnyShapeStyle($0.opacity(0.85)) } ?? AnyShapeStyle(fallbackFill))
                    .overlay(shape.strokeBorder(fallbackStroke, lineWidth: 0.5))
            )
        }
    }

    /// Prominent, tinted capsule control: interactive tinted Liquid Glass on
    /// macOS 26+, a tinted gradient capsule on earlier systems.
    @ViewBuilder
    func prominentGlassCapsule(tint: Color, gradientFallback: [Color]? = nil) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(Brand.glass(tint: tint, interactive: true), in: Capsule(style: .continuous))
        } else {
            background(
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        colors: gradientFallback ?? [tint.opacity(0.95), tint.opacity(0.78)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                    )
                    .shadow(color: tint.opacity(0.30), radius: 3, x: 0, y: 2)
            )
        }
    }
}

/// Wraps content in a `GlassEffectContainer` on macOS 26+ so neighbouring glass
/// shapes blend and morph together; a passthrough on earlier systems.
struct GlassChrome<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

/// The "tiny Recorder" wordmark from the brand mockups.
struct Wordmark: View {
    var size: CGFloat = 13
    var body: some View {
        HStack(spacing: 3) {
            Text("tiny")
                .font(.system(size: size, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
            Text("Recorder")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TinyRecorder")
    }
}

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
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 5, style: .continuous),
                fallbackFill: Color.primary.opacity(0.08),
                fallbackStroke: Color.primary.opacity(0.18)
            )
            .accessibilityLabel("Shortcut \(text)")
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
                        colors: [Brand.redTop, Brand.redBottom],
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
        .accessibilityHidden(true)
    }
}

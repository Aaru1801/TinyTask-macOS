import SwiftUI
import AppKit

/// Finder-style live activity surface shared by the Dock window and menu-bar
/// popover. It turns the app's otherwise terse status strings into useful,
/// glanceable recording/playback telemetry without keeping a large dashboard
/// on screen while TinyRecorder is idle.
struct ActivityCenterView: View {
    let controller: MenuBarController
    var compact = false

    @EnvironmentObject private var recorder: Recorder
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var library: MacroLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode: Equatable { case countdown, recording, playback }

    private var mode: Mode {
        if state.recordingCountdownActive { return .countdown }
        if recorder.isRecording { return .recording }
        return .playback
    }

    private var macro: SavedMacro? {
        if mode == .playback, let id = controller.playingMacroID {
            return library.macros.first(where: { $0.id == id })
        }
        return library.currentMacro
    }

    private var tint: Color {
        switch mode {
        case .countdown: return Brand.sigAmber
        case .recording: return Brand.red500
        case .playback:  return cardAccentColor(for: macro?.accent)
        }
    }

    private var title: String {
        switch mode {
        case .countdown: return L10n.text("Preparing to record")
        case .recording: return L10n.text("Recording")
        case .playback:  return macro?.name ?? L10n.text("Playing macro")
        }
    }

    private var subtitle: String {
        switch mode {
        case .countdown:
            return L10n.text("Switch to the app you want to capture")
        case .recording:
            return L10n.text("Listening for mouse and keyboard input")
        case .playback:
            guard let macro else { return L10n.text("Replaying captured input") }
            return L10n.text("%@ events · %@ · %@", String(describing: macro.eventCount), String(describing: formatActivityDuration(macro.duration)), String(describing: formatActivitySpeed(macro.speed)))
        }
    }

    private var progress: Double? {
        switch mode {
        case .countdown, .recording: return nil
        case .playback: return player.isContinuous ? player.progress : player.overallProgress
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                activityIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: compact ? 13 : 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: compact ? 11 : 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
                controls
            }

            ActivityProgressBar(value: progress, tint: tint)
                .frame(height: 4)
                .accessibilityLabel(progressAccessibilityLabel)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    primaryDetailLabel
                    Spacer(minLength: 0)
                    secondaryDetailLabel
                }
                VStack(alignment: .leading, spacing: 4) {
                    primaryDetailLabel
                    secondaryDetailLabel
                }
            }
        }
        .padding(compact ? 13 : 16)
        .background(activityBackground)
        .accessibilityElement(children: .contain)
    }

    private var primaryDetailLabel: some View {
        Text(primaryDetail)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
    }

    private var secondaryDetailLabel: some View {
        Text(secondaryDetail)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
    }

    private var activityIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.10))
            if mode == .recording {
                RecDot(size: 9, color: tint)
            } else {
                Image(systemName: activitySymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: mode == .countdown && !reduceMotion)
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private var activitySymbol: String {
        switch mode {
        case .countdown: return "timer"
        case .recording: return "record.circle.fill"
        case .playback:  return macro?.icon ?? "play.fill"
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 6) {
            if mode == .recording {
                activityButton(
                    symbol: "trash",
                    help: L10n.text("Discard recording"),
                    tint: .secondary,
                    action: controller.cancelRecording
                )
            }
            activityButton(
                symbol: mode == .countdown ? "xmark" : "stop.fill",
                help: primaryControlHelp,
                tint: mode == .recording ? Brand.red500 : .secondary
            ) {
                if mode == .playback { controller.stopAll() }
                else { controller.toggleRecording() }
            }
        }
    }

    private var primaryControlHelp: String {
        switch mode {
        case .countdown: return L10n.text("Cancel recording countdown")
        case .recording: return L10n.text("Stop and save recording")
        case .playback:  return L10n.text("Stop playback")
        }
    }

    private func activityButton(
        symbol: String,
        help: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var activityBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private var primaryDetail: String {
        switch mode {
        case .countdown:
            return L10n.text("Starting shortly")
        case .recording:
            return L10n.text("%@ recorded · %@ events", String(describing: formatActivityDuration(recorder.liveDuration)), String(describing: recorder.eventCount))
        case .playback:
            if player.isContinuous {
                return L10n.text("Loop %@ · Continuous", String(describing: max(1, player.currentLoop)))
            }
            let percent = Int((player.overallProgress * 100).rounded(.down))
            return L10n.text("%@%% done — %@", String(describing: percent), String(describing: remainingText))
        }
    }

    private var secondaryDetail: String {
        switch mode {
        case .countdown:
            return L10n.text("%@ cancel", String(describing: state.recordHotkey.name))
        case .recording:
            let stats = recorder.liveStats
            return L10n.text("%@ clicks · %@ keys", String(describing: stats.clicks), String(describing: stats.keys))
        case .playback:
            let loop = max(1, player.currentLoop)
            let events = L10n.text("%@/%@ events", String(describing: player.currentEvent), String(describing: max(1, player.totalEvents)))
            return player.isContinuous
                ? L10n.text("%@ · loop %@", String(describing: events), String(describing: loop))
                : L10n.text("%@ · loop %@/%@", String(describing: events), String(describing: loop), String(describing: max(1, player.totalLoops)))
        }
    }

    private var remainingText: String {
        guard let macro else { return L10n.text("finishing soon") }
        let singleRun = macro.duration / max(0.1, macro.speed)
        let total = singleRun * Double(max(1, player.totalLoops))
        let remaining = total * (1 - player.overallProgress)
        if remaining < 0.5 { return L10n.text("finishing now") }
        return L10n.text("about %@ remaining", String(describing: formatActivityDuration(remaining)))
    }

    private var progressAccessibilityLabel: String {
        switch mode {
        case .countdown: return L10n.text("Preparing recording")
        case .recording: return L10n.text("Recording in progress, %@ events captured", String(describing: recorder.eventCount))
        case .playback:
            if player.isContinuous { return L10n.text("Continuous playback, loop %@", String(describing: max(1, player.currentLoop))) }
            return L10n.text("Playback %@ percent complete", String(describing: Int((player.overallProgress * 100).rounded())))
        }
    }
}

private struct ActivityProgressBar: View {
    let value: Double?
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))

                if let value {
                    let clamped = max(0, min(1, value))
                    progressFill
                        .frame(width: max(clamped > 0 ? 5 : 0, width * clamped))
                        .animation(reduceMotion ? nil : .linear(duration: 0.10), value: clamped)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { context in
                        let phase = reduceMotion
                            ? 0.5
                            : context.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 1.6) / 1.6
                        progressFill
                            .frame(width: width * 0.34)
                            .offset(x: -width * 0.34 + width * 1.34 * phase)
                    }
                }
            }
            .clipShape(Capsule(style: .continuous))
        }
    }

    private var progressFill: some View {
        Capsule(style: .continuous)
            .fill(tint)
    }
}

private func formatActivityDuration(_ seconds: TimeInterval) -> String {
    let value = max(0, seconds.isFinite ? seconds : 0)
    if value < 10 { return L10n.text("%.1fs", value) }
    if value < 60 { return L10n.text("%@s", String(describing: Int(value.rounded()))) }
    if value >= 31_536_000 {
        let years = value / 31_536_000
        if years >= 1_000_000 { return L10n.text("over 1M years") }
        return L10n.text(years < 10 ? "%.1fy" : "%.0fy", years)
    }
    if value >= 86_400 {
        let days = Int(value / 86_400)
        let hours = Int(value.truncatingRemainder(dividingBy: 86_400)) / 3_600
        return hours > 0 ? L10n.text("%@d %@h", String(describing: days), String(describing: hours)) : L10n.text("%@d", String(describing: days))
    }
    let minutes = Int(value) / 60
    let remainder = Int(value) % 60
    if minutes < 60 { return String(format: "%d:%02d", minutes, remainder) }
    let hours = minutes / 60
    return L10n.text("%@h %@m", String(describing: hours), String(describing: minutes % 60))
}

private func formatActivitySpeed(_ speed: Double) -> String {
    if abs(speed.rounded() - speed) < 0.01 { return "\(Int(speed.rounded()))×" }
    return String(format: "%.2g×", speed)
}

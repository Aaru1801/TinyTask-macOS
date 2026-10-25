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
        case .countdown: return "Preparing to record"
        case .recording: return "Recording"
        case .playback:  return macro?.name ?? "Playing macro"
        }
    }

    private var subtitle: String {
        switch mode {
        case .countdown:
            return "Switch to the app you want to capture"
        case .recording:
            return "Listening for mouse and keyboard input"
        case .playback:
            guard let macro else { return "Replaying captured input" }
            return "\(macro.eventCount) events · \(formatActivityDuration(macro.duration)) · \(formatActivitySpeed(macro.speed))"
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
                    help: "Discard recording",
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
        case .countdown: return "Cancel recording countdown"
        case .recording: return "Stop and save recording"
        case .playback:  return "Stop playback"
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
            return "Starting shortly"
        case .recording:
            return "\(formatActivityDuration(recorder.liveDuration)) recorded · \(recorder.eventCount) events"
        case .playback:
            if player.isContinuous {
                return "Loop \(max(1, player.currentLoop)) · Continuous"
            }
            let percent = Int((player.overallProgress * 100).rounded(.down))
            return "\(percent)% done — \(remainingText)"
        }
    }

    private var secondaryDetail: String {
        switch mode {
        case .countdown:
            return "\(state.recordHotkey.name) cancel"
        case .recording:
            let stats = recorder.liveStats
            return "\(stats.clicks) clicks · \(stats.keys) keys"
        case .playback:
            let loop = max(1, player.currentLoop)
            let events = "\(player.currentEvent)/\(max(1, player.totalEvents)) events"
            return player.isContinuous
                ? "\(events) · loop \(loop)"
                : "\(events) · loop \(loop)/\(max(1, player.totalLoops))"
        }
    }

    private var remainingText: String {
        guard let macro else { return "finishing soon" }
        let singleRun = macro.duration / max(0.1, macro.speed)
        let total = singleRun * Double(max(1, player.totalLoops))
        let remaining = total * (1 - player.overallProgress)
        if remaining < 0.5 { return "finishing now" }
        return "about \(formatActivityDuration(remaining)) remaining"
    }

    private var progressAccessibilityLabel: String {
        switch mode {
        case .countdown: return "Preparing recording"
        case .recording: return "Recording in progress, \(recorder.eventCount) events captured"
        case .playback:
            if player.isContinuous { return "Continuous playback, loop \(max(1, player.currentLoop))" }
            return "Playback \(Int((player.overallProgress * 100).rounded())) percent complete"
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
    if value < 10 { return String(format: "%.1fs", value) }
    if value < 60 { return "\(Int(value.rounded()))s" }
    if value >= 31_536_000 {
        let years = value / 31_536_000
        if years >= 1_000_000 { return "over 1M years" }
        return String(format: years < 10 ? "%.1fy" : "%.0fy", years)
    }
    if value >= 86_400 {
        let days = Int(value / 86_400)
        let hours = Int(value.truncatingRemainder(dividingBy: 86_400)) / 3_600
        return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
    }
    let minutes = Int(value) / 60
    let remainder = Int(value) % 60
    if minutes < 60 { return String(format: "%d:%02d", minutes, remainder) }
    let hours = minutes / 60
    return "\(hours)h \(minutes % 60)m"
}

private func formatActivitySpeed(_ speed: Double) -> String {
    if abs(speed.rounded() - speed) < 0.01 { return "\(Int(speed.rounded()))×" }
    return String(format: "%.2g×", speed)
}

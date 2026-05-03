import Cocoa
import SwiftUI
import Combine

// MARK: - Window controller

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    init<V: View>(rootView: V) {
        let host = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: host)
        win.title = "Macro Editor"
        win.setContentSize(NSSize(width: 820, height: 580))
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        win.minSize = NSSize(width: 680, height: 460)
        win.isReleasedWhenClosed = false
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .visible
        win.isMovableByWindowBackground = false
        win.backgroundColor = .clear
        win.setFrameAutosaveName("TinyRecorder.MacroEditor")
        super.init(window: win)
        win.delegate = self
        if win.frameAutosaveName.isEmpty { win.center() }
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Row model

struct EventRow: Identifiable {
    let id: Int            // original index in recorder.events
    let event: RecordedEvent
}

// MARK: - Editor view

struct EditorView: View {
    let controller: MenuBarController
    @EnvironmentObject var recorder: Recorder
    @EnvironmentObject var player: Player
    @EnvironmentObject var library: MacroLibrary
    @EnvironmentObject var state: AppState

    @State private var selection: Set<Int> = []
    @State private var hideMouseMoves = false
    @State private var stretchFactor: Double = 1.0
    @State private var shiftMs: Double = 100

    @State private var inspTime: String = ""
    @State private var inspX: String = ""
    @State private var inspY: String = ""
    @State private var inspKey: String = ""

    var rows: [EventRow] {
        recorder.events.enumerated().compactMap { idx, ev in
            if hideMouseMoves, ev.kind == .mouseMoved
                || ev.kind == .leftMouseDragged
                || ev.kind == .rightMouseDragged
                || ev.kind == .otherMouseDragged {
                return nil
            }
            return EventRow(id: idx, event: ev)
        }
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .windowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                EditorToolbar(
                    macro: library.currentMacro,
                    rowCount: recorder.events.count,
                    duration: recorder.events.last?.time ?? 0,
                    hideMouseMoves: $hideMouseMoves,
                    onPlay:    { controller.play() },
                    onStop:    { controller.stopAll() },
                    onExport:  { controller.exportAsScript() },
                    playing:   player.isPlaying
                )

                HSplitView {
                    EditorSidebar(
                        selection: $selection,
                        rows: rows,
                        stretchFactor: $stretchFactor,
                        shiftMs: $shiftMs,
                        inspTime: $inspTime,
                        inspX: $inspX,
                        inspY: $inspY,
                        inspKey: $inspKey,
                        recorder: recorder,
                        onLoadInspector: loadInspector
                    )
                    .frame(minWidth: 240, idealWidth: 260, maxWidth: 300)

                    VStack(spacing: 0) {
                        EditorTimeline(
                            events: recorder.events,
                            selection: $selection,
                            playProgress: player.isPlaying ? player.progress : nil
                        )
                        .padding(14)

                        Divider().opacity(0.5)

                        EventTableView(rows: rows, selection: $selection)
                    }
                    .frame(minWidth: 420)
                }

                EditorFooter(eventCount: recorder.events.count,
                             selectedCount: selection.count,
                             duration: recorder.events.last?.time ?? 0)
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .onChange(of: selection) { _ in loadInspector() }
        .onDisappear { controller.persistEdits() }
    }

    private func loadInspector() {
        if selection.count == 1, let id = selection.first,
           let ev = recorder.events.indices.contains(id) ? recorder.events[id] : nil {
            inspTime = String(format: "%.4f", ev.time)
            inspX = String(format: "%.0f", ev.x)
            inspY = String(format: "%.0f", ev.y)
            inspKey = String(ev.keyCode)
        } else {
            inspTime = ""; inspX = ""; inspY = ""; inspKey = ""
        }
    }
}

// MARK: - Header

private struct EditorToolbar: View {
    let macro: SavedMacro?
    let rowCount: Int
    let duration: TimeInterval
    @Binding var hideMouseMoves: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onExport: () -> Void
    let playing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                BrandMark(size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(macro?.name ?? "Untitled macro")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Label("\(rowCount) events", systemImage: "wave.3.right")
                        Text("·").foregroundStyle(.tertiary)
                        Label(formatDuration(duration), systemImage: "clock")
                        if let m = macro {
                            Text("·").foregroundStyle(.tertiary)
                            Text("edited \(RelativeTime.string(from: m.modifiedAt))")
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                }

                Spacer()

                // Hide mouse moves switch
                Toggle(isOn: $hideMouseMoves) {
                    Label("Hide mouse moves", systemImage: "eye.slash.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(.green)

                // Export
                Button(action: onExport) {
                    Label("Export…", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .controlSize(.regular)
                .buttonStyle(.bordered)

                // Play / Stop
                Button {
                    playing ? onStop() : onPlay()
                } label: {
                    Label(playing ? "Stop" : "Play",
                          systemImage: playing ? "stop.fill" : "play.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .keyboardShortcut(.space, modifiers: [])
                .controlSize(.regular)
                .tint(playing ? .red : .green)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Divider()
        }
        .background(VisualEffectBackground(material: .titlebar, blendingMode: .withinWindow))
    }
}

// MARK: - Timeline

private struct EditorTimeline: View {
    let events: [RecordedEvent]
    @Binding var selection: Set<Int>
    let playProgress: Double?

    @State private var hoverFraction: Double?
    @State private var dragRange: (start: Double, end: Double)?
    @GestureState private var isDragging = false

    private var totalDuration: TimeInterval { events.last?.time ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TIMELINE")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Spacer()
                LegendChip(label: "Click",  tint: .green)
                LegendChip(label: "Key",    tint: .blue)
                LegendChip(label: "Drag",   tint: .purple)
                LegendChip(label: "Scroll", tint: .teal)
                LegendChip(label: "Move",   tint: .secondary)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                        )

                    // Event bars
                    ForEach(0..<min(events.count, 800), id: \.self) { i in
                        let stride = max(1, events.count / 800)
                        let idx = i * stride
                        if idx < events.count {
                            let ev = events[idx]
                            let x = totalDuration > 0
                                ? CGFloat(ev.time / totalDuration) * w
                                : 0
                            let isImpact = ev.kind == .leftMouseDown || ev.kind == .rightMouseDown ||
                                           ev.kind == .keyDown
                            Rectangle()
                                .fill(eventColor(for: ev.kind))
                                .frame(width: isImpact ? 1.6 : 1, height: isImpact ? h * 0.85 : h * 0.45)
                                .position(x: x, y: h / 2)
                        }
                    }

                    // Selection range
                    if let r = selectionRange(in: w) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                            .overlay(
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: 1.5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .offset(x: r.start)
                            )
                            .frame(width: max(2, r.end - r.start), height: h)
                            .offset(x: r.start)
                    }

                    // Drag preview
                    if let dr = dragRange {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: max(2, CGFloat(abs(dr.end - dr.start)) * w), height: h)
                            .offset(x: CGFloat(min(dr.start, dr.end)) * w)
                    }

                    // Playhead
                    if let p = playProgress {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 2, height: h)
                            .offset(x: CGFloat(p) * w)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isDragging) { _, s, _ in s = true }
                        .onChanged { val in
                            let s = Double(max(0, min(1, val.startLocation.x / w)))
                            let e = Double(max(0, min(1, val.location.x / w)))
                            dragRange = (s, e)
                        }
                        .onEnded { _ in
                            if let dr = dragRange {
                                let lo = min(dr.start, dr.end) * totalDuration
                                let hi = max(dr.start, dr.end) * totalDuration
                                let newSel = Set(events.enumerated()
                                    .filter { $0.element.time >= lo && $0.element.time <= hi }
                                    .map { $0.offset })
                                if newSel.isEmpty {
                                    // Treat as click — select nearest event.
                                    let target = (dr.start + dr.end) / 2 * totalDuration
                                    if let idx = nearestEvent(to: target) {
                                        selection = [idx]
                                    }
                                } else {
                                    selection = newSel
                                }
                            }
                            dragRange = nil
                        }
                )
            }
            .frame(height: 50)

            HStack {
                Text(formatTime(0))
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(totalDuration / 2))
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(totalDuration))
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let id = selection.first, selection.count == 1, events.indices.contains(id) {
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text(formatTime(events[id].time))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
                }
                Text("Drag on timeline to select a range · ⌥-drag to extend")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func selectionRange(in width: CGFloat) -> (start: CGFloat, end: CGFloat)? {
        guard !selection.isEmpty, totalDuration > 0 else { return nil }
        let times = selection.compactMap { events.indices.contains($0) ? events[$0].time : nil }
        guard let lo = times.min(), let hi = times.max() else { return nil }
        let s = CGFloat(lo / totalDuration) * width
        let e = CGFloat(hi / totalDuration) * width
        return (s, e)
    }

    private func nearestEvent(to t: TimeInterval) -> Int? {
        guard !events.isEmpty else { return nil }
        var bestIdx = 0
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for (i, e) in events.enumerated() {
            let d = abs(e.time - t)
            if d < bestDelta {
                bestDelta = d
                bestIdx = i
            }
        }
        return bestIdx
    }

    private func formatTime(_ d: TimeInterval) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        let cs = Int((d - floor(d)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }

    private func eventColor(for kind: RecordedEvent.Kind) -> Color {
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

private struct LegendChip: View {
    let label: String
    let tint: Color
    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sidebar (tools + inspector)

private struct EditorSidebar: View {
    @Binding var selection: Set<Int>
    let rows: [EventRow]
    @Binding var stretchFactor: Double
    @Binding var shiftMs: Double
    @Binding var inspTime: String
    @Binding var inspX: String
    @Binding var inspY: String
    @Binding var inspKey: String
    let recorder: Recorder
    let onLoadInspector: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section("Selection", icon: "checklist") {
                    Button(action: deleteSelected) {
                        Label("Delete selected", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(selection.isEmpty)

                    HStack(spacing: 6) {
                        Button(action: trimBefore) {
                            Label("Trim before", systemImage: "arrow.left.to.line")
                        }
                        .frame(maxWidth: .infinity)
                        .help("Delete every event before the selected one")

                        Button(action: trimAfter) {
                            Label("Trim after", systemImage: "arrow.right.to.line")
                        }
                        .frame(maxWidth: .infinity)
                        .help("Delete every event after the selected one")
                    }
                    .controlSize(.small)
                    .disabled(selection.count != 1)

                    Button(role: .destructive, action: clearAll) {
                        Label("Clear all", systemImage: "trash.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(rows.isEmpty)
                }

                section("Time stretch", icon: "speedometer") {
                    Slider(value: $stretchFactor, in: 0.25...4.0, step: 0.05) {
                        Text("Stretch")
                    } minimumValueLabel: {
                        Text("0.25×").font(.system(size: 9))
                    } maximumValueLabel: {
                        Text("4×").font(.system(size: 9))
                    }
                    .controlSize(.small)
                    .labelsHidden()

                    HStack {
                        Text(String(format: "%.2f×", stretchFactor))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                        Spacer()
                        Button("Reset") { stretchFactor = 1.0 }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                    }
                    Text("> 1× slower · < 1× faster.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Button(action: applyStretch) {
                        Label("Apply to all events", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(rows.isEmpty || abs(stretchFactor - 1.0) < 0.001)
                }

                section("Shift selected", icon: "arrow.left.and.right") {
                    Stepper(value: $shiftMs, in: 1...10000, step: 50) {
                        Text("\(Int(shiftMs)) ms")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                    .controlSize(.small)

                    HStack(spacing: 6) {
                        Button { shiftSelection(by: -shiftMs / 1000.0) } label: {
                            Label("Earlier", systemImage: "minus")
                        }
                        .frame(maxWidth: .infinity)

                        Button { shiftSelection(by:  shiftMs / 1000.0) } label: {
                            Label("Later", systemImage: "plus")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)
                    .disabled(selection.isEmpty)
                }

                section("Inspector", icon: "info.circle") {
                    if selection.count == 1, let id = selection.first,
                       recorder.events.indices.contains(id) {
                        let ev = recorder.events[id]
                        HStack {
                            Image(systemName: kindIcon(ev.kind))
                                .foregroundStyle(kindColor(ev.kind))
                                .font(.system(size: 12))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Event #\(id + 1)")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(humanKindName(ev.kind))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        labeledField("Time (s)", text: $inspTime)
                        if ev.kind.isMouse {
                            HStack(spacing: 6) {
                                labeledField("X", text: $inspX)
                                labeledField("Y", text: $inspY)
                            }
                        }
                        if ev.kind.isKey {
                            labeledField("Key code", text: $inspKey)
                            if let name = keyName(UInt16(inspKey) ?? ev.keyCode) {
                                Text("Key: \(name)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(action: applyInspector) {
                            Label("Apply changes", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else if selection.count > 1 {
                        emptyInspector(
                            icon: "square.stack",
                            title: "\(selection.count) events selected",
                            subtitle: "Select one event to edit fields"
                        )
                    } else {
                        emptyInspector(
                            icon: "hand.tap",
                            title: "No selection",
                            subtitle: "Click a row to inspect or edit"
                        )
                    }
                }
            }
            .padding(14)
        }
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(10)
                .cardSurface(cornerRadius: 10)
        }
    }

    @ViewBuilder
    private func emptyInspector(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.4)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .controlSize(.small)
        }
    }

    // MARK: - Actions

    private func deleteSelected() {
        let idx = IndexSet(selection)
        selection.removeAll()
        recorder.deleteEvents(at: idx)
    }

    private func trimBefore() {
        guard selection.count == 1, let id = selection.first else { return }
        recorder.trimBefore(index: id)
        selection = [0]
    }

    private func trimAfter() {
        guard selection.count == 1, let id = selection.first else { return }
        recorder.trimAfter(index: id)
        selection = [id]
    }

    private func clearAll() {
        selection.removeAll()
        recorder.clearAll()
    }

    private func applyStretch() {
        recorder.scaleTime(by: stretchFactor)
        stretchFactor = 1.0
    }

    private func shiftSelection(by delta: TimeInterval) {
        recorder.shiftTime(of: IndexSet(selection), by: delta)
    }

    private func applyInspector() {
        guard selection.count == 1, let id = selection.first,
              recorder.events.indices.contains(id) else { return }
        var ev = recorder.events[id]
        if let t = TimeInterval(inspTime) { ev.time = max(0, t) }
        if let x = Double(inspX) { ev.x = CGFloat(x) }
        if let y = Double(inspY) { ev.y = CGFloat(y) }
        if let k = UInt16(inspKey) { ev.keyCode = k }
        recorder.updateEvent(at: id, with: ev)
        onLoadInspector()
    }
}

// MARK: - Table

private struct EventTableView: View {
    let rows: [EventRow]
    @Binding var selection: Set<Int>

    var body: some View {
        Table(rows, selection: $selection) {
            TableColumn("#") { row in
                Text("\(row.id + 1)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(min: 40, ideal: 50, max: 70)

            TableColumn("Time") { row in
                Text(String(format: "%.3fs", row.event.time))
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 70, ideal: 80, max: 100)

            TableColumn("Type") { row in
                Label {
                    Text(humanKindName(row.event.kind))
                } icon: {
                    Image(systemName: kindIcon(row.event.kind))
                        .foregroundColor(kindColor(row.event.kind))
                }
                .labelStyle(.titleAndIcon)
            }
            .width(min: 130, ideal: 160)

            TableColumn("Position") { row in
                if row.event.kind.isMouse {
                    Text("(\(Int(row.event.x)), \(Int(row.event.y)))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("—").foregroundColor(.secondary.opacity(0.5))
                }
            }
            .width(min: 100, ideal: 110)

            TableColumn("Key") { row in
                if row.event.kind.isKey {
                    Text(keyName(row.event.keyCode) ?? "code \(row.event.keyCode)")
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("—").foregroundColor(.secondary.opacity(0.5))
                }
            }
            .width(min: 90, ideal: 110)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Footer

private struct EditorFooter: View {
    let eventCount: Int
    let selectedCount: Int
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                Label("\(eventCount) events", systemImage: "wave.3.right")
                Text("·").foregroundStyle(.tertiary)
                Label(formatDuration(duration), systemImage: "clock")
                if selectedCount > 0 {
                    Text("·").foregroundStyle(.tertiary)
                    Label("\(selectedCount) selected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
                Spacer()
                Text("Edits apply live · use Save to persist")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .labelStyle(.titleAndIcon)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
        .background(VisualEffectBackground(material: .titlebar, blendingMode: .withinWindow))
    }
}

// MARK: - Helpers

func formatDuration(_ d: TimeInterval) -> String {
    let m = Int(d) / 60
    let s = Int(d) % 60
    let cs = Int((d - floor(d)) * 100)
    return String(format: "%02d:%02d.%02d", m, s, cs)
}

func humanKindName(_ k: RecordedEvent.Kind) -> String {
    switch k {
    case .leftMouseDown:     return "Left Click ↓"
    case .leftMouseUp:       return "Left Click ↑"
    case .rightMouseDown:    return "Right Click ↓"
    case .rightMouseUp:      return "Right Click ↑"
    case .mouseMoved:        return "Mouse Move"
    case .leftMouseDragged:  return "Left Drag"
    case .rightMouseDragged: return "Right Drag"
    case .otherMouseDown:    return "Other Click ↓"
    case .otherMouseUp:      return "Other Click ↑"
    case .otherMouseDragged: return "Other Drag"
    case .keyDown:           return "Key Down"
    case .keyUp:             return "Key Up"
    case .flagsChanged:      return "Modifier"
    case .scrollWheel:       return "Scroll"
    }
}

func kindIcon(_ k: RecordedEvent.Kind) -> String {
    if k.isKey { return "keyboard" }
    switch k {
    case .leftMouseDown, .leftMouseUp:           return "cursorarrow.click"
    case .rightMouseDown, .rightMouseUp:         return "cursorarrow.click.2"
    case .mouseMoved:                            return "arrow.up.left.and.arrow.down.right"
    case .leftMouseDragged, .rightMouseDragged,
         .otherMouseDragged:                     return "hand.draw"
    case .scrollWheel:                           return "arrow.up.and.down"
    case .otherMouseDown, .otherMouseUp:         return "circle.grid.cross"
    default:                                     return "circle"
    }
}

func kindColor(_ k: RecordedEvent.Kind) -> Color {
    if k.isKey { return .blue }
    switch k {
    case .leftMouseDown, .leftMouseUp:    return .green
    case .rightMouseDown, .rightMouseUp:  return .orange
    case .mouseMoved:                     return .gray
    case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
        return .purple
    case .scrollWheel:                    return .teal
    default:                              return .secondary
    }
}

/// Human-readable name for a small set of common Mac keycodes.
func keyName(_ code: UInt16) -> String? {
    let map: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
        26: "7", 28: "8", 25: "9", 29: "0",
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 122: "F1", 120: "F2",
        99: "F3", 118: "F4",
        55: "⌘", 56: "⇧", 58: "⌥", 59: "⌃",
    ]
    return map[code]
}

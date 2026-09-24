import AppKit
import Observation
import SwiftUI
import TimeZonerLib

private let calendarPermissionProbeMarker = "calendar-permission-probe"

struct CalendarPermissionProbeView: View {
    @State private var model = CalendarPermissionProbeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar permission probe")
                .font(.title2.weight(.semibold))

            Text("Status: \(model.status.displayName)")
                .font(.body)

            switch model.status {
            case .notDetermined:
                Text("TimeZoner reads your calendars to count upcoming events in this packaged probe.")
                    .foregroundStyle(.secondary)
                Button("Enable Calendar") {
                    model.requestAccess()
                }
            case .fullAccess:
                Text("Calendars: \(model.calendarCount)")
                Text("Events in the next 7 days: \(model.eventCount)")
                Button("Refresh Calendar Counts") {
                    model.loadCountsIfAuthorized()
                }
            case .denied, .restricted, .writeOnly:
                Text("Calendar events are unavailable to this probe.")
                    .foregroundStyle(.secondary)
                Button("Open Calendar Privacy Settings") {
                    CalendarPermissionProbeModel.openCalendarPrivacySettings()
                }
            }

            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(calendarPermissionProbeMarker)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 420, height: 300, alignment: .topLeading)
        .task {
            model.loadCountsIfAuthorized()
        }
    }
}

@MainActor
@Observable
final class CalendarPermissionProbeModel {
    private let provider: any CalendarEventReading

    var status: CalendarAuthorizationStatus
    var calendarCount = 0
    var eventCount = 0
    var isLoading = false
    var errorMessage: String?

    init(provider: any CalendarEventReading = EventKitCalendarProvider()) {
        self.provider = provider
        status = provider.authorizationStatus
    }

    func requestAccess() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                _ = try await provider.requestAccess()
                status = provider.authorizationStatus
                if status == .fullAccess {
                    try await fetchCounts()
                }
            } catch {
                status = provider.authorizationStatus
                errorMessage = "Calendar access request failed: \(error.localizedDescription)"
            }
        }
    }

    func loadCountsIfAuthorized() {
        status = provider.authorizationStatus
        guard status == .fullAccess, !isLoading else {
            if status != .fullAccess {
                calendarCount = 0
                eventCount = 0
            }
            return
        }

        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await fetchCounts()
            } catch {
                errorMessage = "Calendar fetch failed: \(error.localizedDescription)"
            }
        }
    }

    private func fetchCounts() async throws {
        let calendars = try await provider.calendars()
        let start = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        let end = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 7, to: start) ?? start
        let events = try await provider.events(
            from: start,
            to: end,
            calendarIDs: Set(calendars.map(\.id))
        )
        calendarCount = calendars.count
        eventCount = events.count
    }

    static func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private extension CalendarAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            "Not determined"
        case .restricted:
            "Restricted"
        case .denied:
            "Denied"
        case .fullAccess:
            "Full access"
        case .writeOnly:
            "Write only"
        }
    }
}

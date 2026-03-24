import SwiftUI

public struct ContentView: View {
    @State private var timeState = TimeState()
    @State private var zoneStore = ZoneStore()

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            ChatField(timeState: timeState, zoneStore: zoneStore)

            ZoneCardRow(zones: zoneStore.zones, timeState: timeState, onRemove: { id in
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoneStore.remove(id: id)
                }
            })

            TimeScrubber(timeState: timeState)
        }
        .padding(20)
        .frame(minWidth: 400)
        .background(.ultraThinMaterial)
    }
}

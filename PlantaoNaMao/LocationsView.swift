import SwiftUI

struct LocationsView: View {
    @EnvironmentObject private var store: ShiftStore
    var body: some View {
        NavigationStack {
            List {
                if store.locations.isEmpty {
                    ContentUnavailableView("Seus locais de trabalho", systemImage: "building.2", description: Text("Os locais aparecem aqui quando você cadastra seus plantões."))
                }
                ForEach(store.locations, id: \.self) { location in
                    NavigationLink {
                        LocationDetailView(location: location)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2.crop.circle.fill").font(.title).foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location).font(.headline)
                                Text("\(store.shifts.filter { $0.location == location }.count) plantões cadastrados").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }.navigationTitle("Locais de trabalho")
        }
    }
}

struct LocationDetailView: View {
    @EnvironmentObject private var store: ShiftStore
    let location: String
    @State private var editing: Shift?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.shifts.filter { $0.location == location }.sorted { $0.interval.start > $1.interval.start }) { shift in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shift.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        Button { editing = shift } label: { ShiftRow(shift: shift) }.buttonStyle(.plain)
                    }
                }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle(location)
            .sheet(item: $editing) { ShiftEditor(date: $0.date, shift: $0) }
    }
}

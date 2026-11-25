import SwiftUI
import AppKit

enum MacDestination: Int, CaseIterable, Identifiable {
    case schedule, finance, dashboard, locations
    var id: Int { rawValue }
    var title: String { ["Plantões", "Financeiro", "Painel", "Locais"][rawValue] }
    var icon: String { ["calendar", "chart.bar.xaxis", "chart.bar.fill", "building.2"][rawValue] }
}

struct MacRootView: View {
    @EnvironmentObject private var auth: GoogleAuthStore
    @EnvironmentObject private var store: ShiftStore
    @EnvironmentObject private var cloud: MacSyncController
    @State private var selection = MacDestination.schedule
    @State private var selectedDate = AppLaunch.initialDate
    @State private var profile = false
    @State private var search = false
    @State private var query = ""
    @State private var newShift = false
    var body: some View {
        Group {
            if auth.isSignedIn { shell } else { LoginView() }
        }
        .frame(minWidth: 1000, minHeight: 680)
        .onReceive(NotificationCenter.default.publisher(for: .newMacShift)) { _ in
            if auth.isSignedIn { newShift = true }
        }
        .sheet(isPresented: $newShift) { ShiftEditor(date: selectedDate) }
        .onReceive(NotificationCenter.default.publisher(for: .widgetDateSelected)) { event in
            if let url = event.object as? URL, let day = WidgetData.date(from: url) { open(day) }
        }
        .onAppear {
            if let value = UserDefaults.standard.string(forKey: "widget.pendingURL"),
               let url = URL(string: value), let day = WidgetData.date(from: url) { open(day) }
        }
    }
    private var shell: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(nsImage: NSApplication.shared.applicationIconImage).resizable().scaledToFit()
                        .frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Plantão na Mão").font(.headline)
                        Text("Sua rotina organizada").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(20)
                Button { search = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass"); Text("Buscar plantões")
                        Spacer(minLength: 0); Text("⌘K").font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 14).padding(.vertical, 10).background(.quaternary.opacity(0.6), in: Capsule())
                }.buttonStyle(.plain).keyboardShortcut("k").padding(.horizontal, 16).padding(.bottom, 6)
                List {
                    Section("Sua rotina") {
                        ForEach(MacDestination.allCases) { destination in
                            Button { selection = destination } label: {
                                Label(destination.title, systemImage: destination.icon)
                                    .font(.body.weight(selection == destination ? .semibold : .regular))
                                    .foregroundStyle(selection == destination ? Color.accentColor : Color.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 9).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .listRowBackground(selection == destination ? Color.accentColor.opacity(0.12) : .clear)
                                .keyboardShortcut(KeyEquivalent(Character(String(destination.rawValue + 1))), modifiers: .command)
                                .accessibilityIdentifier("sidebar-\(destination.rawValue)")
                                .accessibilityAddTraits(selection == destination ? .isSelected : [])
                        }
                    }
                }.listStyle(.sidebar)
                Button { Task { await cloud.syncNow() } } label: {
                    HStack(spacing: 8) {
                        if cloud.isSyncing { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.triangle.2.circlepath") }
                        Text(cloud.isSyncing ? "Sincronizando…" : "Sincronizar agora")
                        Spacer()
                    }.font(.caption).padding(.horizontal, 20).padding(.vertical, 10)
                }.buttonStyle(.plain).disabled(cloud.isSyncing).keyboardShortcut("r")
                if let error = cloud.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled).padding(.horizontal, 20).padding(.bottom, 8)
                }
                ThemeToggleButton().padding(.horizontal, 20).padding(.vertical, 10)
                Divider().padding(.horizontal, 16)
                Button { profile = true } label: {
                    HStack(spacing: 12) {
                        MacAvatar(url: auth.photoURL).frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(auth.displayName.isEmpty ? "Meu perfil" : auth.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text("Perfil e ajustes").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0); Image(systemName: "gearshape").foregroundStyle(.secondary)
                    }.padding(12).contentShape(Rectangle())
                }.buttonStyle(.plain).keyboardShortcut(",").padding(8).accessibilityIdentifier("mac-profile")
            }.navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if let error = store.storageError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").font(.callout).padding().background(.orange.opacity(0.12))
                }
                switch selection {
                case .schedule: MacScheduleView(selectedDate: $selectedDate)
                case .finance: FinanceView()
                case .dashboard: DashboardView()
                case .locations: LocationsView()
                }
            }.background { AppBackdrop() }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $profile) { MacSettingsView().frame(width: 620, height: 720) }
        .sheet(isPresented: $search) { searchSheet }
    }
    private var searchSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Nome, local ou observação", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("mac-search")
                Button("Concluir") { search = false }.keyboardShortcut(.cancelAction)
            }
            List(store.shifts.filter { query.isEmpty || ($0.title + " " + $0.location + " " + $0.notes).localizedStandardContains(query) }.sorted { $0.date > $1.date }) { shift in
                Button {
                    selectedDate = shift.date; selection = .schedule; search = false
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shift.title).font(.headline)
                        Text("\(shift.location) · \(shift.date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
        }.padding(24).frame(width: 620, height: 500)
    }
    private func open(_ date: Date) {
        selectedDate = date; selection = .schedule
        UserDefaults.standard.removeObject(forKey: "widget.pendingURL")
    }
}

struct MacAvatar: View {
    let url: String
    var body: some View {
        ZStack {
            Circle().fill(.thinMaterial)
            if let url = URL(string: url), !self.url.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Image(systemName: "person.fill") }
                }
            } else { Image(systemName: "person.fill") }
        }.clipShape(Circle())
    }
}

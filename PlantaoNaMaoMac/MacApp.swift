import SwiftUI
import AppKit
import UserNotifications

extension Notification.Name { static let newMacShift = Notification.Name("plantao.mac.new-shift") }

@main
struct PlantaoNaMaoMacApp: App {
    @NSApplicationDelegateAdaptor(MacNotificationDelegate.self) private var delegate
    @StateObject private var store = AppLaunch.makeStore()
    @StateObject private var auth = GoogleAuthStore()
    @StateObject private var cloud = MacSyncController()
    @StateObject private var reminders = ShiftNotifications()
    @Environment(\.scenePhase) private var phase
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @AppStorage("plantao-na-mao.appearance") private var appearance = "system"
    private var scheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }
    var body: some Scene {
        WindowGroup("Plantão na Mão") {
            MacRootView()
                .environmentObject(store).environmentObject(auth).environmentObject(cloud).environmentObject(reminders)
                .tint((ShiftColor(rawValue: theme) ?? .mint).value)
                .preferredColorScheme(scheme).environment(\.locale, Locale(identifier: "pt_BR"))
                .task { reminders.start(store: store); await cloud.start(store: store, auth: auth) }
                .onOpenURL { url in
                    if url.scheme == "plantaonamao" {
                        UserDefaults.standard.set(url.absoluteString, forKey: "widget.pendingURL")
                        NotificationCenter.default.post(name: .widgetDateSelected, object: url)
                    } else { _ = auth.handle(url) }
                }
                .onChange(of: phase) { _, value in
                    WidgetBridge.publish(store.shifts)
                    if value == .active { reminders.refresh(); Task { await cloud.resume() } }
                    else if value == .background { cloud.pause() }
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                    reminders.refresh(); WidgetBridge.publish(store.shifts)
                    Task { await cloud.resume() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    reminders.refresh(); WidgetBridge.publish(store.shifts)
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                    reminders.refresh(); WidgetBridge.publish(store.shifts)
                }
        }
        .defaultSize(width: 1220, height: 820)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("Novo plantão") { NotificationCenter.default.post(name: .newMacShift, object: nil) }
                    .keyboardShortcut("n").disabled(!auth.isSignedIn || !store.canWrite)
            }
        }
        Settings {
            MacSettingsView().environmentObject(store).environmentObject(auth).environmentObject(cloud).environmentObject(reminders)
                .preferredColorScheme(scheme).environment(\.locale, Locale(identifier: "pt_BR"))
                .frame(width: 620, height: 720)
        }
    }
}

final class MacNotificationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let value = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: value), WidgetData.date(from: url) != nil {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                UserDefaults.standard.set(value, forKey: "widget.pendingURL")
                NotificationCenter.default.post(name: .widgetDateSelected, object: url)
            }
        }
        completionHandler()
    }
}

import SwiftUI
import Combine
import UserNotifications

protocol ReminderCenter: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func deliveredNotifications() async -> [UNNotification]
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}
extension UNUserNotificationCenter: ReminderCenter {
    func authorizationStatus() async -> UNAuthorizationStatus { await notificationSettings().authorizationStatus }
}

@MainActor
final class ShiftNotifications: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var lead: ReminderLead
    @Published private(set) var denied = false
    @Published private(set) var requestingPermission = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var queuedCount = 0
    @Published private(set) var hasMoreReminders = false
    private let center: ReminderCenter
    private let defaults: UserDefaults
    private var changes: AnyCancellable?
    private var shifts: [Shift] = []
    private var worker: Task<Void, Never>?
    private var needsRefresh = false
    private var version = 0
    private var started = false
    private var authorizationError: String?

    init(defaults: UserDefaults = .standard, center: ReminderCenter = UNUserNotificationCenter.current()) {
        self.defaults = defaults; self.center = center
        enabled = defaults.bool(forKey: "plantao-na-mao.reminders-enabled")
        lead = ReminderLead(rawValue: defaults.integer(forKey: "plantao-na-mao.reminder-minutes")) ?? .day
    }
    func start(store: ShiftStore) {
        guard !started, store.canWrite, !AppLaunch.isUITest else { return }
        started = true
        changes = store.$shifts.sink { [weak self] shifts in
            self?.shifts = shifts
            self?.refresh()
        }
    }
    func setEnabled(_ value: Bool) async {
        enabled = value
        defaults.set(value, forKey: "plantao-na-mao.reminders-enabled")
        authorizationError = nil
        if value {
            requestingPermission = true
            defer { requestingPermission = false }
            do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
            catch { authorizationError = "Não foi possível pedir permissão. Tente novamente em Ajustes." }
        }
        refresh()
    }
    func setLead(_ value: ReminderLead) {
        lead = value
        defaults.set(value.rawValue, forKey: "plantao-na-mao.reminder-minutes")
        refresh()
    }
    func refresh() {
        guard !AppLaunch.isUITest else { return }
        version += 1; needsRefresh = true
        guard worker == nil else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            while self.needsRefresh {
                self.needsRefresh = false
                await self.reconcile()
            }
            self.worker = nil
        }
    }
    // Serializes replacements so a late edit/disable cannot leave stale requests behind.
    private func reconcile() async {
        let ticket = version
        let status = await center.authorizationStatus()
        guard ticket == version else { return }
        let authorized = status == .authorized || status == .provisional
        denied = status == .denied
        let plans = enabled && authorized ? ShiftReminder.upcoming(shifts, lead: lead) : []
        let requests = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(ShiftReminder.prefix) }
        guard ticket == version else { return }
        let expected = Set(plans.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier).filter { !expected.contains($0) })
        let delivered = await center.deliveredNotifications()
        guard ticket == version else { return }
        let existing = Set(shifts.map { ShiftReminder.prefix + $0.id.uuidString })
        center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter {
            $0.hasPrefix(ShiftReminder.prefix) && (!enabled || !existing.contains($0))
        })
        errorMessage = authorizationError
        var count = 0
        for plan in plans {
            guard ticket == version else { return }
            let content = UNMutableNotificationContent()
            content.title = plan.title; content.subtitle = plan.subtitle; content.body = plan.body
            content.sound = .default
            content.threadIdentifier = "plantao-reminders"
            content.userInfo = ["url": plan.url.absoluteString]
            var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
            let trigger = UNCalendarNotificationTrigger(dateMatching: utc.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: plan.fireDate), repeats: false)
            let old = requests.first { $0.identifier == plan.identifier }
            if let old, old.content.title == content.title, old.content.subtitle == content.subtitle,
               old.content.body == content.body, old.content.userInfo["url"] as? String == plan.url.absoluteString,
               let previous = old.trigger as? UNCalendarNotificationTrigger,
               previous.dateComponents == trigger.dateComponents { count += 1; continue }
            do {
                try await center.add(UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger))
                count += 1
            } catch { errorMessage = "Alguns lembretes não foram agendados. Abra Ajustes e tente novamente." }
        }
        queuedCount = count
        hasMoreReminders = enabled && authorized && ShiftReminder.upcoming(shifts, lead: lead, limit: 65).count > 64
    }
    func waitUntilSettled() async { await worker?.value }
}

#if os(iOS)
final class NotificationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let string = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: string), url.scheme == "plantaonamao" {
            DispatchQueue.main.async {
                UserDefaults.standard.set(string, forKey: "widget.pendingURL")
                NotificationCenter.default.post(name: .widgetDateSelected, object: url)
                completionHandler()
            }
        } else { completionHandler() }
    }
}

#endif

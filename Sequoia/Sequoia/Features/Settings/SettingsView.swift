import SwiftUI
import UserNotifications
import DesignSystem
import SequoiaCore

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmsReset = false
    @State private var authorization: UNAuthorizationStatus = .notDetermined

    private var store: SequoiaStore { app.store }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Difficulty", selection: difficultyBinding) {
                        ForEach(Difficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Daily word")
                } footer: {
                    Text(store.settings.difficulty.subtitle)
                }

                Section {
                    Toggle("Daily reminder", isOn: notificationsBinding)
                    if store.settings.notificationsEnabled {
                        DatePicker("Reminder time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        Toggle("Evening streak nudge", isOn: nudgeBinding)
                    }
                    if authorization == .denied && store.settings.notificationsEnabled {
                        Button("Allow notifications in iOS Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(authorization == .denied && store.settings.notificationsEnabled
                         ? "Notifications are turned off for Sequoia. Everything else works as usual."
                         : "The reminder keeps the word a surprise until you open the app.")
                }

                Section {
                    NavigationLink("About Sequoia") { AboutView() }
                }

                Section {
                    Button("Reset progress", role: .destructive) { confirmsReset = true }
                } footer: {
                    Text("Erases your streak, rings, forest and word history. This can't be undone.")
                }

                #if SEQUOIA_DEV
                Section {
                    NavigationLink {
                        DeveloperPanelView()
                    } label: {
                        Label("Developer", systemImage: "hammer")
                    }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .sequoiaScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { store.resetProgress() }
            } message: {
                Text("Your streak, rings, forest and word history will be erased.")
            }
            .task { await refreshAuthorization() }
        }
    }

    private func refreshAuthorization() async {
        await app.notifications.refreshAuthorization()
        authorization = app.notifications.authorization
    }

    private var difficultyBinding: Binding<Difficulty> {
        Binding(get: { store.settings.difficulty }, set: { level in store.updateSettings { $0.difficulty = level } })
    }

    private var nudgeBinding: Binding<Bool> {
        Binding(get: { store.settings.streakNudgeEnabled }, set: { on in store.updateSettings { $0.streakNudgeEnabled = on } })
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.notificationsEnabled },
            set: { enabled in
                store.updateSettings { $0.notificationsEnabled = enabled }
                if enabled {
                    Task {
                        await app.notifications.requestPermissionIfNeeded(store: store)
                        await refreshAuthorization()
                    }
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = store.currentClock.calendar
                return calendar.date(from: DateComponents(hour: store.settings.reminderHour, minute: store.settings.reminderMinute)) ?? .distantPast
            },
            set: { date in
                let parts = store.currentClock.calendar.dateComponents([.hour, .minute], from: date)
                store.updateSettings {
                    $0.reminderHour = parts.hour ?? 8
                    $0.reminderMinute = parts.minute ?? 0
                }
            }
        )
    }
}

#Preview { SettingsView().environment(AppModel.preview) }
#Preview("Dark") { SettingsView().environment(AppModel.preview).preferredColorScheme(.dark) }

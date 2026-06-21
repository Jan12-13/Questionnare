import SwiftUI

enum AppSettings {
    static let administratorModeKey = "administratorMode"
    static let defaultAdministratorMode = true
    static let settingsPassword = "1"

    static var isAdministratorMode: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: administratorModeKey) != nil else {
            return defaultAdministratorMode
        }
        return defaults.bool(forKey: administratorModeKey)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.administratorModeKey)
    private var isAdministratorMode = AppSettings.defaultAdministratorMode
    @State private var password = ""
    @State private var isUnlocked = false
    @State private var showsInvalidPassword = false

    var body: some View {
        NavigationStack {
            Form {
                if isUnlocked {
                    Section {
                        Toggle("管理者状態", isOn: $isAdministratorMode)
                    } header: {
                        Text("管理者設定")
                    } footer: {
                        Text(isAdministratorMode
                             ? "アンケートと回答の削除ができます。"
                             : "アンケートと回答の削除はできません。")
                    }
                } else {
                    Section {
                        SecureField("パスワード", text: $password)
                            .keyboardType(.numberPad)
                            .textContentType(.password)
                            .onSubmit(authenticate)

                        Button("設定を開く", action: authenticate)
                            .disabled(password.isEmpty)
                    } header: {
                        Text("パスワード")
                    } footer: {
                        Text("設定を変更するにはパスワードを入力してください。")
                    }

                    if showsInvalidPassword {
                        Section {
                            Label("パスワードが違います", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear {
                password = ""
                isUnlocked = false
                showsInvalidPassword = false
            }
            .onChange(of: password) {
                showsInvalidPassword = false
            }
        }
    }

    private func authenticate() {
        guard password == AppSettings.settingsPassword else {
            showsInvalidPassword = true
            return
        }

        withAnimation {
            password = ""
            showsInvalidPassword = false
            isUnlocked = true
        }
    }
}

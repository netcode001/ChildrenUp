import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: AppThemeManager
    @StateObject private var userManager = UserManager.shared
    @StateObject private var authManager = SupabaseAuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showLogin = false
    @State private var showSub = false
    @State private var showThemeSettings = false
    @State private var showUserList = false
    @State private var showDemoDataAlert = false
    @State private var isGenerating = false
    
    // App Lock
    @StateObject private var appLockManager = AppLockManager.shared
    @State private var showingPaywall = false
    @State private var isAppLockSwitchOn = false
    @State private var showAppLockAlert = false

    // Avatar
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    
    // Sync
    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled: Bool = true
    @State private var syncedRecordCount = 0
    
    private var mainAccount: User? {
        userManager.allUsers.first(where: { $0.isMainAccount })
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - User Profile Section
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                            if let avatarImage {
                                avatarImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Theme.primaryGradient)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .onChange(of: selectedAvatarItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    if let uiImage = UIImage(data: data) {
                                        avatarImage = Image(uiImage: uiImage)
                                        saveAvatar(data: data)
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(mainAccount?.name ?? "点击头像设置")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                
                                // Subscription Badge
                                if subscriptionManager.isPro {
                                    Text("PRO")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            LinearGradient(
                                                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(4)
                                } else {
                                    Text("免费版")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.8))
                                        .cornerRadius(4)
                                }
                            }
                            
                            if authManager.isAuthenticated, let email = authManager.currentUserEmail {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Text(isCloudSyncEnabled ? "已开启 iCloud 同步备份" : "未开启 iCloud 同步备份")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // MARK: - General Settings
                Section {
                    settingsRow(title: "用户管理", icon: "person.2.fill", color: .blue) {
                        showUserList = true
                    }
                    
                    settingsRow(title: "外观风格", icon: "paintpalette.fill", color: .purple, value: themeManager.currentTheme.displayName) {
                        showThemeSettings = true
                    }
                    
                    settingsRow(title: "订阅会员", icon: "crown.fill", color: .orange, value: subscriptionManager.isPro ? "已订阅" : "解锁高级版") {
                        showSub = true
                    }
                    
                    settingsRow(title: "提醒设置", icon: "bell.fill", color: .red) {
                        // TODO: Reminder settings
                    }
                }
                
                // MARK: - Data & Security
                Section {
                    NavigationLink(destination: CloudSyncView()) {
                        HStack {
                            SettingsIcon(icon: "icloud.fill", color: .blue)
                            VStack(alignment: .leading) {
                                Text("iCloud 同步")
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textPrimary)
                                if isCloudSyncEnabled {
                                    Text("已同步 \(userManager.allUsers.count) 个用户 \(syncedRecordCount) 条数据")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            if isCloudSyncEnabled {
                                Text("已开启")
                                    .font(Theme.captionFont)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    
                    HStack {
                        SettingsIcon(icon: "lock.fill", color: .green)
                        VStack(alignment: .leading) {
                            Text("应用锁")
                                .font(Theme.bodyFont)
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        Toggle("", isOn: $isAppLockSwitchOn)
                            .labelsHidden()
                            .tint(Theme.primary)
                    }
                    .padding(.vertical, 5)
                    .onChange(of: isAppLockSwitchOn) { _, newValue in
                        if newValue {
                            if !subscriptionManager.isPro {
                                isAppLockSwitchOn = false
                                showingPaywall = true
                            } else if !appLockManager.isEnabled {
                                showAppLockAlert = true
                            }
                        } else {
                            appLockManager.isEnabled = false
                        }
                    }
                    .onChange(of: appLockManager.isEnabled) { _, newValue in
                        isAppLockSwitchOn = newValue
                    }
                    .alert("开启应用锁", isPresented: $showAppLockAlert) {
                        Button("取消", role: .cancel) {
                            isAppLockSwitchOn = false
                        }
                        Button("开启") {
                            appLockManager.isEnabled = true
                        }
                    } message: {
                        Text("为了保护您的数据隐私，开启后每次启动应用都需要使用 Face ID 或密码进行验证。")
                    }
                    
                    NavigationLink(destination: ExportView()) {
                        HStack {
                            SettingsIcon(icon: "square.and.arrow.up", color: .gray)
                            Text("导出数据")
                                .font(Theme.bodyFont)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                // MARK: - Danger Zone
                Section {
                    if authManager.isAuthenticated {
                        Button(action: {
                            authManager.signOut()
                        }) {
                            HStack {
                                Spacer()
                                Text("退出登录")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.vertical, 5)
                        }
                    } else {
                        Button(action: {
                            showLogin = true
                        }) {
                            HStack {
                                Spacer()
                                Text("登录 / 注册")
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                
                // MARK: - Demo Data (Hidden in Prod usually, kept for now)
                Section {
                    Button(action: {
                        isGenerating = true
                        Task {
                            do {
                                try await DemoDataGenerator.shared.generateDemoData()
                                try await Task.sleep(nanoseconds: 500_000_000)
                                await MainActor.run {
                                    isGenerating = false
                                    showDemoDataAlert = true
                                    NotificationCenter.default.post(name: NSNotification.Name("ReloadDashboardData"), object: nil)
                                }
                            } catch {
                                await MainActor.run { isGenerating = false }
                            }
                        }
                    }) {
                        if isGenerating {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("生成演示数据")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("我的")
            .navigationDestination(isPresented: $showThemeSettings) {
                ThemeSettingsView()
            }
            .navigationDestination(isPresented: $showUserList) {
                UserListView()
            }
            .sheet(isPresented: $showLogin) { LoginRegisterView() }
            .sheet(isPresented: $showSub) { SubscriptionView() }
            .sheet(isPresented: $showingPaywall) { SubscriptionView() }
            .alert("生成成功", isPresented: $showDemoDataAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("已生成365天的步数、卡路里、睡眠和心情数据，请前往洞察页面查看。")
            }
            .onAppear {
                loadAvatar()
                loadSyncStats()
                isAppLockSwitchOn = appLockManager.isEnabled
            }
            .onChange(of: mainAccount) { _, _ in
                loadAvatar()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func settingsRow(title: String, icon: String, color: Color, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                SettingsIcon(icon: icon, color: color)
                Text(title)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                if let value = value {
                    Text(value)
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle()) // Important for List behavior
    }
    
    private func loadSyncStats() {
        Task {
            if let count = try? await CoreDataManager.shared.fetchAllRecordCount() {
                await MainActor.run {
                    syncedRecordCount = count
                }
            }
        }
    }
    
    private func saveAvatar(data: Data) {
        guard let mainAccount = self.mainAccount else { return }
        let fileName = "avatar_\(mainAccount.id.uuidString).jpg"
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                Task {
                    await userManager.updateAvatar(for: mainAccount, path: fileName)
                    await MainActor.run {
                        loadAvatar()
                    }
                }
            } catch {
                print("Error saving avatar: \(error)")
            }
        }
    }
    
    private func loadAvatar() {
        guard let path = mainAccount?.avatarPath, !path.isEmpty else {
            avatarImage = nil
            return
        }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(path)
            if let data = try? Data(contentsOf: fileURL), let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
            } else {
                avatarImage = nil
            }
        }
    }
}

struct SettingsIcon: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(6)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(AppThemeManager.shared)
}

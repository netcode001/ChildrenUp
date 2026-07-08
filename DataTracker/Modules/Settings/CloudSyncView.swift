import SwiftUI
import CloudKit

struct CloudSyncView: View {
    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled: Bool = true
    @StateObject private var syncManager = CloudSyncManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPaywall = false
    
    var body: some View {
        List {
            Section(header: Text("iCloud 状态")) {
                HStack {
                    Text("iCloud 账户")
                    Spacer()
                    Text(accountStatusText)
                        .foregroundColor(accountStatusColor)
                }
                
                if syncManager.iCloudAccountStatus != .available {
                    Text("请在系统设置中登录 iCloud 并开启 iCloud Drive 以使用同步功能。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("同步设置")) {
                HStack {
                    Toggle("开启 iCloud 同步", isOn: $isCloudSyncEnabled)
                        .onChange(of: isCloudSyncEnabled) { _, newValue in
                            if newValue && !SubscriptionManager.shared.isPro {
                                isCloudSyncEnabled = false
                                showingPaywall = true
                            }
                        }
                    
                    if !SubscriptionManager.shared.isPro {
                        Image(systemName: "crown.fill")
                            .foregroundColor(Theme.accent)
                    }
                }
                
                Text("开启后，您的数据将自动备份到 iCloud，并在您的所有设备间同步。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !isCloudSyncEnabled {
                    Text("注意：关闭同步后，新的数据将仅保存在本地。重新开启需要重启应用生效。")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section(header: Text("数据操作")) {
                Button(action: {
                    Task {
                        await syncManager.triggerSync()
                    }
                }) {
                    HStack {
                        Text("立即从 iCloud 恢复/同步")
                            .foregroundColor(Theme.primary)
                        Spacer()
                        if syncManager.isSyncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(syncManager.iCloudAccountStatus != .available || !isCloudSyncEnabled || syncManager.isSyncing)
                
                if let lastSync = syncManager.lastSyncDate {
                    HStack {
                        Spacer()
                        Text("上次检查: \(lastSync.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("iCloud 同步")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncManager.checkAccountStatus()
            // If not pro, ensure sync is off (optional, but good for enforcement)
            // But maybe they were pro and expired? Let's just gate the *enabling* action.
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    private var accountStatusText: String {
        switch syncManager.iCloudAccountStatus {
        case .available:
            return "已登录"
        case .noAccount:
            return "未登录"
        case .restricted:
            return "受限"
        case .couldNotDetermine:
            return "未知"
        case .temporarilyUnavailable:
            return "暂时不可用"
        @unknown default:
            return "未知"
        }
    }
    
    private var accountStatusColor: Color {
        switch syncManager.iCloudAccountStatus {
        case .available:
            return .green
        case .noAccount, .restricted, .temporarilyUnavailable:
            return .red
        default:
            return .gray
        }
    }
}

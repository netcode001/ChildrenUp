import SwiftUI

struct ExportView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var selectedUsers: Set<UUID> = []
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        Button {
                            if selectedUsers.count == userManager.allUsers.count {
                                selectedUsers.removeAll()
                            } else {
                                selectedUsers = Set(userManager.allUsers.map { $0.id })
                            }
                        } label: {
                            HStack {
                                Text("全选")
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                if selectedUsers.count == userManager.allUsers.count && !userManager.allUsers.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                    }
                    
                    Section("选择要导出的用户数据") {
                        ForEach(userManager.allUsers) { user in
                            Button {
                                if selectedUsers.contains(user.id) {
                                    selectedUsers.remove(user.id)
                                } else {
                                    selectedUsers.insert(user.id)
                                }
                            } label: {
                                HStack {
                                    if let path = user.avatarPath,
                                       let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                                       let uiImage = UIImage(contentsOfFile: dir.appendingPathComponent(path).path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Theme.surfaceElevated)
                                            .frame(width: 32, height: 32)
                                            .overlay(Image(systemName: "person.fill").foregroundColor(Theme.secondary))
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(user.name)
                                            .foregroundColor(Theme.textPrimary)
                                        if user.isMainAccount {
                                            Text("主账户")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedUsers.contains(user.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.primary)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                VStack {
                    Button {
                        if SubscriptionManager.shared.isPro || selectedUsers.count <= 1 {
                            exportData()
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        HStack {
                            Text(SubscriptionManager.shared.isPro || selectedUsers.count <= 1 ? "导出数据" : "升级 Pro 导出多用户数据")
                                .font(Theme.headlineFont)
                            if !SubscriptionManager.shared.isPro && selectedUsers.count > 1 {
                                Image(systemName: "crown.fill")
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .fill(selectedUsers.isEmpty ? Color.gray : (SubscriptionManager.shared.isPro || selectedUsers.count <= 1 ? Theme.primary : Theme.accent))
                        )
                    }
                    .disabled(selectedUsers.isEmpty || isExporting)
                    .padding()
                }
                .background(Theme.surface)
            }
            
            if isExporting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("正在导出...")
                        .font(Theme.headlineFont)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.7))
                )
            }
        }
        .navigationTitle("导出数据")
        .onAppear {
            // Default select all
            selectedUsers = Set(userManager.allUsers.map { $0.id })
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
    }
    
    @State private var showingPaywall = false
    
    private func exportData() {
        guard !selectedUsers.isEmpty else { return }
        
        withAnimation {
            isExporting = true
        }
        
        Task {
            // Add artificial delay for animation visibility if needed
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            do {
                let url = try await CoreDataManager.shared.exportRecords(for: selectedUsers)
                await MainActor.run {
                    self.exportURL = url
                    self.isExporting = false
                    self.showShareSheet = true
                }
            } catch {
                print("Export failed: \(error)")
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }
}

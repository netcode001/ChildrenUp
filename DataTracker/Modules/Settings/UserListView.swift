import SwiftUI
import PhotosUI

struct UserListView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var showAddUser = false
    @State private var newUserName = ""
    @State private var showingPaywall = false
    @State private var editingUser: User?
    
    var body: some View {
        List {
            ForEach(userManager.allUsers) { user in
                Button {
                    editingUser = user
                } label: {
                    HStack(spacing: 12) {
                        // Avatar
                        if let path = user.avatarPath,
                           let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                           let uiImage = UIImage(contentsOfFile: dir.appendingPathComponent(path).path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Theme.surface)
                                .frame(width: 40, height: 40)
                                .overlay(Image(systemName: "person.fill").foregroundColor(Theme.secondary))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(user.name)
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textPrimary)
                                
                                if user.isCurrentUser {
                                    Text("当前")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.primary.opacity(0.1))
                                        .foregroundColor(Theme.primary)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(user.isMainAccount ? "主账户" : "子账户")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !user.isMainAccount {
                        Button(role: .destructive) {
                            if user.isCurrentUser {
                                // If deleting current user, we might need to switch first? 
                                // For now, let's just allow delete and UserManager handles switch or let user switch first.
                                // Safe bet: prevent deleting current user too, or show alert.
                                // Requirement says "Sub account can be deleted". 
                                // Let's implement delete.
                                Task {
                                    await userManager.deleteUser(user)
                                }
                            } else {
                                Task {
                                    await userManager.deleteUser(user)
                                }
                            }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("用户管理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if SubscriptionManager.shared.canCreateUser(currentUserCount: userManager.allUsers.count) {
                        showAddUser = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
        .sheet(item: $editingUser) { user in
            UserEditView(user: user)
        }
        .alert("添加新用户", isPresented: $showAddUser) {
            TextField("用户名", text: $newUserName)
            Button("取消", role: .cancel) { newUserName = "" }
            Button("添加") {
                if !newUserName.isEmpty {
                    Task {
                        await userManager.createUser(name: newUserName, avatarPath: nil)
                        newUserName = ""
                    }
                }
            }
        }
    }
}

struct UserEditView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @StateObject private var userManager = UserManager.shared
    
    init(user: User) {
        self.user = user
        _name = State(initialValue: user.name)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else if let path = user.avatarPath,
                                      let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                                      let uiImage = UIImage(contentsOfFile: dir.appendingPathComponent(path).path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Theme.surface)
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "person.fill").resizable().padding(20).foregroundColor(Theme.secondary))
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("更换头像")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.primary)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section("用户信息") {
                    TextField("用户名", text: $name)
                    
                    HStack {
                        Text("账户类型")
                        Spacer()
                        Text(user.isMainAccount ? "主账户" : "子账户")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("编辑用户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            var avatarPath = user.avatarPath
                            
                            // Save new avatar if selected
                            if let data = selectedImageData {
                                let fileName = UUID().uuidString + ".jpg"
                                if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                    let fileURL = dir.appendingPathComponent(fileName)
                                    try? data.write(to: fileURL)
                                    avatarPath = fileName
                                }
                            }
                            
                            await userManager.updateUser(user: user, name: name, avatarPath: avatarPath)
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }
}

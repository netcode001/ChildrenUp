//
//  UserManager.swift
//  DataTracker
//
//  Created by Assistant on 2025/12/16.
//

import Foundation
import CoreData
import SwiftUI
import Combine

struct User: Identifiable, Hashable {
    let id: UUID
    var name: String
    var avatarPath: String?
    var isCurrentUser: Bool
    var subscriptionStatus: Int16
    var subscriptionExpiry: Date?
    var createdAt: Date
    var isMainAccount: Bool // New property
}

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: User?
    @Published var allUsers: [User] = []
    
    // New: Subscription Manager Reference (to avoid circular dependency, access shared directly or inject?)
    // Using direct access for simplicity in this pair programming session
    
    // Determine main account ID (earliest created user)
    private var mainAccountId: UUID? {
        allUsers.sorted(by: { $0.createdAt < $1.createdAt }).first?.id
    }
    
    private init() {
        Task {
            await loadUsers()
        }
    }
    
    @MainActor
    func loadUsers() async {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            
            // First pass to determine main account ID (if not determined yet)
            let sortedEntities = entities.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
            let mainId = sortedEntities.first?.id
            
            self.allUsers = entities.map { entity in
                var user = entity.toModel()
                if let mainId = mainId, user.id == mainId {
                    user.isMainAccount = true
                }
                return user
            }
            
            if let current = self.allUsers.first(where: { $0.isCurrentUser }) {
                self.currentUser = current
                CoreDataManager.shared.currentUserId = current.id
            } else if let first = self.allUsers.first {
                await switchUser(to: first)
            } else {
                await createDefaultUser()
            }
        } catch {
            print("Failed to load users: \(error)")
        }
    }
    
    @MainActor
    func createDefaultUser() async {
        print("Creating default user and migrating data...")
        let context = PersistenceController.shared.container.viewContext
        
        // Create default user
        let newUser = UserEntity(context: context)
        newUser.id = UUID()
        newUser.name = "默认用户"
        newUser.createdAt = Date()
        newUser.isCurrentUser = true
        
        // Migrate existing items that have no user
        let itemRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
        itemRequest.predicate = NSPredicate(format: "user == nil")
        
        do {
            let items = try context.fetch(itemRequest)
            for item in items {
                item.user = newUser
            }
            
            try context.save()
            print("Migrated \(items.count) items to default user")
            
            await loadUsers()
        } catch {
            print("Failed to create default user: \(error)")
        }
    }
    
    @MainActor
    func createUser(name: String, avatarPath: String?) async {
        let context = PersistenceController.shared.container.newBackgroundContext()
        await context.perform {
            let entity = UserEntity(context: context)
            entity.id = UUID()
            entity.name = name
            entity.avatarPath = avatarPath
            entity.createdAt = Date()
            entity.isCurrentUser = false // New users are not current by default
            
            do {
                try context.save()
            } catch {
                print("Failed to create user: \(error)")
            }
        }
        await loadUsers()
    }
    
    @MainActor
    func switchUser(to user: User) async {
        let context = PersistenceController.shared.container.viewContext
        
        // Update all users
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                if entity.id == user.id {
                    entity.isCurrentUser = true
                } else {
                    entity.isCurrentUser = false
                }
            }
            try context.save()
            
            // Update local state
            self.currentUser = user
            self.currentUser?.isCurrentUser = true
            
            // Sync to UserDefaults for compatibility with existing views
            if let path = user.avatarPath {
                UserDefaults.standard.set(path, forKey: "userAvatarPath")
            } else {
                UserDefaults.standard.removeObject(forKey: "userAvatarPath")
            }
            
            // Update CoreDataManager
            CoreDataManager.shared.currentUserId = user.id
            
            // Reload users to reflect state
            await loadUsers()
            
            // Post notification for data reload
            NotificationCenter.default.post(name: NSNotification.Name("ReloadDashboardData"), object: nil)
        } catch {
            print("Failed to switch user: \(error)")
        }
    }
    
    @MainActor
    func updateAvatar(for user: User, path: String) async {
        await updateUser(user: user, name: nil, avatarPath: path)
    }
    
    @MainActor
    func updateUser(user: User, name: String?, avatarPath: String?) async {
        let context = PersistenceController.shared.container.newBackgroundContext()
        await context.perform {
            let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
            
            if let entity = try? context.fetch(request).first {
                if let name = name {
                    entity.name = name
                }
                if let avatarPath = avatarPath {
                    entity.avatarPath = avatarPath
                }
                try? context.save()
            }
        }
        
        // If updating current user, sync to UserDefaults
        if user.id == self.currentUser?.id {
            if let avatarPath = avatarPath {
                UserDefaults.standard.set(avatarPath, forKey: "userAvatarPath")
            }
        }
        
        await loadUsers()
    }

    @MainActor
    func deleteUser(_ user: User) async {
        let context = PersistenceController.shared.container.newBackgroundContext()
        await context.perform {
            let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
            
            if let entity = try? context.fetch(request).first {
                context.delete(entity)
                try? context.save()
            }
        }
        await loadUsers()
    }
}

extension UserEntity {
    func toModel() -> User {
        return User(
            id: self.id ?? UUID(),
            name: self.name ?? "Unknown",
            avatarPath: self.avatarPath,
            isCurrentUser: self.isCurrentUser,
            subscriptionStatus: self.subscriptionStatus,
            subscriptionExpiry: self.subscriptionExpiry,
            createdAt: self.createdAt ?? Date(),
            isMainAccount: false // Set by UserManager
        )
    }
}

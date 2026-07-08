//
//  CoreDataManager.swift
//  DataTracker
//
//  Created by Assistant on 2025/11/13.
//

import Foundation
@preconcurrency import CoreData
import Combine
import SwiftUI

class CoreDataManager {
    static let shared = CoreDataManager()
    
    // Set by UserManager
    var currentUserId: UUID?
    
    private init() {}
    
    // MARK: - TrackerItem Operations
    
    func saveTrackerItem(_ item: TrackerItem) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        // Capture currentUserId to use in background block
        let userId = self.currentUserId
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            
            let entity: TrackerItemEntity
            if let existing = try context.fetch(fetchRequest).first {
                entity = existing
            } else {
                entity = TrackerItemEntity(context: context)
                entity.id = item.id
                entity.createdAt = item.createdAt
                
                // Set user for new item
                if let userId = userId {
                    let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
                    if let user = try context.fetch(userRequest).first {
                        entity.user = user
                    }
                }
            }
            
            entity.name = item.name
            entity.group = item.group
            entity.unit = item.unit
            entity.icon = item.icon
            entity.color = item.color
            entity.updatedAt = Date()
            
            try context.save()
        }
    }
    
    func fetchTrackerItems(in category: String? = nil) async throws -> [TrackerItem] {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Filter by user
        if let userId = currentUserId {
            predicates.append(NSPredicate(format: "user.id == %@", userId as CVarArg))
        } else {
            // If no user set, maybe fetch items with no user (legacy)?
            // Or return empty?
            // For now, let's include items with no user OR items with current user
            // But wait, migration should have handled "no user" items.
            // So strictly filtering by user is safer.
            // However, on first launch before user load, this might be called.
            // Let's assume UserManager loads first.
            // If currentUserId is nil, we might want to return nothing or all?
            // Safe bet: if nil, return empty to avoid mixing data.
            // But for migration safety:
            // predicates.append(NSPredicate(format: "user == nil")) 
            // We'll stick to strict filtering if ID is set.
        }
        
        if let category = category, category != "我的" {
            predicates.append(NSPredicate(format: "group == %@", category))
        }
        
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { entity in
            guard let id = entity.id, let name = entity.name else { return nil }
            return TrackerItem(
                id: id,
                name: name,
                group: entity.group,
                unit: entity.unit,
                icon: entity.icon,
                color: entity.color,
                createdAt: entity.createdAt ?? Date(),
                updatedAt: entity.updatedAt ?? Date()
            )
        }
    }
    
    func deleteTrackerItem(_ item: TrackerItem) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        try await context.perform {
            let fetchRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            if let entity = try context.fetch(fetchRequest).first {
                // Delete associated records first to ensure cleanup
                let recordRequest: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
                recordRequest.predicate = NSPredicate(format: "item == %@", entity)
                let records = try context.fetch(recordRequest)
                for record in records {
                    context.delete(record)
                }
                
                context.delete(entity)
                try context.save()
            }
        }
    }
    
    // MARK: - TrackerRecord Operations
    
    func saveTrackerRecord(_ record: TrackerRecord) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        try await context.perform {
            // Find item first
            let itemRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
            itemRequest.predicate = NSPredicate(format: "id == %@", record.itemId as CVarArg)
            guard let itemEntity = try context.fetch(itemRequest).first else {
                print("CoreDataManager: TrackerItem not found for record")
                return 
            }
            
            let fetchRequest: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            
            let entity: TrackerRecordEntity
            if let existing = try context.fetch(fetchRequest).first {
                entity = existing
            } else {
                entity = TrackerRecordEntity(context: context)
                entity.id = record.id
            }
            
            entity.value = record.value
            entity.date = record.date
            entity.note = record.note
            if let images = record.images, !images.isEmpty {
                // Store array of Data as single Data blob using JSON encoding or archiving
                // For simplicity, we'll archive the array of data objects
                // Note: In a real app, you might want a separate Entity for images (1-to-Many)
                // but for "max 3 small images", storing as blob is acceptable if size is managed.
                // We will simply join them or use NSKeyedArchiver if compatible, 
                // but here let's assume we store the first one or try to encode the array.
                // Better approach: Encode [Data] to Data
                if let encoded = try? JSONEncoder().encode(images) {
                    entity.images = encoded
                }
            } else {
                entity.images = nil
            }
            entity.item = itemEntity
            
            try context.save()
        }
    }
    
    func batchSaveTrackerRecords(_ records: [TrackerRecord]) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        try await context.perform {
            // Cache item entities to avoid fetching for each record
            var itemCache: [UUID: TrackerItemEntity] = [:]
            
            for record in records {
                // Find item
                let itemEntity: TrackerItemEntity
                if let cached = itemCache[record.itemId] {
                    itemEntity = cached
                } else {
                    let itemRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
                    itemRequest.predicate = NSPredicate(format: "id == %@", record.itemId as CVarArg)
                    if let fetched = try context.fetch(itemRequest).first {
                        itemEntity = fetched
                        itemCache[record.itemId] = fetched
                    } else {
                        print("CoreDataManager: TrackerItem not found for record batch")
                        continue
                    }
                }
                
                // Check if record exists
                let fetchRequest: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
                
                let entity: TrackerRecordEntity
                if let existing = try context.fetch(fetchRequest).first {
                    entity = existing
                } else {
                    entity = TrackerRecordEntity(context: context)
                    entity.id = record.id
                }
                
                entity.value = record.value
                entity.date = record.date
                entity.note = record.note
                if let images = record.images, !images.isEmpty {
                    if let encoded = try? JSONEncoder().encode(images) {
                        entity.images = encoded
                    }
                } else {
                    entity.images = nil
                }
                entity.item = itemEntity
            }
            
            try context.save()
        }
    }
    
    func fetchTrackerRecords(for itemId: UUID) async throws -> [TrackerRecord] {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "item.id == %@", itemId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { entity in
            guard let id = entity.id, let item = entity.item, let itemId = item.id else { return nil }
            
            var images: [Data]? = nil
            if let data = entity.images {
                images = try? JSONDecoder().decode([Data].self, from: data)
            }
            
            return TrackerRecord(
                id: id,
                itemId: itemId,
                value: entity.value,
                date: entity.date ?? Date(),
                note: entity.note,
                images: images
            )
        }
    }
    
    func fetchRecentRecords(limit: Int = 10, category: String? = nil) async throws -> [TrackerRecord] {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        if let category = category, category != "我的" {
            predicates.append(NSPredicate(format: "item.group == %@", category))
        }
        
        if let userId = currentUserId {
            predicates.append(NSPredicate(format: "item.user.id == %@", userId as CVarArg))
        }
        
        if !predicates.isEmpty {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = limit
        
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { entity in
            guard let id = entity.id, let item = entity.item, let itemId = item.id else { return nil }
            
            var images: [Data]? = nil
            if let data = entity.images {
                images = try? JSONDecoder().decode([Data].self, from: data)
            }

            return TrackerRecord(
                id: id,
                itemId: itemId,
                value: entity.value,
                date: entity.date ?? Date(),
                note: entity.note,
                images: images
            )
        }
    }
    
    func deleteTrackerRecord(_ record: TrackerRecord) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        try await context.perform {
            let fetchRequest: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            if let entity = try context.fetch(fetchRequest).first {
                context.delete(entity)
                try context.save()
            }
        }
    }

    // MARK: - Aggregations (Adapted)
    
    struct AggregatedItem {
        let item: TrackerItem
        let records: [TrackerRecord]
        let totalValue: Double
        let count: Int
    }
    
    func fetchAggregatedRecords(from start: Date?, to end: Date?, userId: UUID? = nil) async throws -> [AggregatedItem] {
        let records = try await fetchRecords(from: start, to: end, userId: userId)
        
        // Fetch all items to map details
        let items = try await fetchTrackerItems()
        let itemMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        
        // Group by Item ID
        let grouped = Dictionary(grouping: records, by: { $0.itemId })
        
        var result: [AggregatedItem] = []
        
        for (itemId, itemRecords) in grouped {
            if let item = itemMap[itemId] {
                let total = itemRecords.reduce(0) { $0 + $1.value }
                result.append(AggregatedItem(
                    item: item,
                    records: itemRecords,
                    totalValue: total,
                    count: itemRecords.count
                ))
            }
        }
        
        // Sort by most frequent or custom logic
        return result.sorted { $0.count > $1.count }
    }
    
    func fetchRecords(from start: Date?, to end: Date?, category: String? = nil, userId: UUID? = nil) async throws -> [TrackerRecord] {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
        var predicates: [NSPredicate] = []
        if let start = start { predicates.append(NSPredicate(format: "date >= %@", start as CVarArg)) }
        if let end = end { predicates.append(NSPredicate(format: "date <= %@", end as CVarArg)) }
        if let category = category, category != "全部" {
            predicates.append(NSPredicate(format: "item.group == %@", category))
        }
        
        let targetUserId = userId ?? currentUserId
        if let userId = targetUserId {
            predicates.append(NSPredicate(format: "item.user.id == %@", userId as CVarArg))
        }
        
        if !predicates.isEmpty { request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates) }
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let entities = try context.fetch(request)
        return entities.compactMap { entity in
            guard let id = entity.id, let item = entity.item, let itemId = item.id else { return nil }
            
            var images: [Data]? = nil
            if let data = entity.images {
                images = try? JSONDecoder().decode([Data].self, from: data)
            }

            return TrackerRecord(
                id: id,
                itemId: itemId,
                value: entity.value,
                date: entity.date ?? Date(),
                note: entity.note,
                images: images
            )
        }
    }

    func fetchRecordCount(from start: Date?, to end: Date?, category: String? = nil, userId: UUID? = nil) async throws -> Int {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
        var predicates: [NSPredicate] = []
        if let start = start { predicates.append(NSPredicate(format: "date >= %@", start as CVarArg)) }
        if let end = end { predicates.append(NSPredicate(format: "date <= %@", end as CVarArg)) }
        if let category = category, category != "全部" {
            predicates.append(NSPredicate(format: "item.group == %@", category))
        }
        
        let targetUserId = userId ?? currentUserId
        if let userId = targetUserId {
            predicates.append(NSPredicate(format: "item.user.id == %@", userId as CVarArg))
        }
        
        if !predicates.isEmpty { request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates) }
        return try context.count(for: request)
    }

    func fetchNumericAverage(from start: Date?, to end: Date?, category: String? = nil, userId: UUID? = nil) async throws -> Double? {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
        var predicates: [NSPredicate] = []
        if let start = start { predicates.append(NSPredicate(format: "date >= %@", start as CVarArg)) }
        if let end = end { predicates.append(NSPredicate(format: "date <= %@", end as CVarArg)) }
        if let category = category, category != "全部" {
            predicates.append(NSPredicate(format: "item.group == %@", category))
        }
        
        let targetUserId = userId ?? currentUserId
        if let userId = targetUserId {
            predicates.append(NSPredicate(format: "item.user.id == %@", userId as CVarArg))
        }
        
        if !predicates.isEmpty { request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates) }
        
        let entities = try context.fetch(request)

        let values = entities.map { $0.value }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
    
    func generateCSV(from points: [TrendPoint], title: String? = nil) throws -> URL {
        var lines: [String] = []
        if let t = title { lines.append("# \(t)") }
        lines.append("date,label,value")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for p in points {
            let dateStr = p.date.map { formatter.string(from: $0) } ?? ""
            lines.append("\(dateStr),\(p.label),\(p.value)")
        }
        let csv = lines.joined(separator: "\n")
        let dir = FileManager.default.temporaryDirectory
        let dateStr = formatter.string(from: Date())
        let cleanTitle = (title ?? "Trend").replacingOccurrences(of: " ", with: "_")
        let filename = "\(cleanTitle)_\(dateStr).csv"
        let url = dir.appendingPathComponent(filename)
        try csv.data(using: .utf8)?.write(to: url)
        return url
    }

    func renderChartImage<V: View>(from view: V, scale: CGFloat = 2.0) throws -> URL {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        #if os(iOS)
        guard let img = renderer.uiImage, let data = img.pngData() else {
            throw NSError(domain: "render", code: -1)
        }
        #elseif os(macOS)
        guard let img = renderer.nsImage else { throw NSError(domain: "render", code: -1) }
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "render", code: -1)
        }
        #else
        let data = Data()
        #endif
        let dir = FileManager.default.temporaryDirectory
        let filename = "Chart_\(Int(Date().timeIntervalSince1970)).png"
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    func exportRecords(for userIds: Set<UUID>) async throws -> URL {
        let context = PersistenceController.shared.container.viewContext
        
        return try await context.perform {
            // Fetch items for selected users to map names
            let itemRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
            itemRequest.predicate = NSPredicate(format: "user.id IN %@", userIds)
            let items = try context.fetch(itemRequest)
            let itemMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
            
            // Fetch records for selected users
            let request: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
            request.predicate = NSPredicate(format: "item.user.id IN %@", userIds)
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            let entities = try context.fetch(request)
            
            var csvString = "Date,User,Item Name,Value,Note\n"
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            for entity in entities {
                let dateStr = formatter.string(from: entity.date ?? Date())
                let itemId = entity.item?.id
                let itemName: String
                if let id = itemId, let name = itemMap[id] {
                     itemName = name ?? "Unknown"
                } else {
                     itemName = "Unknown"
                }
                
                let userName = entity.item?.user?.name ?? "Unknown"
                let value = String(format: "%.2f", entity.value)
                let note = (entity.note ?? "").replacingOccurrences(of: ",", with: "，").replacingOccurrences(of: "\n", with: " ")
                
                csvString.append("\(dateStr),\(userName),\(itemName),\(value),\(note)\n")
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "DataTracker_Export_\(Int(Date().timeIntervalSince1970)).csv"
            let fileURL = tempDir.appendingPathComponent(fileName)
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        }
    }
    
    func exportAllRecordsToCSV() async throws -> URL {
        let items = try await fetchTrackerItems()
        let itemMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
        
        // Fetch all records
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        // Perform fetch on the context's thread if needed, but viewContext is main thread usually.
        // Since this function is async, we can use perform.
        return try await context.perform {
            let entities = try context.fetch(request)
            
            var csvString = "Date,Item Name,Value,Note\n"
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            for entity in entities {
                let dateStr = formatter.string(from: entity.date ?? Date())
                // Use safe navigation for item relationships
                let itemId = entity.item?.id
                let itemName = itemId != nil ? (itemMap[itemId!] ?? "Unknown") : "Unknown"
                let value = String(format: "%.2f", entity.value)
                let note = (entity.note ?? "").replacingOccurrences(of: ",", with: "，").replacingOccurrences(of: "\n", with: " ")
                
                csvString.append("\(dateStr),\(itemName),\(value),\(note)\n")
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("DataTracker_Export_\(Int(Date().timeIntervalSince1970)).csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        }
    }
    
    func fetchAllRecordCount() async throws -> Int {
        let context = PersistenceController.shared.container.viewContext
        return try await context.perform {
            let request: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
            return try context.count(for: request)
        }
    }
    
    // MARK: - AI Processing
    
    @discardableResult
    func processAIRecord(_ data: AIRecordData) async throws -> UUID {
        let context = PersistenceController.shared.container.newBackgroundContext()
        let userId = self.currentUserId
        
        // Prepare template map for lookup
        let allTemplates = CategoryManager.shared.templates
        
        // Check Pro status on MainActor before entering background context
        let isPro = await MainActor.run { SubscriptionManager.shared.isPro }
        
        return try await context.perform {
            var itemEntity: TrackerItemEntity?
            
            // 1. Find or Create Item
            let fetchRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
            
            var predicates = [NSPredicate(format: "name ==[c] %@", data.targetName)]
            if let userId = userId {
                predicates.append(NSPredicate(format: "user.id == %@", userId as CVarArg))
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            if let existing = try context.fetch(fetchRequest).first {
                itemEntity = existing
            } else {
                // Check Limits for AI Auto-Creation (Free: 5 items)
                if !isPro {
                    let countRequest: NSFetchRequest<TrackerItemEntity> = TrackerItemEntity.fetchRequest()
                    let currentCount = try context.count(for: countRequest)
                    
                    if currentCount >= SubscriptionManager.Limits.maxFreeTrackers {
                        throw NSError(domain: "DataTracker", code: 403, userInfo: [
                            NSLocalizedDescriptionKey: "免费版最多支持自动创建 \(SubscriptionManager.Limits.maxFreeTrackers) 个追踪项。请手动创建或升级 Pro 版。"
                        ])
                    }
                }
                
                // If action is createAndRecord or simply not found, create it
                let newItem = TrackerItemEntity(context: context)
                newItem.id = UUID()
                newItem.name = data.targetName
                newItem.createdAt = Date()
                newItem.updatedAt = Date()
                
                if let userId = userId {
                    let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
                    if let user = try context.fetch(userRequest).first {
                        newItem.user = user
                    }
                }
                
                // Try to find matching template for metadata
                var foundCategory: String?
                var foundUnit: String?
                var foundIcon: String?
                
                for (category, items) in allTemplates {
                    if let match = items.first(where: { $0.name == data.targetName }) {
                        foundCategory = category
                        foundUnit = match.unit
                        foundIcon = match.icon
                        break
                    }
                }
                
                // Use AI provided info if available, otherwise fallback to template or defaults
                var finalCategory = foundCategory ?? data.newModelInfo?.group ?? "其他"
                
                // Heuristic: Map AI 'type' to category if template lookup and explicit group failed
                if foundCategory == nil && data.newModelInfo?.group == nil, let type = data.newModelInfo?.type?.lowercased() {
                     if ["food", "drink", "meal", "diet", "beverage"].contains(where: { type.contains($0) }) { finalCategory = "饮食" }
                     else if ["exercise", "workout", "sport", "fitness", "activity"].contains(where: { type.contains($0) }) { finalCategory = "健身" }
                     else if ["health", "body", "medical", "sleep", "vital"].contains(where: { type.contains($0) }) { finalCategory = "健康" }
                     else if ["money", "cost", "price", "expense", "finance"].contains(where: { type.contains($0) }) { finalCategory = "财务" }
                     else if ["study", "learn", "exam", "read", "education"].contains(where: { type.contains($0) }) { finalCategory = "考试/学习" }
                     else if ["work", "job", "task", "efficiency"].contains(where: { type.contains($0) }) { finalCategory = "工作/效率" }
                }
                
                newItem.group = finalCategory
                newItem.unit = data.newModelInfo?.unit ?? foundUnit ?? "次"
                newItem.icon = data.newModelInfo?.icon ?? foundIcon ?? "tray.fill"
                newItem.color = "#007AFF"
                
                itemEntity = newItem
            }
            
            // 2. Create Record
            guard let item = itemEntity, let _ = item.id else {
                throw NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve item"])
            }
            
            let record = TrackerRecordEntity(context: context)
            let recordId = UUID()
            record.id = recordId
            record.date = Date() // Use current time for now
            record.item = item
            
            let valueString = data.value
            let scanner = Scanner(string: valueString)
            var doubleVal: Double = 0
            
            if let val = Double(valueString) {
                doubleVal = val
            } else if let val = scanner.scanDouble() {
                doubleVal = val
            } else {
                record.note = valueString
            }
            
            record.value = doubleVal
            
            try context.save()
            return recordId
        }
    }
    
    func updateRecord(id: UUID, note: String? = nil, images: [Data]? = nil) async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<TrackerRecordEntity> = TrackerRecordEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            guard let record = try context.fetch(fetchRequest).first else {
                throw NSError(domain: "CoreData", code: 404, userInfo: [NSLocalizedDescriptionKey: "Record not found"])
            }
            
            if let note = note {
                record.note = note
            }
            
            if let images = images {
                record.images = try JSONEncoder().encode(images)
            }
            
            try context.save()
        }
    }
}

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    @Published var categories: [String] = []
    @Published var hiddenTemplates: Set<String> = []
    
    private let defaults = UserDefaults.standard
    private let categoriesKey = "dashboard_categories"
    private let hiddenTemplatesKey = "dashboard_hidden_templates"
    
    // Preset categories defined in tagdev.md
    private let defaultCategories = [
        "健身",
        "饮食",
        "健康",
        "财务",
        "成绩",
        "学习",
        "工作",
        "兴趣",
        "其他"
    ]
    
    // Preset templates for each category
    let templates: [String: [TemplateItem]] = [
        "健身": [
            TemplateItem(name: "跑步", unit: "km", icon: "figure.run"),
            TemplateItem(name: "步行", unit: "steps", icon: "figure.walk"),
            TemplateItem(name: "骑行", unit: "km", icon: "bicycle"),
            TemplateItem(name: "游泳", unit: "m", icon: "figure.pool.swim"),
            
            // Updated Icons based on user feedback
            TemplateItem(name: "俯卧撑", unit: "count", icon: "figure.strengthtraining.functional"), // Changed from .traditional
            TemplateItem(name: "引体向上", unit: "count", icon: "figure.climbing"), // Changed from .functional (closest visual match)
            TemplateItem(name: "深蹲", unit: "count", icon: "figure.strengthtraining.traditional"), // Changed from .cooldown (Squat is traditional strength)
            TemplateItem(name: "仰卧起坐", unit: "count", icon: "figure.core.training"),
            TemplateItem(name: "平板支撑", unit: "sec", icon: "stopwatch"), // Maybe figure.core.training.fill? Keep stopwatch for now
            TemplateItem(name: "跳绳", unit: "count", icon: "figure.jumprope"),
            
            // New Gym Equipment
            TemplateItem(name: "跑步机", unit: "km", icon: "figure.run"), // Generic run
            TemplateItem(name: "划船机", unit: "km", icon: "figure.rower"),
            TemplateItem(name: "椭圆机", unit: "min", icon: "figure.elliptical"),
            TemplateItem(name: "动感单车", unit: "min", icon: "figure.indoor.cycle"),
            TemplateItem(name: "登山机", unit: "min", icon: "figure.stairs"),
            TemplateItem(name: "卧推", unit: "kg", icon: "dumbbell.fill"), // Generic weight
            TemplateItem(name: "倒蹬机", unit: "kg", icon: "figure.strengthtraining.traditional"), // Leg press is traditional
            
            TemplateItem(name: "力量训练", unit: "kg", icon: "dumbbell.fill"),
            TemplateItem(name: "瑜伽", unit: "min", icon: "figure.yoga"),
            TemplateItem(name: "运动消耗", unit: "kcal", icon: "flame.fill"),
            TemplateItem(name: "平均心率", unit: "bpm", icon: "heart.fill")
        ],
        "饮食": [
            TemplateItem(name: "饮水量", unit: "ml", icon: "drop.fill"),
            TemplateItem(name: "热量摄入", unit: "kcal", icon: "fork.knife"),
            TemplateItem(name: "蛋白质", unit: "g", icon: "fish.fill"),
            TemplateItem(name: "碳水化合物", unit: "g", icon: "circle.grid.cross.fill"),
            TemplateItem(name: "脂肪", unit: "g", icon: "drop.triangle.fill"),
            
            // Changed from Caffeine
            TemplateItem(name: "咖啡", unit: "杯", icon: "cup.and.saucer.fill"),
            
            TemplateItem(name: "糖分", unit: "g", icon: "cube.fill"),
            TemplateItem(name: "水果蔬菜", unit: "portions", icon: "carrot.fill"),
            
            // New Food & Drinks
            TemplateItem(name: "奶茶", unit: "杯", icon: "cup.and.saucer"),
            TemplateItem(name: "火锅", unit: "次", icon: "flame"), // flame implies hot/cooking
            TemplateItem(name: "料理", unit: "顿", icon: "fork.knife.circle.fill"),
            TemplateItem(name: "牛排", unit: "份", icon: "fork.knife"),
            TemplateItem(name: "披萨", unit: "块", icon: "circle.grid.cross"), // Looks like a sliced pie
            
            // Alcohol
            TemplateItem(name: "白酒", unit: "ml", icon: "wineglass"),
            TemplateItem(name: "红酒", unit: "杯", icon: "wineglass.fill"),
            TemplateItem(name: "葡萄酒", unit: "杯", icon: "wineglass.fill"),
            TemplateItem(name: "黄酒", unit: "ml", icon: "drop.fill"), // Liquid drop
            TemplateItem(name: "酒精摄入", unit: "ml", icon: "wineglass.fill"), // Keep original generic one too
            
            TemplateItem(name: "零食/含糖饮料", unit: "count", icon: "takeoutbag.and.cup.and.straw.fill")
        ],
        "健康": [
            TemplateItem(name: "体重", unit: "kg", icon: "scalemass.fill"),
            TemplateItem(name: "体脂率", unit: "%", icon: "percent"),
            TemplateItem(name: "睡眠时长", unit: "hr", icon: "bed.double.fill"),
            TemplateItem(name: "深睡时长", unit: "hr", icon: "moon.zzz.fill"),
            TemplateItem(name: "静息心率", unit: "bpm", icon: "waveform.path.ecg"),
            TemplateItem(name: "收缩压", unit: "mmHg", icon: "heart.circle.fill"),
            TemplateItem(name: "舒张压", unit: "mmHg", icon: "heart.circle"),
            TemplateItem(name: "体温", unit: "°C", icon: "thermometer"),
            
            // Medical Indicators
            TemplateItem(name: "血糖", unit: "mmol/L", icon: "drop.fill"),
            TemplateItem(name: "血氧", unit: "%", icon: "bubbles.and.sparkles.fill"), // Changed from o2.circle to bubbles
            TemplateItem(name: "胆固醇", unit: "mmol/L", icon: "drop.triangle.fill"),
            TemplateItem(name: "甘油三酯", unit: "mmol/L", icon: "drop.circle.fill"),
            TemplateItem(name: "尿酸", unit: "μmol/L", icon: "testtube.2"),
            TemplateItem(name: "视力", unit: "score", icon: "eye.fill"),
            
            TemplateItem(name: "心情指数", unit: "score", icon: "face.smiling"),
            TemplateItem(name: "精力值", unit: "score", icon: "bolt.fill"),
            TemplateItem(name: "冥想/正念", unit: "min", icon: "brain.head.profile")
        ],
        "财务": [
            TemplateItem(name: "今日总支出", unit: "元", icon: "yensign.circle.fill"),
            TemplateItem(name: "餐饮支出", unit: "元", icon: "fork.knife.circle"),
            TemplateItem(name: "交通支出", unit: "元", icon: "car.circle"),
            TemplateItem(name: "购物支出", unit: "元", icon: "bag.circle"),
            TemplateItem(name: "娱乐支出", unit: "元", icon: "gamecontroller.circle"),
            TemplateItem(name: "今日收入", unit: "元", icon: "arrow.down.circle.fill"),
            TemplateItem(name: "储蓄/理财", unit: "元", icon: "banknote.fill"),
            TemplateItem(name: "固定账单", unit: "元", icon: "doc.text.fill")
        ],
        "成绩": [
            TemplateItem(name: "语文", unit: "分", icon: "book.fill"),
            TemplateItem(name: "数学", unit: "分", icon: "function"),
            TemplateItem(name: "英语", unit: "分", icon: "textformat.abc"),
            TemplateItem(name: "物理", unit: "分", icon: "atom"),
            TemplateItem(name: "化学", unit: "分", icon: "flask.fill"),
            TemplateItem(name: "生物", unit: "分", icon: "leaf.fill"),
            TemplateItem(name: "历史", unit: "分", icon: "scroll.fill"),
            TemplateItem(name: "地理", unit: "分", icon: "globe"),
            TemplateItem(name: "政治", unit: "分", icon: "building.columns.fill"),
            TemplateItem(name: "科学", unit: "分", icon: "testtube.2"),
            TemplateItem(name: "体育", unit: "分", icon: "figure.run"),
            TemplateItem(name: "音乐", unit: "分", icon: "music.note"),
            TemplateItem(name: "美术", unit: "分", icon: "paintbrush.fill"),
            TemplateItem(name: "信息技术", unit: "分", icon: "desktopcomputer")
        ],
        "学习": [
            TemplateItem(name: "学习时长", unit: "hr", icon: "book.fill"),
            TemplateItem(name: "专注时长", unit: "min", icon: "timer"),
            TemplateItem(name: "刷题数量", unit: "count", icon: "pencil.and.outline"),
            TemplateItem(name: "背单词", unit: "count", icon: "textformat.abc"),
            TemplateItem(name: "阅读页数", unit: "pages", icon: "book.closed.fill"),
            TemplateItem(name: "模拟考分数", unit: "score", icon: "graduationcap.fill"),
            TemplateItem(name: "错题整理", unit: "count", icon: "xmark.circle"),
            TemplateItem(name: "网课/听课", unit: "min", icon: "desktopcomputer")
        ],
        "工作": [
            TemplateItem(name: "工作时长", unit: "hr", icon: "briefcase.fill"),
            TemplateItem(name: "加班时长", unit: "hr", icon: "clock.badge.exclamationmark"),
            TemplateItem(name: "完成任务数", unit: "count", icon: "checkmark.square.fill"),
            TemplateItem(name: "会议时长", unit: "min", icon: "person.3.fill"),
            TemplateItem(name: "通勤时长", unit: "min", icon: "tram.fill"),
            TemplateItem(name: "邮件/消息处理", unit: "count", icon: "envelope.fill"),
            TemplateItem(name: "代码行数/提交", unit: "count", icon: "chevron.left.forwardslash.chevron.right")
        ],
        "兴趣": [
            TemplateItem(name: "屏幕使用时间", unit: "hr", icon: "iphone"),
            TemplateItem(name: "游戏时长", unit: "min", icon: "gamecontroller.fill"),
            TemplateItem(name: "练琴/乐器", unit: "min", icon: "music.note"),
            TemplateItem(name: "绘画/创作", unit: "min", icon: "paintbrush.fill"),
            TemplateItem(name: "观影/追剧", unit: "min", icon: "tv.fill"),
            TemplateItem(name: "社交/聚会", unit: "hr", icon: "person.2.fill"),
            TemplateItem(name: "家务劳动", unit: "min", icon: "house.fill")
        ]
    ]
    
    private init() {
        loadCategories()
    }
    
    func loadCategories() {
        if let saved = defaults.array(forKey: categoriesKey) as? [String] {
            self.categories = saved
            
            // Migration: Rename categories
            var needsSave = false
            let renames = [
                "考试/学习": "学习",
                "工作/效率": "工作",
                "效率": "工作",
                "兴趣/其他": "兴趣",
                "未分类": "其他"
            ]
            
            for (oldName, newName) in renames {
                if let index = self.categories.firstIndex(of: oldName) {
                    self.categories[index] = newName
                    needsSave = true
                }
            }
            
            // Ensure "成绩" exists for existing users
            if !self.categories.contains("成绩") {
                // Insert after "财务" if possible, or append
                if let financeIndex = self.categories.firstIndex(of: "财务") {
                    self.categories.insert("成绩", at: financeIndex + 1)
                } else {
                    self.categories.append("成绩")
                }
                needsSave = true
            }
            
            // Ensure "其他" exists for existing users
            if !self.categories.contains("其他") {
                self.categories.append("其他")
                needsSave = true
            }
            
            if needsSave {
                saveCategories()
            }
        } else {
            // Initialize with default categories
            self.categories = defaultCategories
            saveCategories()
        }
        
        if let hidden = defaults.array(forKey: hiddenTemplatesKey) as? [String] {
            self.hiddenTemplates = Set(hidden)
        }
    }
    
    func addCategory(_ name: String) {
        guard !categories.contains(name) else { return }
        categories.append(name)
        saveCategories()
    }
    
    func deleteCategory(at index: Int) {
        guard index >= 0 && index < categories.count else { return }
        categories.remove(at: index)
        saveCategories()
    }
    
    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        saveCategories()
    }
    
    func hideTemplate(_ name: String) {
        hiddenTemplates.insert(name)
        saveHiddenTemplates()
    }
    
    private func saveCategories() {
        defaults.set(categories, forKey: categoriesKey)
    }
    
    private func saveHiddenTemplates() {
        defaults.set(Array(hiddenTemplates), forKey: hiddenTemplatesKey)
    }
    
    // Helper to get templates for a category
    func getTemplates(for category: String) -> [TemplateItem] {
        let items = templates[category] ?? []
        return items.filter { !hiddenTemplates.contains($0.name) }
    }
    
    // Get all templates across all categories
    func getAllTemplates() -> [TemplateItem] {
        return templates.values.flatMap { $0 }.filter { !hiddenTemplates.contains($0.name) }
    }
}

struct TemplateItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let unit: String
    let icon: String
}

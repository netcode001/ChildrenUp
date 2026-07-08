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
                     else if ["exercise", "workout", "sport", "fitness", "activity"].contains(where: { type.contains($0) }) { finalCategory = "运动" }
                     else if ["sleep", "nap", "bedtime"].contains(where: { type.contains($0) }) { finalCategory = "睡眠" }
                     else if ["health", "body", "medical", "vital", "medicine"].contains(where: { type.contains($0) }) { finalCategory = "健康" }
                     else if ["score", "exam", "grade", "test"].contains(where: { type.contains($0) }) { finalCategory = "成绩" }
                     else if ["study", "learn", "read", "homework", "education"].contains(where: { type.contains($0) }) { finalCategory = "学习" }
                     else if ["mood", "emotion", "feeling"].contains(where: { type.contains($0) }) { finalCategory = "情绪" }
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
    
    private let defaultCategories = [
        "成绩",
        "学习",
        "睡眠",
        "运动",
        "健康",
        "饮食",
        "情绪",
        "其他"
    ]
    
    // Preset templates for each category
    let templates: [String: [TemplateItem]] = [
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
            TemplateItem(name: "阅读", unit: "分钟", icon: "book.closed.fill"),
            TemplateItem(name: "作业", unit: "项", icon: "pencil.and.list.clipboard"),
            TemplateItem(name: "学习时长", unit: "小时", icon: "book.fill"),
            TemplateItem(name: "专注时长", unit: "min", icon: "timer"),
            TemplateItem(name: "刷题数量", unit: "count", icon: "pencil.and.outline"),
            TemplateItem(name: "背单词", unit: "count", icon: "textformat.abc"),
            TemplateItem(name: "阅读页数", unit: "pages", icon: "book.closed.fill"),
            TemplateItem(name: "模拟考分数", unit: "score", icon: "graduationcap.fill"),
            TemplateItem(name: "错题整理", unit: "count", icon: "xmark.circle"),
            TemplateItem(name: "网课/听课", unit: "min", icon: "desktopcomputer")
        ],
        "睡眠": [
            TemplateItem(name: "睡眠时长", unit: "小时", icon: "bed.double.fill"),
            TemplateItem(name: "入睡时间", unit: "点", icon: "moon.zzz.fill"),
            TemplateItem(name: "午睡", unit: "分钟", icon: "powersleep"),
            TemplateItem(name: "夜醒", unit: "次", icon: "alarm.fill")
        ],
        "运动": [
            TemplateItem(name: "跳绳", unit: "个", icon: "figure.jumprope"),
            TemplateItem(name: "跑步", unit: "分钟", icon: "figure.run"),
            TemplateItem(name: "步行", unit: "步", icon: "figure.walk"),
            TemplateItem(name: "游泳", unit: "分钟", icon: "figure.pool.swim"),
            TemplateItem(name: "篮球", unit: "分钟", icon: "basketball.fill"),
            TemplateItem(name: "足球", unit: "分钟", icon: "soccerball"),
            TemplateItem(name: "户外活动", unit: "分钟", icon: "sun.max.fill")
        ],
        "健康": [
            TemplateItem(name: "体温", unit: "°C", icon: "thermometer"),
            TemplateItem(name: "用药", unit: "次", icon: "pills.fill"),
            TemplateItem(name: "身高", unit: "cm", icon: "ruler.fill"),
            TemplateItem(name: "体重", unit: "kg", icon: "scalemass.fill"),
            TemplateItem(name: "视力", unit: "分", icon: "eye.fill"),
            TemplateItem(name: "过敏", unit: "次", icon: "allergens"),
            TemplateItem(name: "咳嗽", unit: "次", icon: "lungs.fill")
        ],
        "饮食": [
            TemplateItem(name: "早餐", unit: "份", icon: "sunrise.fill"),
            TemplateItem(name: "午餐", unit: "份", icon: "fork.knife"),
            TemplateItem(name: "晚餐", unit: "份", icon: "moon.stars.fill"),
            TemplateItem(name: "饮水", unit: "杯", icon: "drop.fill"),
            TemplateItem(name: "水果", unit: "份", icon: "carrot.fill"),
            TemplateItem(name: "牛奶", unit: "杯", icon: "mug.fill"),
            TemplateItem(name: "零食", unit: "次", icon: "takeoutbag.and.cup.and.straw.fill")
        ],
        "情绪": [
            TemplateItem(name: "开心", unit: "次", icon: "face.smiling.fill"),
            TemplateItem(name: "生气", unit: "次", icon: "flame.fill"),
            TemplateItem(name: "难过", unit: "次", icon: "cloud.rain.fill"),
            TemplateItem(name: "焦虑", unit: "次", icon: "exclamationmark.bubble.fill"),
            TemplateItem(name: "主动表达", unit: "次", icon: "bubble.left.and.bubble.right.fill")
        ],
        "其他": [
            TemplateItem(name: "身高体重记录", unit: "次", icon: "list.clipboard.fill"),
            TemplateItem(name: "老师反馈", unit: "次", icon: "person.text.rectangle.fill"),
            TemplateItem(name: "亲子活动", unit: "次", icon: "figure.2.and.child.holdinghands"),
            TemplateItem(name: "兴趣课", unit: "分钟", icon: "paintpalette.fill")
        ]
    ]
    
    private init() {
        loadCategories()
    }
    
    func loadCategories() {
        if let saved = defaults.array(forKey: categoriesKey) as? [String] {
            var needsSave = false
            let renames = [
                "健身": "运动",
                "考试/学习": "学习",
                "工作/效率": "其他",
                "效率": "其他",
                "工作": "其他",
                "财务": "其他",
                "兴趣": "其他",
                "兴趣/其他": "其他",
                "未分类": "其他"
            ]
            
            var normalized: [String] = []
            for category in saved {
                let newName = renames[category] ?? category
                if defaultCategories.contains(newName), !normalized.contains(newName) {
                    normalized.append(newName)
                }
                if newName != category {
                    needsSave = true
                }
            }
            
            for category in defaultCategories where !normalized.contains(category) {
                normalized.append(category)
            }
            
            if normalized != saved {
                needsSave = true
            }
            self.categories = normalized
            
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

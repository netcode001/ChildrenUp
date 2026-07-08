import Foundation

class DemoDataGenerator {
    static let shared = DemoDataGenerator()
    
    private init() {}
    
    func generateDemoData() async throws {
        // 1. Ensure Items exist
        let walkingItem = TrackerItem(id: UUID(), name: "步数", group: "健康", unit: "步", icon: "figure.walk", color: "#34C759")
        let caloriesItem = TrackerItem(id: UUID(), name: "卡路里", group: "健康", unit: "kcal", icon: "flame.fill", color: "#FF9500")
        let sleepItem = TrackerItem(id: UUID(), name: "睡眠", group: "健康", unit: "h", icon: "bed.double.fill", color: "#5856D6")
        let moodItem = TrackerItem(id: UUID(), name: "心情", group: "生活", unit: "分", icon: "face.smiling", color: "#FFCC00")
        
        // Save items (if they already exist with same name, we might want to use existing ones, but for simplicity let's save new ones or update)
        // Note: CoreDataManager.saveTrackerItem uses ID to check existence.
        // But here we generate new UUIDs. So we will likely duplicate if we run multiple times unless we check by name.
        // Let's first check if items with these names exist.
        
        let existingItems = try await CoreDataManager.shared.fetchTrackerItems()
        
        var finalWalkingItem = walkingItem
        var finalCaloriesItem = caloriesItem
        var finalSleepItem = sleepItem
        var finalMoodItem = moodItem
        
        if let existing = existingItems.first(where: { $0.name == "步数" }) { finalWalkingItem = existing } else { try await CoreDataManager.shared.saveTrackerItem(walkingItem) }
        if let existing = existingItems.first(where: { $0.name == "卡路里" }) { finalCaloriesItem = existing } else { try await CoreDataManager.shared.saveTrackerItem(caloriesItem) }
        if let existing = existingItems.first(where: { $0.name == "睡眠" }) { finalSleepItem = existing } else { try await CoreDataManager.shared.saveTrackerItem(sleepItem) }
        if let existing = existingItems.first(where: { $0.name == "心情" }) { finalMoodItem = existing } else { try await CoreDataManager.shared.saveTrackerItem(moodItem) }
        
        // 2. Generate Records
        var records: [TrackerRecord] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Generate for last 365 days
        for i in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // Random factors
            let seasonality = sin(Double(i) / 365.0 * 2 * .pi) // yearly cycle
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            
            // Walking: Base 6000 + Seasonality + Random + Weekend boost
            var steps = 6000.0 + (seasonality * 1000.0) + Double.random(in: -1000...2000)
            if isWeekend { steps += 2000 }
            steps = max(0, steps)
            
            // Calories: Linear with steps + noise
            let calories = steps * 0.04 + Double.random(in: -50...50)
            
            // Sleep: Normal around 7.5h
            var sleep = 7.5 + Double.random(in: -1.5...1.5)
            if isWeekend { sleep += 1.0 } // Sleep more on weekends
            
            // Mood: Correlated with Sleep (more sleep -> better mood, up to a point) + Random
            // Sleep 7-8 is ideal (8-9 mood). Too little (<6) is bad. Too much (>10) is groggy.
            var moodBase = 7.0
            if sleep < 6 { moodBase = 4.0 }
            else if sleep < 7 { moodBase = 6.0 }
            else if sleep < 9 { moodBase = 8.0 }
            else { moodBase = 7.0 }
            
            let mood = min(10, max(1, moodBase + Double.random(in: -2...2)))
            
            // Create records
            records.append(TrackerRecord(id: UUID(), itemId: finalWalkingItem.id, value: steps, date: date, note: "自动生成"))
            records.append(TrackerRecord(id: UUID(), itemId: finalCaloriesItem.id, value: calories, date: date, note: "自动生成"))
            records.append(TrackerRecord(id: UUID(), itemId: finalSleepItem.id, value: sleep, date: date, note: "自动生成"))
            records.append(TrackerRecord(id: UUID(), itemId: finalMoodItem.id, value: mood, date: date, note: "自动生成"))
        }
        
        // 3. Save Records Batch
        try await CoreDataManager.shared.batchSaveTrackerRecords(records)
    }
}

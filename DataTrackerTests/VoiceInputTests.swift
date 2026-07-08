import Testing
@testable import DataTracker
import Foundation

struct VoiceInputTests {

    @Test func testProcessAIRecord_NewItem() async throws {
        let uniqueName = "TestVoiceItem_\(UUID().uuidString)"
        let response = AIResponse(
            action: .createAndRecord,
            modelName: uniqueName,
            data: AIRecordData(value: "10.5", date: nil),
            newModelInfo: NewModelInfo(type: "number", unit: "kg", icon: nil)
        )
        
        try await CoreDataManager.shared.processAIRecord(response)
        
        // Verify
        let items = try await CoreDataManager.shared.fetchTrackerItems()
        let item = items.first(where: { $0.name == uniqueName })
        
        #expect(item != nil)
        #expect(item?.unit == "kg")
        
        if let item = item {
            let records = try await CoreDataManager.shared.fetchTrackerRecords(for: item.id)
            #expect(records.count == 1)
            #expect(records.first?.value == 10.5)
            
            // Cleanup
            try await CoreDataManager.shared.deleteTrackerItem(item)
        }
    }
    
    @Test func testProcessAIRecord_ExistingItem() async throws {
        // Create item first
        let uniqueName = "TestVoiceItem_Existing_\(UUID().uuidString)"
        let item = TrackerItem(id: UUID(), name: uniqueName, group: nil, unit: "m", icon: nil, color: "blue", createdAt: Date(), updatedAt: Date())
        try await CoreDataManager.shared.saveTrackerItem(item)
        
        let response = AIResponse(
            action: .record,
            modelName: uniqueName,
            data: AIRecordData(value: "20", date: nil),
            newModelInfo: nil
        )
        
        try await CoreDataManager.shared.processAIRecord(response)
        
        // Verify
        let records = try await CoreDataManager.shared.fetchTrackerRecords(for: item.id)
        #expect(records.count == 1)
        #expect(records.first?.value == 20.0)
        
        // Cleanup
        try await CoreDataManager.shared.deleteTrackerItem(item)
    }
}

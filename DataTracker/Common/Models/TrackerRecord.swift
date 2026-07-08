import Foundation

struct TrackerRecord: Identifiable, Equatable, Hashable {
    let id: UUID
    let itemId: UUID
    var value: Double
    var date: Date
    var note: String?
    var images: [Data]?
    
    init(id: UUID = UUID(), itemId: UUID, value: Double, date: Date = Date(), note: String? = nil, images: [Data]? = nil) {
        self.id = id
        self.itemId = itemId
        self.value = value
        self.date = date
        self.note = note
        self.images = images
    }
}

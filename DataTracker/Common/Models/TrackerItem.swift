import Foundation

struct TrackerItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var group: String?
    var unit: String?
    var icon: String?
    var color: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), name: String, group: String? = nil, unit: String? = nil, icon: String? = nil, color: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.group = group
        self.unit = unit
        self.icon = icon
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

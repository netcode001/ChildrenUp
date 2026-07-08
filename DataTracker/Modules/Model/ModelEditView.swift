import SwiftUI

struct ModelEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var group: String = ""
    @State private var unit: String = ""
    @State private var icon: String = ""
    @State private var color: String = ""
    
    let existingItem: TrackerItem
    
    init(existingItem: TrackerItem) {
        self.existingItem = existingItem
        _name = State(initialValue: existingItem.name)
        _group = State(initialValue: existingItem.group ?? "")
        _unit = State(initialValue: existingItem.unit ?? "")
        _icon = State(initialValue: existingItem.icon ?? "doc.text.fill")
        _color = State(initialValue: existingItem.color ?? "#007AFF")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称", text: $name)
                    TextField("分组", text: $group)
                    TextField("单位", text: $unit)
                }
                
                Section(header: Text("样式")) {
                    TextField("图标", text: $icon)
                    TextField("颜色", text: $color)
                }
                
                Button("保存") {
                    saveItem()
                }
            }
            .navigationTitle("编辑项目")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func saveItem() {
        var updated = existingItem
        updated.name = name
        updated.group = group.isEmpty ? nil : group
        updated.unit = unit.isEmpty ? nil : unit
        updated.icon = icon.isEmpty ? nil : icon
        updated.color = color.isEmpty ? nil : color
        
        Task {
            try? await CoreDataManager.shared.saveTrackerItem(updated)
            await MainActor.run { dismiss() }
        }
    }
}

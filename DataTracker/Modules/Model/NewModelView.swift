import SwiftUI

struct NewModelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var group: String = ""
    @State private var unit: String = ""
    @State private var icon: String = "doc.text.fill"
    @State private var color: String = "#007AFF"
    
    init(initialGroup: String? = nil) {
        _group = State(initialValue: initialGroup ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称 (必填)", text: $name)
                    TextField("分组 (可选)", text: $group)
                    TextField("单位 (可选)", text: $unit)
                }
                
                Section(header: Text("样式")) {
                    TextField("图标 (SF Symbol)", text: $icon)
                    TextField("颜色 (Hex)", text: $color)
                }
                
                Button("保存") {
                    saveItem()
                }
                .disabled(name.isEmpty)
            }
            .navigationTitle("新建项目")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
    
    @State private var showingPaywall = false
    
    // ...
    
    private func saveItem() {
        // Manual creation is now unlimited for free users (user request)
        let item = TrackerItem(
            name: name,
            group: group.isEmpty ? nil : group,
            unit: unit.isEmpty ? nil : unit,
            icon: icon.isEmpty ? nil : icon,
            color: color.isEmpty ? nil : color
        )
        
        Task {
            try? await CoreDataManager.shared.saveTrackerItem(item)
            await MainActor.run { dismiss() }
        }
    }
}

#Preview {
    NewModelView()
}
